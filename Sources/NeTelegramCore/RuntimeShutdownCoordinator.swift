import Foundation

public enum RuntimeShutdownRejection: Sendable, Equatable {
    case alreadyPending
    case alreadyFinished

    public var userMessage: String {
        switch self {
        case .alreadyPending:
            return "Выход уже выполняется: дождитесь подтверждения закрытия аккаунтов и TDLib. Повторная команда не отправлена."
        case .alreadyFinished:
            return "Завершение TDLib уже подтверждено; повторная команда выхода не отправлена."
        }
    }
}

public enum RuntimeShutdownStartResult: Sendable, Equatable {
    case began
    case rejected(RuntimeShutdownRejection)
}

/// Owns the quit-only account-close acknowledgements and shared receiver drain.
/// Profile logout and identity-recovery closes remain outside this coordinator.
public struct RuntimeShutdownCoordinator: Sendable, Equatable {
    private var barrier = TerminationBarrier()
    private var pendingClients: Set<Int32> = []

    public init() {}

    public var isPending: Bool { barrier.isPending }
    public var isFinished: Bool { barrier.isFinished }
    public var pendingClientIDs: Set<Int32> { pendingClients }
    public var canDrainReceiver: Bool { barrier.isPending && pendingClients.isEmpty }

    /// Starts one quit attempt with the exact set of clients the app will close.
    @discardableResult
    public mutating func begin(clients: Set<Int32>) -> Bool {
        if case .began = beginReportingRejection(clients: clients) { return true }
        return false
    }

    /// Starts one quit attempt and preserves a user-visible reason when the
    /// existing close/drain barrier correctly refuses a duplicate attempt.
    @discardableResult
    public mutating func beginReportingRejection(clients: Set<Int32>) -> RuntimeShutdownStartResult {
        guard !barrier.isPending else { return .rejected(.alreadyPending) }
        guard !barrier.isFinished else { return .rejected(.alreadyFinished) }
        barrier.begin()
        pendingClients = clients
        return .began
    }

    /// Records one TDLib authorizationStateClosed update. Unknown or duplicate
    /// updates cannot satisfy the quit barrier.
    @discardableResult
    public mutating func acknowledgeClosed(clientID: Int32) -> Bool {
        guard barrier.isPending, pendingClients.remove(clientID) != nil else { return false }
        return true
    }

    /// An immediate close rejection cancels this quit attempt. The caller keeps
    /// accepted close requests in its general lifecycle set until they finish.
    private mutating func cancel() {
        guard !barrier.isFinished else { return }
        barrier.cancel()
        pendingClients.removeAll()
    }

    /// Cancels a quit attempt only for a client that was part of its expected
    /// close set. The app separately waits for any already-accepted closes.
    @discardableResult
    public mutating func cancelAfterCloseRejection(clientID: Int32) -> Bool {
        guard barrier.isPending, pendingClients.contains(clientID) else { return false }
        cancel()
        return true
    }

    /// The shared receive/reducer drain is allowed only after every expected
    /// account has acknowledged Closed.
    @discardableResult
    public mutating func beginReceiverDrain() -> Bool {
        guard pendingClients.isEmpty else { return false }
        return barrier.beginReceiverDrain()
    }

    @discardableResult
    public mutating func finishReceiverDrain() -> Bool {
        barrier.finishReceiverDrain()
    }
}
