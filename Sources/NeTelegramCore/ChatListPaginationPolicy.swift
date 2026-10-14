/// Prevents repeated end-of-list notifications from issuing overlapping page
/// requests while allowing a later completion or account switch to retry.
public struct ChatListPaginationPolicy: Sendable, Equatable {
    private var triggeredAccounts: Set<AccountUUID> = []

    public init() {}

    public mutating func shouldRequestPage(
        account: AccountUUID,
        isNearEnd: Bool,
        loadState: ChatListLoadState.State
    ) -> Bool {
        guard isNearEnd else {
            triggeredAccounts.remove(account)
            return false
        }
        guard loadState == .loaded, !triggeredAccounts.contains(account) else { return false }
        triggeredAccounts.insert(account)
        return true
    }

    public mutating func pageDidComplete(for account: AccountUUID) {
        triggeredAccounts.remove(account)
    }
}
