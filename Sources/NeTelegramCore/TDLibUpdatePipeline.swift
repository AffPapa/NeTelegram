import Foundation

public enum TDLibPipelineEvent: Sendable {
    case routed(RoutedTDLibUpdate)
    case routingFailure(TDLibRoutingError)
}

public enum TDLibUpdateAdmission: Equatable, Sendable {
    case accepted
    case stopped
    case oversized(maximumBytes: Int)
}

/// A bounded fair queue between the one blocking td_receive worker and the
/// reducer. Each client keeps FIFO order; ready clients take turns so a busy
/// account cannot indefinitely starve sparse accounts. A small, byte-limited
/// reserve admits one event for otherwise idle lanes after the shared budget
/// fills. Further overflow applies backpressure; no updates are dropped.
public final class TDLibUpdateBuffer: @unchecked Sendable {
    private enum Lane: Hashable {
        case client(ClientID)
        case unrouteable
    }

    private struct LaneQueue {
        var items: [BufferedTDLibUpdate] = []
        var head = 0
        var count: Int { items.count - head }

        mutating func append(_ update: BufferedTDLibUpdate) { items.append(update) }

        mutating func take() -> BufferedTDLibUpdate? {
            guard head < items.count else { return nil }
            let update = items[head]
            head += 1
            if head >= 256 && head * 2 >= items.count {
                items.removeFirst(head)
                head = 0
            }
            return update
        }
    }

    private let condition = NSCondition()
    private let capacity: Int
    private let byteCapacity: Int
    private let reservedByteCapacity: Int
    private var storage: [Lane: LaneQueue] = [:]
    /// Contains only non-empty lanes. A lane moves to the tail after each take.
    private var readyLanes: [Lane] = []
    private var storedItemCount = 0
    private var storedByteCount = 0
    private var inFlightItemCount = 0
    private var inFlightByteCount = 0
    private var inFlightByLane: [Lane: Int] = [:]
    /// A saturated shared budget may hold one event for each otherwise idle
    /// lane. This bounded reserve lets the sole receive worker discover other
    /// accounts behind a hot account without dropping events.
    private var reservedLanes: Set<Lane> = []
    private var reservedBytes = 0
    private var waitingAppends = 0
    private var closed = false
    private var allowFinalInFlightAppend = false
    private var finalInFlightAppendUsed = false

    public init(capacity: Int = 2_048, byteCapacity: Int = 64 * 1_024 * 1_024) {
        self.capacity = max(1, capacity)
        self.byteCapacity = max(1, byteCapacity)
        self.reservedByteCapacity = max(1, byteCapacity / 4)
    }

    public var count: Int {
        condition.lock()
        defer { condition.unlock() }
        return storedItemCount + inFlightItemCount
    }

    /// Number of receive producers currently blocked by a full FIFO. The
    /// shared TDLib gateway has one producer; this is exposed for diagnostics
    /// and to make backpressure behavior observable in tests.
    public var blockedProducerCount: Int {
        condition.lock()
        defer { condition.unlock() }
        return waitingAppends
    }

    /// Bytes queued or being reduced, including the bounded cross-lane reserve.
    /// Asynchronous delivery cannot turn backpressure into an unbounded task queue.
    public var queuedByteCount: Int {
        condition.lock()
        defer { condition.unlock() }
        return storedByteCount + inFlightByteCount
    }

    /// Buffered event count for one client. Exposed for diagnostics and to
    /// verify that a noisy lane cannot conceal sparse clients in the queue.
    public func queuedClientCount(for clientID: ClientID) -> Int {
        condition.lock()
        defer { condition.unlock() }
        return storage[.client(clientID)]?.count ?? 0
    }

    /// Blocks until capacity is available. Returns false once shutdown starts.
    @discardableResult
    public func append(_ json: Data) -> Bool {
        if case .accepted = admit(json) { return true }
        return false
    }

    func admit(_ json: Data) -> TDLibUpdateAdmission {
        guard json.count <= byteCapacity else { return .oversized(maximumBytes: byteCapacity) }
        let incoming = BufferedTDLibUpdate(json: json)
        let lane = lane(for: incoming)
        condition.lock()
        while !closed && isFull(for: incoming, lane: lane) {
            waitingAppends += 1
            condition.wait()
            waitingAppends -= 1
        }
        guard !closed || (allowFinalInFlightAppend && !finalInFlightAppendUsed) else {
            condition.unlock()
            return .stopped
        }
        // The receive worker calls append synchronously and is the sole producer.
        // During shutdown, it may already hold one JSON result (including while
        // blocked above). Admit that one result so closing input cannot silently
        // discard a critical authorization/delete/TTL update. This final item may
        // exceed the normal budget by at most one update, then all later appends
        // are rejected.
        if closed { finalInFlightAppendUsed = true }
        let useReservedCapacity = storedItemCount + inFlightItemCount > 0
            && !hasMainCapacity(for: incoming.json.count)
        let update = BufferedTDLibUpdate(json: json, usesReservedLaneCapacity: useReservedCapacity)
        if useReservedCapacity {
            reservedLanes.insert(lane)
            reservedBytes += json.count
        }
        if storage[lane] == nil {
            storage[lane] = LaneQueue()
            readyLanes.append(lane)
        }
        storage[lane, default: LaneQueue()].append(update)
        storedItemCount += 1
        storedByteCount += update.json.count
        condition.signal()
        condition.unlock()
        return .accepted
    }

    /// Returns nil after close and after every already accepted item is drained.
    public func take() -> BufferedTDLibUpdate? {
        condition.lock()
        while readyLanes.isEmpty && !closed { condition.wait() }
        guard !readyLanes.isEmpty else {
            condition.unlock()
            return nil
        }
        let lane = readyLanes.removeFirst()
        guard var laneQueue = storage[lane], let update = laneQueue.take() else {
            condition.unlock()
            assertionFailure("TDLib update queue contains an empty ready lane")
            return nil
        }
        storedItemCount -= 1
        storedByteCount -= update.json.count
        inFlightItemCount += 1
        inFlightByteCount += update.json.count
        inFlightByLane[lane, default: 0] += 1
        if laneQueue.count == 0 {
            storage.removeValue(forKey: lane)
        } else {
            storage[lane] = laneQueue
            readyLanes.append(lane)
        }
        condition.broadcast()
        condition.unlock()
        return update
    }

    /// Releases capacity only after the account's asynchronous reducer callback
    /// finishes, including time spent awaiting MainActor work.
    public func complete(_ update: BufferedTDLibUpdate) {
        condition.lock()
        precondition(inFlightItemCount > 0 && inFlightByteCount >= update.json.count)
        inFlightItemCount -= 1
        inFlightByteCount -= update.json.count
        let lane = lane(for: update)
        let laneCount = inFlightByLane[lane, default: 0]
        precondition(laneCount > 0)
        if laneCount == 1 { inFlightByLane.removeValue(forKey: lane) }
        else { inFlightByLane[lane] = laneCount - 1 }
        if update.usesReservedLaneCapacity {
            reservedLanes.remove(lane)
            reservedBytes -= update.json.count
        }
        condition.broadcast()
        condition.unlock()
    }

    /// Waits for queued and delivered work to finish after input has closed.
    public func waitUntilDrained() {
        condition.lock()
        while storedItemCount > 0 || inFlightItemCount > 0 { condition.wait() }
        condition.unlock()
    }

    /// Wakes blocked producers and the consumer. Accepted events remain queued
    /// and are returned by take() before it reports end-of-stream.
    public func close(allowInFlightReceive: Bool = false) {
        condition.lock()
        closed = true
        allowFinalInFlightAppend = allowFinalInFlightAppend || allowInFlightReceive
        condition.broadcast()
        condition.unlock()
    }

    private func isFull(for update: BufferedTDLibUpdate, lane: Lane) -> Bool {
        let outstandingItems = storedItemCount + inFlightItemCount
        if outstandingItems == 0 { return false }
        if hasMainCapacity(for: update.json.count) { return false }
        return !canUseReservedCapacity(for: update, lane: lane)
    }

    private func hasMainCapacity(for nextItemBytes: Int) -> Bool {
        let outstandingItems = storedItemCount + inFlightItemCount
        let outstandingBytes = storedByteCount + inFlightByteCount
        return outstandingItems < capacity
            && outstandingBytes <= byteCapacity
            && nextItemBytes <= byteCapacity - outstandingBytes
    }

    private func canUseReservedCapacity(for update: BufferedTDLibUpdate, lane: Lane) -> Bool {
        guard !reservedLanes.contains(lane),
              (storage[lane]?.count ?? 0) + inFlightByLane[lane, default: 0] == 0,
              reservedBytes <= reservedByteCapacity,
              update.json.count <= reservedByteCapacity - reservedBytes else { return false }
        switch lane {
        case .client:
            return reservedLanes.reduce(into: 0) { count, reservedLane in
                if case .client = reservedLane { count += 1 }
            } < 20
        case .unrouteable:
            return true
        }
    }

    private func lane(for update: BufferedTDLibUpdate) -> Lane {
        guard let clientID = update.clientID else { return .unrouteable }
        return .client(clientID)
    }
}

/// Owns exactly one TDLib receive worker and a fair routing stage. Each client has
/// an asynchronous serial delivery lane: one slow account callback does not hold
/// the reducer at the head of every other account's stream. Shared capacity stays
/// charged until callbacks finish, preserving explicit backpressure and no-loss
/// behavior without creating a thread per account.
public final class TDLibUpdatePipeline: @unchecked Sendable {
    private let gateway: TDLibGateway
    private let coordinator: RuntimeCoordinator
    let buffer: TDLibUpdateBuffer
    private let delivery = TDLibUpdateDeliveryScheduler()
    private let lock = NSLock()
    private let reducerExited = DispatchGroup()
    private var started = false
    private var drainRequested = false

    public init(
        gateway: TDLibGateway,
        coordinator: RuntimeCoordinator,
        capacity: Int = 2_048,
        byteCapacity: Int = 64 * 1_024 * 1_024
    ) {
        self.gateway = gateway
        self.coordinator = coordinator
        self.buffer = TDLibUpdateBuffer(capacity: capacity, byteCapacity: byteCapacity)
    }

    public func start(
        onEvent: @escaping @Sendable (TDLibPipelineEvent) async -> Void,
        onReceiveFailure: @escaping @Sendable (TDLibGatewayError) async -> Void = { _ in }
    ) {
        lock.lock()
        precondition(!started, "TDLib update pipeline may only be started once")
        started = true
        reducerExited.enter()
        lock.unlock()

        let reducer = Thread { [buffer, coordinator, reducerExited, delivery] in
            defer { reducerExited.leave() }
            while let update = buffer.take() {
                let completed = DispatchSemaphore(value: 0)
                Task {
                    let event: TDLibPipelineEvent
                    do {
                        event = .routed(try await coordinator.routeUpdate(update))
                    } catch let error as TDLibRoutingError {
                        event = .routingFailure(error)
                    } catch {
                        event = .routingFailure(.malformedUpdate)
                    }
                    delivery.enqueue(event, update: update, buffer: buffer, onEvent: onEvent)
                    completed.signal()
                }
                // Route each event in ingress order before starting its client lane.
                completed.wait()
            }
            buffer.waitUntilDrained()
        }
        reducer.name = "NeTelegram.TDLib.reducer"
        reducer.start()

        gateway.startSingleReceiveWorker(
            onUpdate: { [buffer] update in
                buffer.admit(update)
            },
            onFailure: { [buffer, reducerExited] failure in
                // The receive worker has returned from td_receive and cannot
                // append another item. Close input, drain every accepted update,
                // then surface the terminal failure to the application.
                buffer.close()
                DispatchQueue.global(qos: .userInitiated).async {
                    reducerExited.wait()
                    Task { await onReceiveFailure(failure) }
                }
            }
        )
    }

    /// Stops TDLib input and closes admission immediately. Closing the buffer
    /// wakes a receive callback blocked on backpressure; that sole in-flight
    /// callback may append its already-received JSON once, after which no new
    /// input is admitted. Accepted events remain queued for finishInputAndDrain.
    public func requestInputStop() {
        lock.lock()
        guard started else {
            lock.unlock()
            gateway.requestWorkerStop()
            return
        }
        let shouldClose = !drainRequested
        drainRequested = true
        lock.unlock()

        gateway.requestWorkerStop()
        if shouldClose { buffer.close(allowInFlightReceive: true) }
    }

    /// Call only after the receive worker has exited. This closes the FIFO,
    /// drains accepted updates in order, and waits until the reducer callback
    /// for the final update has completed.
    public func finishInputAndDrain() {
        lock.lock()
        guard started else {
            lock.unlock()
            return
        }
        let shouldClose = !drainRequested
        drainRequested = true
        lock.unlock()

        if shouldClose { buffer.close() }
        reducerExited.wait()
    }
}

/// Serializes callbacks within each client while allowing independent client lanes
/// to make progress concurrently. These are tasks, not account-owned threads.
final class TDLibUpdateDeliveryScheduler: @unchecked Sendable {
    private enum Lane: Hashable {
        case client(ClientID)
        case unrouteable
    }

    private struct Work: Sendable {
        let event: TDLibPipelineEvent
        let update: BufferedTDLibUpdate
        let buffer: TDLibUpdateBuffer
        let callback: @Sendable (TDLibPipelineEvent) async -> Void
    }

    private struct WorkQueue {
        var items: [Work] = []
        var head = 0

        mutating func append(_ work: Work) { items.append(work) }

        mutating func take() -> Work? {
            guard head < items.count else { return nil }
            let work = items[head]
            head += 1
            if head >= 256 && head * 2 >= items.count {
                items.removeFirst(head)
                head = 0
            }
            return work
        }

        var isEmpty: Bool { head >= items.count }
    }

    private let lock = NSLock()
    private var queues: [Lane: WorkQueue] = [:]
    private var draining: Set<Lane> = []

    func enqueue(
        _ event: TDLibPipelineEvent,
        update: BufferedTDLibUpdate,
        buffer: TDLibUpdateBuffer,
        onEvent: @escaping @Sendable (TDLibPipelineEvent) async -> Void
    ) {
        let lane = update.clientID.map(Lane.client) ?? .unrouteable
        lock.lock()
        queues[lane, default: WorkQueue()].append(Work(event: event, update: update, buffer: buffer, callback: onEvent))
        let shouldStart = draining.insert(lane).inserted
        lock.unlock()

        if shouldStart {
            Task { await drain(lane) }
        }
    }

    private func drain(_ lane: Lane) async {
        while let work = take(lane) {
            await work.callback(work.event)
            work.buffer.complete(work.update)
        }
    }

    private func take(_ lane: Lane) -> Work? {
        lock.lock()
        defer { lock.unlock() }
        guard var queue = queues[lane], let work = queue.take() else {
            queues.removeValue(forKey: lane)
            draining.remove(lane)
            return nil
        }
        if queue.isEmpty {
            queues.removeValue(forKey: lane)
        } else {
            queues[lane] = queue
        }
        return work
    }
}
