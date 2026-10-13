import Foundation

/// Makes an awaited profile-restore continuation stale when the user quits.
/// This is useful when an underlying synchronous Keychain request cannot be
/// cancelled: the UI can proceed with its close barrier, and a late result
/// cannot start new account runtimes after shutdown begins.
public struct ProfileRestoreGenerationGate: Sendable {
    private var generation: UInt64 = 0

    public init() {}

    public mutating func begin() -> UInt64 {
        generation &+= 1
        return generation
    }

    @discardableResult
    public mutating func invalidate() -> UInt64 {
        generation &+= 1
        return generation
    }

    public func isCurrent(_ candidate: UInt64) -> Bool {
        candidate == generation
    }
}
