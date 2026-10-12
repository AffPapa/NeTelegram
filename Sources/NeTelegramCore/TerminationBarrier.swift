import Foundation

/// Tracks the app-wide quit barrier across account closes and TDLib's final
/// receive/reducer drain. A quit is not complete merely because no account
/// routes remain; the shared worker and accepted updates must also finish.
public struct TerminationBarrier: Sendable, Equatable {
    private enum Phase: Sendable, Equatable {
        case idle
        case closingAccounts
        case drainingReceiver
        case finished
    }

    private var phase: Phase = .idle

    public init() {}

    public var isPending: Bool {
        phase == .closingAccounts || phase == .drainingReceiver
    }

    public var isFinished: Bool { phase == .finished }

    public mutating func begin() {
        guard phase != .finished else { return }
        phase = .closingAccounts
    }

    /// Used when TDLib rejects a close and AppKit must cancel this quit attempt.
    public mutating func cancel() {
        guard phase != .finished else { return }
        phase = .idle
    }

    /// Transitions only a pending quit into the final shared-worker drain.
    @discardableResult
    public mutating func beginReceiverDrain() -> Bool {
        guard phase == .closingAccounts else { return false }
        phase = .drainingReceiver
        return true
    }

    /// Approves termination exactly once, and only after the receiver and
    /// accepted update pipeline have both drained.
    @discardableResult
    public mutating func finishReceiverDrain() -> Bool {
        guard phase == .drainingReceiver else { return false }
        phase = .finished
        return true
    }
}
