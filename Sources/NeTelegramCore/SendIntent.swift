import Foundation

public enum ConversationTopicKey: Hashable, Codable, Sendable {
    case main
    case thread(messageThreadID: Int64)
    case forum(topicID: Int32)
    case directMessages(topicID: Int64)
    case savedMessages(topicID: Int64)
}

public struct ConversationKey: Hashable, Codable, Sendable {
    public let account: AccountUUID
    public let chatID: Int64
    public let topic: ConversationTopicKey

    public init(account: AccountUUID, chatID: Int64, topic: ConversationTopicKey = .main) {
        self.account = account
        self.chatID = chatID
        self.topic = topic
    }
}

public struct MessageKey: Hashable, Sendable {
    public let conversation: ConversationKey
    public let messageID: Int64

    public init(conversation: ConversationKey, messageID: Int64) {
        self.conversation = conversation
        self.messageID = messageID
    }
}

public struct TextEntitySpan: Hashable, Sendable {
    /// TDLib offsets are UTF-16 code-unit offsets, not Swift Character offsets.
    public let offsetUTF16: Int32
    public let lengthUTF16: Int32
    public let type: String

    public init(offsetUTF16: Int32, lengthUTF16: Int32, type: String) {
        self.offsetUTF16 = offsetUTF16
        self.lengthUTF16 = lengthUTF16
        self.type = type
    }
}

public struct SendAttachment: Hashable, Sendable {
    public let localFileURL: URL

    public init(localFileURL: URL) { self.localFileURL = localFileURL }
}

public struct ChatSendPermission: Sendable, Equatable {
    public let canSendBasicMessages: Bool
    public let isChannel: Bool
    public let defaultSenderTelegramUserID: Int64?

    public init(canSendBasicMessages: Bool, isChannel: Bool, defaultSenderTelegramUserID: Int64?) {
        self.canSendBasicMessages = canSendBasicMessages
        self.isChannel = isChannel
        self.defaultSenderTelegramUserID = defaultSenderTelegramUserID
    }

    public func permitsTextSend(as telegramUserID: Int64, topic: ConversationTopicKey, paidStars: Int64 = 0) -> Bool {
        canSendBasicMessages
            && !isChannel
            && defaultSenderTelegramUserID == telegramUserID
            && (topic == .main || isForumTopic(topic))
            && paidStars == 0
    }

    private func isForumTopic(_ topic: ConversationTopicKey) -> Bool {
        if case .forum = topic { return true }
        return false
    }
}

/// Immutable account and UI context captured before any asynchronous work.
public struct SendIntent: Sendable {
    public let account: AccountUUID
    public let expectedTelegramUserID: Int64
    public let runtimeGeneration: RuntimeGeneration
    public let conversation: ConversationKey
    public let replyToMessageID: Int64?
    public let sendAsUserID: Int64?
    public let text: String
    public let entities: [TextEntitySpan]
    public let attachments: [SendAttachment]
    public let privacyEpoch: UInt64

    public static let maximumPaidStars: Int64 = 0

    public init(
        account: AccountUUID,
        expectedTelegramUserID: Int64,
        runtimeGeneration: RuntimeGeneration,
        conversation: ConversationKey,
        replyToMessageID: Int64? = nil,
        sendAsUserID: Int64? = nil,
        text: String,
        entities: [TextEntitySpan] = [],
        attachments: [SendAttachment] = [],
        privacyEpoch: UInt64
    ) {
        self.account = account
        self.expectedTelegramUserID = expectedTelegramUserID
        self.runtimeGeneration = runtimeGeneration
        self.conversation = conversation
        self.replyToMessageID = replyToMessageID
        self.sendAsUserID = sendAsUserID
        self.text = text
        self.entities = entities
        self.attachments = attachments
        self.privacyEpoch = privacyEpoch
    }
}

/// Serializes privacy lock transitions against the exact td_send dispatch.
/// A caller's queued intent is invalid after any lock/unlock epoch transition.
public final class PrivacyDispatchBarrier: @unchecked Sendable {
    private let lock = NSLock()
    private var epoch: UInt64 = 0
    private var isLocked = false

    public init(locked: Bool = false) { isLocked = locked }

    @discardableResult
    public func setLocked(_ locked: Bool) -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        guard isLocked != locked else { return epoch }
        isLocked = locked
        epoch &+= 1
        return epoch
    }

    public func currentEpoch() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return epoch
    }

    @discardableResult
    public func dispatch(
        _ intent: SendIntent,
        currentAccount: AccountUUID,
        currentTelegramUserID: Int64,
        currentGeneration: RuntimeGeneration,
        send: () throws -> Void
    ) rethrows -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !isLocked,
              intent.privacyEpoch == epoch,
              intent.account == currentAccount,
              intent.conversation.account == currentAccount,
              intent.expectedTelegramUserID == currentTelegramUserID,
              intent.runtimeGeneration == currentGeneration else { return false }
        try send()
        return true
    }

    /// Serializes non-message user commands such as explicit account logout
    /// against privacy lock and account switching. The caller captures identity
    /// before any modal UI and supplies the current runtime immediately before
    /// dispatch.
    @discardableResult
    public func dispatchBoundUserCommand(
        account: AccountUUID,
        expectedTelegramUserID: Int64,
        runtimeGeneration: RuntimeGeneration,
        privacyEpoch: UInt64,
        currentAccount: AccountUUID,
        currentTelegramUserID: Int64,
        currentGeneration: RuntimeGeneration,
        send: () throws -> Void
    ) rethrows -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !isLocked,
              privacyEpoch == epoch,
              account == currentAccount,
              expectedTelegramUserID == currentTelegramUserID,
              runtimeGeneration == currentGeneration else { return false }
        try send()
        return true
    }
}
