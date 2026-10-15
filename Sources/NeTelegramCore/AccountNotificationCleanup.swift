public enum AccountNotificationCleanup {
    /// Replaces one account's active notification snapshot while retaining
    /// routes for transient push-only entries that were already active.
    /// Returns identifiers that the caller must remove from Notification Center.
    @discardableResult
    public static func reconcile(
        account: AccountUUID,
        candidates: [RoutedTDLibNotification],
        preserving identifiersToPreserve: Set<String> = [],
        identifiersByAccount: inout [AccountUUID: Set<String>],
        targetsByIdentifier: inout [String: RoutedTDLibNotification]
    ) -> Set<String> {
        var nextTargets: [String: RoutedTDLibNotification] = [:]
        for notification in candidates where notification.account == account {
            nextTargets[notification.systemIdentifier] = notification
        }

        let oldIdentifiers = identifiersByAccount[account] ?? []
        for identifier in identifiersToPreserve where oldIdentifiers.contains(identifier) {
            guard let previous = targetsByIdentifier[identifier],
                  previous.account == account,
                  previous.systemIdentifier == identifier else { continue }
            nextTargets[identifier] = previous
        }

        let nextIdentifiers = Set(nextTargets.keys)
        let staleTargetIdentifiers = Set(targetsByIdentifier.compactMap { identifier, target in
            target.account == account ? identifier : nil
        })
        let removed = oldIdentifiers.union(staleTargetIdentifiers).subtracting(nextIdentifiers)

        identifiersByAccount[account] = nextIdentifiers
        targetsByIdentifier = targetsByIdentifier.filter { $0.value.account != account }
        targetsByIdentifier.merge(nextTargets) { _, new in new }
        return removed
    }

    /// Applies a TDLib group delta using identifiers scoped by account and
    /// group. Routes supplied for another account/group are ignored.
    @discardableResult
    public static func applyGroupUpdate(
        account: AccountUUID,
        groupID: Int32,
        removedNotificationIDs: Set<Int32>,
        added: [RoutedTDLibNotification],
        identifiersByAccount: inout [AccountUUID: Set<String>],
        targetsByIdentifier: inout [String: RoutedTDLibNotification]
    ) -> Set<String> {
        let removed = Set(removedNotificationIDs.map {
            RoutedTDLibNotification.systemIdentifier(account: account, groupID: groupID, notificationID: $0)
        })
        var active = identifiersByAccount[account] ?? []
        active.subtract(removed)
        for identifier in removed {
            guard let target = targetsByIdentifier[identifier],
                  target.account == account,
                  target.groupID == groupID else { continue }
            targetsByIdentifier.removeValue(forKey: identifier)
        }

        for notification in added where notification.account == account && notification.groupID == groupID {
            active.insert(notification.systemIdentifier)
            targetsByIdentifier[notification.systemIdentifier] = notification
        }
        identifiersByAccount[account] = active
        return removed
    }

    /// Replaces or removes one route. A mismatched identity/identifier fails
    /// closed and asks the caller to clear any existing OS presentation.
    @discardableResult
    public static func replace(
        account: AccountUUID,
        identifier: String,
        with replacement: RoutedTDLibNotification?,
        identifiersByAccount: inout [AccountUUID: Set<String>],
        targetsByIdentifier: inout [String: RoutedTDLibNotification]
    ) -> Set<String> {
        guard let replacement,
              replacement.account == account,
              replacement.systemIdentifier == identifier else {
            identifiersByAccount[account, default: []].remove(identifier)
            if targetsByIdentifier[identifier]?.account == account {
                targetsByIdentifier.removeValue(forKey: identifier)
            }
            return [identifier]
        }

        identifiersByAccount[account, default: []].insert(identifier)
        targetsByIdentifier[identifier] = replacement
        return []
    }

    /// Removes only one account's routes and returns system notification IDs
    /// that the caller must remove from Notification Center.
    @discardableResult
    public static func remove(
        account: AccountUUID,
        identifiersByAccount: inout [AccountUUID: Set<String>],
        targetsByIdentifier: inout [String: RoutedTDLibNotification]
    ) -> Set<String> {
        let identifiers = identifiersByAccount.removeValue(forKey: account) ?? []
        targetsByIdentifier = targetsByIdentifier.filter { !identifiers.contains($0.key) }
        return identifiers
    }

    /// Removes OS notification previews/routes for deleted or expired messages
    /// without disturbing other accounts, chats, or active notifications.
    @discardableResult
    public static func removeMessages(
        account: AccountUUID,
        chatID: Int64,
        messageIDs: Set<Int64>,
        identifiersByAccount: inout [AccountUUID: Set<String>],
        targetsByIdentifier: inout [String: RoutedTDLibNotification]
    ) -> Set<String> {
        guard !messageIDs.isEmpty else { return [] }
        let removed = Set(targetsByIdentifier.compactMap { identifier, target in
            target.account == account
                && target.conversation.chatID == chatID
                && messageIDs.contains(target.messageID)
                ? identifier
                : nil
        })
        guard !removed.isEmpty else { return [] }
        targetsByIdentifier = targetsByIdentifier.filter { !removed.contains($0.key) }
        identifiersByAccount[account]?.subtract(removed)
        return removed
    }
}
