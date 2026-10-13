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
}
