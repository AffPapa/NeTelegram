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
        let recoverablePending = pending.filter { pendingWithStoredDatabase.contains($0.id) }
        if !recoverablePending.isEmpty {
            return authorized + recoverablePending
        }
        if !authorized.isEmpty {
            return authorized
        }
        return Array(pending.prefix(1))
    }
}
