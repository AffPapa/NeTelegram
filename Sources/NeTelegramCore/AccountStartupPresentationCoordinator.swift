/// Keeps account selection intent stable while profile runtimes finish opening
/// asynchronously. The first restored runtime may initialize an empty window,
/// but a late background startup cannot replace a newer user selection.
@MainActor
public final class AccountStartupPresentationCoordinator {
    public private(set) var selectedAccountIntent: AccountUUID?
    public private(set) var selectionRevision: UInt64 = 0

    public init() {}

    public func select(_ account: AccountUUID) {
        selectedAccountIntent = account
        selectionRevision &+= 1
    }

    /// A first restored or explicitly requested startup runtime can initialize
    /// an otherwise unselected window. Record that implicit choice so async
    /// close/cleanup work can finish its presentation transition safely.
    /// Never replace an intent that arrived while this runtime was starting.
    public func adoptStartupPresentationIfUnselected(_ account: AccountUUID) {
        guard selectedAccountIntent == nil else { return }
        select(account)
    }

    /// Async cleanup may only update the window if the user's selection has
    /// not changed since that cleanup began.
    public func selectionIsCurrent(account: AccountUUID, revision: UInt64) -> Bool {
        selectedAccountIntent == account && selectionRevision == revision
    }

    public func shouldPresentStartupRuntime(
        account: AccountUUID,
        explicitlySelected: Bool,
        hasPresentedRuntime: Bool
    ) -> Bool {
        if let selectedAccountIntent { return selectedAccountIntent == account }
        return explicitlySelected || !hasPresentedRuntime
    }
}
