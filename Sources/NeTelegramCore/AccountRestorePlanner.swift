public enum AccountRestorePlanner {
    /// Restores every verified identity plus any unverified profile whose
    /// existing TDLib database may contain a session that needs identity
    /// recovery. A single empty login profile is opened only when nothing else
    /// can be restored, so stale empty placeholders do not create runtimes.
    public static func profilesToRestore(
        authorized: [AccountProfile],
        pending: [AccountProfile],
        pendingWithStoredDatabase: Set<AccountUUID>
    ) -> [AccountProfile] {
        let recoverablePending = pending.filter {
            $0.logoutCleanupPending != true && pendingWithStoredDatabase.contains($0.id)
        }
        let recoverableAuthorized = authorized.filter { $0.logoutCleanupPending != true }
        if !recoverablePending.isEmpty {
            return recoverableAuthorized + recoverablePending
        }
        if !recoverableAuthorized.isEmpty {
            return recoverableAuthorized
        }
        return Array(pending.filter { $0.logoutCleanupPending != true }.prefix(1))
    }
}
