import Foundation

public struct ConversationHistoryRequestContext: Hashable, Sendable {
    public let conversation: ConversationKey
    public let runtimeGeneration: RuntimeGeneration
    public let requestGeneration: UInt64

    public init(conversation: ConversationKey, runtimeGeneration: RuntimeGeneration, requestGeneration: UInt64) {
        self.conversation = conversation
        self.runtimeGeneration = runtimeGeneration
        self.requestGeneration = requestGeneration
    }

    public func acceptsResponse(
        from account: AccountUUID,
        runtimeGeneration: RuntimeGeneration,
        requestGeneration: UInt64,
        isLocked: Bool
    ) -> Bool {
        !isLocked
            && conversation.account == account
            && self.runtimeGeneration == runtimeGeneration
            && self.requestGeneration == requestGeneration
    }
}

public struct ConversationHistoryRequestRegistry: Sendable {
    private var requests: [String: ConversationHistoryRequestContext] = [:]

    public init() {}

    public mutating func register(_ context: ConversationHistoryRequestContext, for extra: String) {
        requests[extra] = context
    }

    public mutating func take(for extra: String) -> ConversationHistoryRequestContext? {
        requests.removeValue(forKey: extra)
    }

    @discardableResult
    public mutating func remove(account: AccountUUID, runtimeGeneration: RuntimeGeneration? = nil) -> Int {
        let keys = requests.compactMap { key, context in
            context.conversation.account == account
                && (runtimeGeneration.map { context.runtimeGeneration == $0 } ?? true)
                ? key : nil
        }
        for key in keys { requests.removeValue(forKey: key) }
        return keys.count
    }

    public mutating func removeAll() {
        requests.removeAll(keepingCapacity: true)
    }
}
