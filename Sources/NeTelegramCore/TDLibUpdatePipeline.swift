import Foundation

public enum TDLibPipelineEvent: Sendable {
    case routed(RoutedTDLibUpdate)
    case routingFailure(TDLibRoutingError)
}

/// A bounded fair queue between the one blocking td_receive worker and the
/// reducer. Each client keeps FIFO order; ready clients take turns so a busy
/// account cannot indefinitely starve sparse accounts. Capacity and byte
/// budgets are shared across every lane. When full, the producer blocks and
/// stops calling td_receive; it never drops updates.
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
    private var storage: [Lane: LaneQueue] = [:]
    /// Contains only non-empty lanes. A lane moves to the tail after each take.
    private var readyLanes: [Lane] = []
    private var storedItemCount = 0
    private var storedByteCount = 0
    private var waitingAppends = 0
    private var closed = false

    public init(capacity: Int = 2_048, byteCapacity: Int = 64 * 1_024 * 1_024) {
        self.capacity = max(1, capacity)
        self.byteCapacity = max(1, byteCapacity)
    }

    public var count: Int {
        condition.lock()
        defer { condition.unlock() }
        return storedItemCount
    }

    /// Number of receive producers currently blocked by a full FIFO. The
    /// shared TDLib gateway has one producer; this is exposed for diagnostics
    /// and to make backpressure behavior observable in tests.
    public var blockedProducerCount: Int {
        condition.lock()
        defer { condition.unlock() }
        return waitingAppends
    }

    /// Bytes currently waiting for ordered reduction. The byte budget is shared
    /// by every account because TDLib has one process-wide receive stream.
    public var queuedByteCount: Int {
        condition.lock()
        defer { condition.unlock() }
        return storedByteCount
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
        let update = BufferedTDLibUpdate(json: json)
        condition.lock()
        while !closed && isFull(for: update.json.count) {
            waitingAppends += 1
            condition.wait()
            waitingAppends -= 1
        }
        guard !closed else {
            condition.unlock()
            return false
        }
        let lane = lane(for: update)
        if storage[lane] == nil {
            storage[lane] = LaneQueue()
            readyLanes.append(lane)
        }
        storage[lane, default: LaneQueue()].append(update)
        storedItemCount += 1
        storedByteCount += update.json.count
        condition.signal()
        condition.unlock()
        return true
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

    /// Wakes blocked producers and the consumer. Accepted events remain queued
    /// and are returned by take() before it reports end-of-stream.
    public func close() {
        condition.lock()
        closed = true
        condition.broadcast()
        condition.unlock()
    }

    private func isFull(for nextItemBytes: Int) -> Bool {
        if storedItemCount >= capacity { return true }
        if storedItemCount == 0 { return false }
        if storedByteCount <= byteCapacity, nextItemBytes <= byteCapacity - storedByteCount {
            return false
        }
        // Never drop a TDLib update just because a single response exceeds the
        // normal budget. Admit it only into an empty queue, which prevents any
        // other item from being retained beside it until it has been consumed.
        return true
    }

    private func lane(for update: BufferedTDLibUpdate) -> Lane {
        guard let clientID = update.clientID else { return .unrouteable }
        return .client(clientID)
    }
}

/// Owns exactly one TDLib receive worker and a fair routing stage. Updates remain
/// ordered within each client; cross-client delivery is round-robin. The reducer
/// waits for each callback to finish before taking the next update, allowing the
/// bounded ingress queue to provide explicit backpressure without silent loss.
public final class TDLibUpdatePipeline: @unchecked Sendable {
    private let gateway: TDLibGateway
    private let coordinator: RuntimeCoordinator
    private let buffer: TDLibUpdateBuffer
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

    public func start(onEvent: @escaping @Sendable (TDLibPipelineEvent) -> Void) {
        lock.lock()
        precondition(!started, "TDLib update pipeline may only be started once")
        started = true
        reducerExited.enter()
        lock.unlock()

        let reducer = Thread { [buffer, coordinator, reducerExited] in
            defer { reducerExited.leave() }
            while let update = buffer.take() {
                let completed = DispatchSemaphore(value: 0)
                Task {
                    do {
                        onEvent(.routed(try await coordinator.routeUpdate(update)))
                    } catch let error as TDLibRoutingError {
                        onEvent(.routingFailure(error))
                    } catch {
                        onEvent(.routingFailure(.malformedUpdate))
                    }
                    completed.signal()
                }
                // Do not let actor scheduling reorder the reducer stream.
                completed.wait()
            }
        }
        reducer.name = "NeTelegram.TDLib.reducer"
        reducer.start()

        gateway.startSingleReceiveWorker { [buffer] update in
            buffer.append(update)
        }
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
