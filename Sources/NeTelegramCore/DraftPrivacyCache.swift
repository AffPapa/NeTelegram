import Foundation

/// Separates drafts that could not be persisted from presentation memory while
/// the privacy lock is active. Recovery values are restored only after unlock.
public enum DraftPrivacyCache {
    /// Removes only the exact text confirmed by TDLib from both visible and
    /// lock-time recovery memory. A newer draft for the same conversation is
    /// preserved, and the caller retains the account dirty barrier until all
    /// remaining drafts are durable.
    @discardableResult
    public static func removeIfMatching(
        _ conversation: ConversationKey,
        text: String,
        presentationDrafts: inout [ConversationKey: String],
        lockedDirtyDrafts: inout [ConversationKey: String]
    ) -> Bool {
        var removed = false
        if presentationDrafts[conversation] == text {
            presentationDrafts.removeValue(forKey: conversation)
            removed = true
        }
        if lockedDirtyDrafts[conversation] == text {
            lockedDirtyDrafts.removeValue(forKey: conversation)
            removed = true
        }
        return removed
    }

    /// Builds the durable snapshot from both visible drafts and the private
    /// recovery cache used while locked. A failed lock-time write must not let
    /// a later quit overwrite the last durable copy with an empty presentation
    /// cache.
    public static func draftsForPersistence(
        account: AccountUUID,
        presentationDrafts: [ConversationKey: String],
        lockedDirtyDrafts: [ConversationKey: String]
    ) -> [ConversationKey: String] {
        var result = presentationDrafts.filter { $0.key.account == account }
        for (conversation, text) in lockedDirtyDrafts where conversation.account == account {
            result[conversation] = text
        }
        return result
    }

    @discardableResult
    public static func lock(
        presentationDrafts: inout [ConversationKey: String],
        dirtyAccounts: Set<AccountUUID>
    ) -> [ConversationKey: String] {
        let recoverable = presentationDrafts.filter { dirtyAccounts.contains($0.key.account) }
        presentationDrafts.removeAll(keepingCapacity: false)
        return recoverable
    }

    public static func unlock(
        presentationDrafts: inout [ConversationKey: String],
        lockedDirtyDrafts: inout [ConversationKey: String]
    ) {
        presentationDrafts.merge(lockedDirtyDrafts) { _, recovered in recovered }
        lockedDirtyDrafts.removeAll(keepingCapacity: false)
    }
}
