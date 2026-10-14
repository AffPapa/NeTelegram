import Foundation

/// Photo download admission belongs to transport state, not to the visible chat.
/// TDLib can finish a request after the user switches conversations or locks UI.
public enum PhotoDownloadSlotPolicy {
    /// Releases every active slot for this account/file pair, regardless of chat
    /// or topic. Returns the affected conversations for diagnostics/tests.
    @discardableResult
    public static func releaseCompleted(
        account: AccountUUID,
        fileID: Int32,
        from active: inout [ConversationKey: Set<Int32>]
    ) -> Set<ConversationKey> {
        var released = Set<ConversationKey>()
        for conversation in Array(active.keys) where conversation.account == account {
            guard active[conversation]?.remove(fileID) != nil else { continue }
            released.insert(conversation)
            if active[conversation]?.isEmpty == true {
                active.removeValue(forKey: conversation)
            }
        }
        return released
    }
}
