import Foundation

public enum TDLibPipelineEvent: Sendable {
    case routed(RoutedTDLibUpdate)
    case routingFailure(TDLibRoutingError)
}

/// A bounded FIFO between the one blocking td_receive worker and ordered
/// reducer delivery. When full, the producer blocks and stops calling
/// td_receive; it never drops authorization, deletion, TTL, or ordinary updates.
public final class TDLibUpdateBuffer: @unchecked Sendable {
    private let condition = NSCondition()
    private let capacity: Int
    private let byteCapacity: Int
    private var storage: [Data] = []
    private var head = 0
    private var storedByteCount = 0
    private var waitingAppends = 0

    public init(capacity: Int = 2_048, byteCapacity: Int = 64 * 1_024 * 1_024) {
        self.capacity = max(1, capacity)
        self.byteCapacity = max(1, byteCapacity)
    }

    public var count: Int {
        condition.lock()
        defer { condition.unlock() }
        return storage.count - head
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

    /// Blocks until capacity is available. False is reserved for future
    /// shutdown use; this implementation stays open for the process lifetime.
    @discardableResult
    public func append(_ update: Data) -> Bool {
        condition.lock()
        while isFull(for: update.count) {
            waitingAppends += 1
            condition.wait()
            waitingAppends -= 1
        }
        storage.append(update)
        storedByteCount += update.count
        condition.signal()
        condition.unlock()
        return true
    }

    public func take() -> Data {
        condition.lock()
        while head == storage.count { condition.wait() }
        let update = storage[head]
        head += 1
        storedByteCount -= update.count
        if head >= 256 && head * 2 >= storage.count {
            storage.removeFirst(head)
            head = 0
        }
        condition.broadcast()
        condition.unlock()
        return update
    }

    private func isFull(for nextItemBytes: Int) -> Bool {
        let itemCount = storage.count - head
        if itemCount >= capacity { return true }
        if itemCount == 0 { return false }
        if storedByteCount <= byteCapacity, nextItemBytes <= byteCapacity - storedByteCount {
            return false
        }
        // Never drop a TDLib update just because a single response exceeds the
        // normal budget. Admit it only into an empty queue, which prevents any
        // other item from being retained beside it until it has been consumed.
        return true
    }
}

/// Owns exactly one TDLib receive worker and a serial, ordered routing stage.
/// The reducer waits for each callback to finish before taking the next update.
/// UI consumers must synchronously hop to MainActor so backpressure reaches the
/// bounded FIFO instead of accumulating an unbounded main-queue backlog.
public final class TDLibUpdatePipeline: @unchecked Sendable {
    private let gateway: TDLibGateway
    private let coordinator: RuntimeCoordinator
    private let buffer: TDLibUpdateBuffer
    private let lock = NSLock()
    private var started = false

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
        lock.unlock()

        let reducer = Thread { [buffer, coordinator] in
            while true {
                let update = buffer.take()
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
}
