public enum AccountNotificationCleanup {
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
