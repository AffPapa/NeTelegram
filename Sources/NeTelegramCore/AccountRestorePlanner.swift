public enum AccountRestorePlanner {
    /// Keeps every planned account eligible for startup while excluding only
    /// runtimes that already exist or have an account-specific startup task.
    /// The input order is preserved for deterministic startup scheduling.
    public static func pendingStartupProfiles(
        candidates: [AccountProfile],
        running: Set<AccountUUID>,
        starting: Set<AccountUUID>
    ) -> [AccountProfile] {
        candidates.filter { !running.contains($0.id) && !starting.contains($0.id) }
    }

    /// Enqueues every eligible profile synchronously. The enqueue callback must
    /// hand startup to its bounded scheduler and return; it must not await a
    /// profile's authentication or network lifetime.
    @discardableResult
    public static func enqueueStartupProfiles(
        candidates: [AccountProfile],
        running: Set<AccountUUID>,
        starting: Set<AccountUUID>,
        enqueue: (AccountProfile) -> Void
    ) -> [AccountUUID] {
        let pending = pendingStartupProfiles(
            candidates: candidates,
            running: running,
            starting: starting
        )
        for profile in pending {
            enqueue(profile)
        }
        return pending.map(\.id)
    }

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
            $0.logoutCleanupPending != true
                && $0.unverifiedRemovalPending != true
                && pendingWithStoredDatabase.contains($0.id)
        }
        let recoverableAuthorized = authorized.filter {
            $0.logoutCleanupPending != true && $0.unverifiedRemovalPending != true
        }
        if !recoverablePending.isEmpty {
            return recoverableAuthorized + recoverablePending
        }
        if !recoverableAuthorized.isEmpty {
            return recoverableAuthorized
        }
        return Array(pending.filter {
            $0.logoutCleanupPending != true && $0.unverifiedRemovalPending != true
        }.prefix(1))
    }
}
