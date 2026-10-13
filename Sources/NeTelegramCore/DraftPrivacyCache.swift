import Foundation

/// Separates drafts that could not be persisted from presentation memory while
/// the privacy lock is active. Recovery values are restored only after unlock.
public enum DraftPrivacyCache {
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
