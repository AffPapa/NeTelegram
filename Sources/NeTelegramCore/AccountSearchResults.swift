import Foundation

public struct AccountSearchResultKey: Hashable, Sendable {
    public let account: AccountUUID
    public let conversation: ConversationKey?
    public let messageID: Int64?

    public init(account: AccountUUID, conversation: ConversationKey?, messageID: Int64?) {
        self.account = account
        self.conversation = conversation
        self.messageID = messageID
    }
}

public struct AccountSearchResult: Sendable {
    public let account: AccountUUID
    public let conversation: ConversationKey?
    public let messageID: Int64?
    public let title: String
    public let excerpt: String

    public init(account: AccountUUID, conversation: ConversationKey?, messageID: Int64? = nil, title: String, excerpt: String) {
        self.account = account
        self.conversation = conversation
        self.messageID = messageID
        self.title = title
        self.excerpt = excerpt
    }

    public var key: AccountSearchResultKey {
        AccountSearchResultKey(account: account, conversation: conversation, messageID: messageID)
    }
}

/// Ordered, deduplicated search snapshot with an explicit per-account cap.
/// Account and typed-topic identity are part of every key so results can never
/// collapse across profiles or forum topics.
public struct AccountSearchResults: Sendable {
    private let maximumPerAccount: Int
    private var order: [AccountSearchResultKey] = []
    private var rows: [AccountSearchResultKey: AccountSearchResult] = [:]
    private var counts: [AccountUUID: Int] = [:]

    public init(maximumPerAccount: Int = 20) {
        self.maximumPerAccount = max(1, maximumPerAccount)
    }

    @discardableResult
    public mutating func append(_ result: AccountSearchResult) -> Bool {
        let key = result.key
        guard result.conversation == nil || result.conversation?.account == result.account,
              rows[key] == nil,
              counts[result.account, default: 0] < maximumPerAccount else { return false }
        rows[key] = result
        order.append(key)
        counts[result.account, default: 0] += 1
        return true
    }

    public var values: [AccountSearchResult] { order.compactMap { rows[$0] } }
    public var isEmpty: Bool { order.isEmpty }

    public mutating func removeAll() {
        order.removeAll(keepingCapacity: true)
        rows.removeAll(keepingCapacity: true)
        counts.removeAll(keepingCapacity: true)
    }
}
