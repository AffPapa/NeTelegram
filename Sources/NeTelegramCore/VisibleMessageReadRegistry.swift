import Foundation

public struct VisibleMessageReadCandidate: Equatable, Sendable {
    public let messageID: Int64
    public let isIncoming: Bool
    public let canBeViewed: Bool

    public init(messageID: Int64, isIncoming: Bool, canBeViewed: Bool = true) {
        self.messageID = messageID
        self.isIncoming = isIncoming
        self.canBeViewed = canBeViewed
    }
}

public struct VisibleMessageReadRequest: Equatable, Sendable {
    public let conversation: ConversationKey
    public let runtimeGeneration: RuntimeGeneration
    public let messageIDs: [Int64]

    public init(conversation: ConversationKey, runtimeGeneration: RuntimeGeneration, messageIDs: [Int64]) {
        self.conversation = conversation
        self.runtimeGeneration = runtimeGeneration
        self.messageIDs = messageIDs
    }
}

/// Deduplicates view/read requests without retaining unbounded chat history.
/// The caller supplies IDs whose complete message presentation is in the viewport.
public struct VisibleMessageReadRegistry: Sendable {
    private var completed = Set<MessageKey>()
    private var completionOrder: [MessageKey] = []
    private var pendingByExtra: [String: VisibleMessageReadRequest] = [:]
    private let maximumRetainedMessages: Int

    public init(maximumRetainedMessages: Int = 4_096) {
        self.maximumRetainedMessages = max(1, maximumRetainedMessages)
    }

    public func candidateIDs(
        messages: [VisibleMessageReadCandidate],
        fullyVisibleMessageIDs: Set<Int64>,
        conversation: ConversationKey,
        runtimeGeneration: RuntimeGeneration
    ) -> [Int64] {
        let pendingIDs = pendingByExtra.values
            .filter { $0.conversation == conversation && $0.runtimeGeneration == runtimeGeneration }
            .reduce(into: Set<Int64>()) { $0.formUnion($1.messageIDs) }
        var seen = Set<Int64>()
        return messages.compactMap { candidate in
            let id = candidate.messageID
            guard id > 0,
                  candidate.isIncoming,
                  candidate.canBeViewed,
                  fullyVisibleMessageIDs.contains(id),
                  seen.insert(id).inserted,
                  !completed.contains(MessageKey(conversation: conversation, messageID: id)),
                  !pendingIDs.contains(id) else { return nil }
            return id
        }
    }

    /// Reserves the IDs before dispatch so a scroll/layout callback cannot enqueue duplicates.
    @discardableResult
    public mutating func begin(
        extra: String,
        conversation: ConversationKey,
        runtimeGeneration: RuntimeGeneration,
        messageIDs: [Int64]
    ) -> VisibleMessageReadRequest? {
        guard !extra.isEmpty, pendingByExtra[extra] == nil else { return nil }
        let pendingIDs = pendingByExtra.values
            .filter { $0.conversation == conversation && $0.runtimeGeneration == runtimeGeneration }
            .reduce(into: Set<Int64>()) { $0.formUnion($1.messageIDs) }
        var unique = Set<Int64>()
        let eligible = messageIDs.filter { id in
            id > 0
                && unique.insert(id).inserted
                && !completed.contains(MessageKey(conversation: conversation, messageID: id))
                && !pendingIDs.contains(id)
        }
        guard !eligible.isEmpty else { return nil }
        let request = VisibleMessageReadRequest(
            conversation: conversation,
            runtimeGeneration: runtimeGeneration,
            messageIDs: eligible
        )
        pendingByExtra[extra] = request
        return request
    }

    /// Resolves only the originating account and generation. Failed requests become eligible again.
    @discardableResult
    public mutating func resolve(
        extra: String,
        account: AccountUUID,
        runtimeGeneration: RuntimeGeneration,
        succeeded: Bool
    ) -> VisibleMessageReadRequest? {
        guard let request = pendingByExtra[extra],
              request.conversation.account == account,
              request.runtimeGeneration == runtimeGeneration else { return nil }
        pendingByExtra.removeValue(forKey: extra)
        if succeeded {
            for id in request.messageIDs {
                let key = MessageKey(conversation: request.conversation, messageID: id)
                guard completed.insert(key).inserted else { continue }
                completionOrder.append(key)
            }
            while completionOrder.count > maximumRetainedMessages {
                completed.remove(completionOrder.removeFirst())
            }
        }
        return request
    }

    public mutating func remove(account: AccountUUID) {
        completed = Set(completed.filter { $0.conversation.account != account })
        completionOrder.removeAll { $0.conversation.account == account }
        pendingByExtra = pendingByExtra.filter { $0.value.conversation.account != account }
    }

    public mutating func removeAll() {
        completed.removeAll()
        completionOrder.removeAll()
        pendingByExtra.removeAll()
    }
}
