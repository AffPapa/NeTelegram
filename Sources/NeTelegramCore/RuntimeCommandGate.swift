import Foundation

/// Orders account commands against the TDLib close request. Once close has
/// been accepted, no later app command can enter the same client generation.
public final class RuntimeCommandGate: @unchecked Sendable {
    private let lock = NSLock()
    private var closing = false

    public init() {}

    @discardableResult
    public func dispatch(_ command: () throws -> Void) rethrows -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !closing else { return false }
        try command()
        return true
    }

    /// The close request is sent while holding the same lock as ordinary
    /// commands. A failed queue operation rolls the gate back so the runtime
    /// remains usable; an accepted close permanently rejects later commands.
    @discardableResult
    public func beginClosing(_ close: () throws -> Void) rethrows -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !closing else { return true }
        closing = true
        do {
            try close()
            return true
        } catch {
            closing = false
            throw error
        }
    }

    public var isClosing: Bool {
        lock.lock()
        defer { lock.unlock() }
        return closing
    }
}
