public struct VerifiedIdentityGate: Sendable {
    public enum Decision: Equatable, Sendable {
        case accepted(Int64)
        case mismatch(expected: Int64, actual: Int64)
        case invalid
    }

    public private(set) var expectedUserID: Int64?
    public private(set) var verifiedUserID: Int64?

    public init(expectedUserID: Int64?) {
        self.expectedUserID = expectedUserID.flatMap { $0 > 0 ? $0 : nil }
    }

    /// Starts a new TDLib authorization cycle without changing the identity
    /// already bound to this local profile.
    public mutating func beginAuthorizationCycle() {
        verifiedUserID = nil
    }

    public mutating func verify(_ userID: Int64) -> Decision {
        guard userID > 0 else { return .invalid }
        if let expectedUserID, expectedUserID != userID {
            verifiedUserID = nil
            return .mismatch(expected: expectedUserID, actual: userID)
        }
        expectedUserID = userID
        verifiedUserID = userID
        return .accepted(userID)
    }
}
