import Foundation

public struct AccountSearchRequestContext: Hashable, Sendable {
    public let account: AccountUUID
    public let runtimeGeneration: RuntimeGeneration
    public let searchGeneration: UInt64

    public init(account: AccountUUID, runtimeGeneration: RuntimeGeneration, searchGeneration: UInt64) {
        self.account = account
        self.runtimeGeneration = runtimeGeneration
        self.searchGeneration = searchGeneration
    }

    public func acceptsResponse(
        from account: AccountUUID,
        runtimeGeneration: RuntimeGeneration,
        searchGeneration: UInt64,
        isLocked: Bool
    ) -> Bool {
        !isLocked
            && self.account == account
            && self.runtimeGeneration == runtimeGeneration
            && self.searchGeneration == searchGeneration
    }
}

public struct AccountSearchRequestRegistry: Sendable {
    private var requests: [String: AccountSearchRequestContext] = [:]

    public init() {}

    public var isEmpty: Bool { requests.isEmpty }

    public mutating func register(_ context: AccountSearchRequestContext, for extra: String) {
        requests[extra] = context
    }

    public mutating func take(for extra: String) -> AccountSearchRequestContext? {
        requests.removeValue(forKey: extra)
    }

    @discardableResult
    public mutating func remove(account: AccountUUID, runtimeGeneration: RuntimeGeneration? = nil) -> Int {
        let keys = requests.compactMap { key, context in
            context.account == account
                && (runtimeGeneration == nil || context.runtimeGeneration == runtimeGeneration)
                ? key : nil
        }
        for key in keys { requests.removeValue(forKey: key) }
        return keys.count
    }

    public mutating func removeAll() {
        requests.removeAll(keepingCapacity: true)
    }
}

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

    public mutating func removeAll(for account: AccountUUID) {
        let removed = Set(order.filter { $0.account == account })
        guard !removed.isEmpty else { return }
        order.removeAll { removed.contains($0) }
        for key in removed { rows.removeValue(forKey: key) }
        counts.removeValue(forKey: account)
    }
}
