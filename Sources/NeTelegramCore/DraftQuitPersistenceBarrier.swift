import Foundation

/// Persists dirty account drafts in a deterministic order before application
/// termination. A failed save leaves that account and every unattempted account
/// dirty so a later quit attempt can retry without losing the in-memory copy.
public enum DraftQuitPersistenceBarrier {
    public enum Outcome: Equatable, Sendable {
        case complete
        case blocked(account: AccountUUID)
    }

    public enum PersistenceError: Error {
        case unavailable
    }

    /// Removes an account from `dirtyAccounts` only after `persist` returns.
    /// Accounts are ordered by their durable UUID to make partial-failure
    /// behavior reproducible and straightforward to audit.
    public static func flush(
        dirtyAccounts: inout Set<AccountUUID>,
        persist: (AccountUUID) throws -> Void
    ) -> Outcome {
        let orderedAccounts = dirtyAccounts.sorted { $0.id.uuidString < $1.id.uuidString }
        for account in orderedAccounts {
            do {
                try persist(account)
                dirtyAccounts.remove(account)
            } catch {
                return .blocked(account: account)
            }
        }
        return .complete
    }
}
