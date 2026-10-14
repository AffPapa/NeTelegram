import Foundation

/// Keeps the exact search target together while AppKit changes accounts and
/// prepares the topic-specific history request.
public struct SearchResultNavigationPlan: Hashable, Sendable {
    public enum TopicSelection: Hashable, Sendable {
        case main
        case forum(topicID: Int32)
        case typed(ConversationTopicKey)
    }

    public let conversation: ConversationKey
    public let topicSelection: TopicSelection
    public let historyAnchorMessageID: Int64?

    public init(conversation: ConversationKey, messageID: Int64?) {
        self.conversation = conversation
        self.historyAnchorMessageID = messageID
        switch conversation.topic {
        case .main:
            self.topicSelection = .main
        case .forum(let topicID):
            self.topicSelection = .forum(topicID: topicID)
        case .thread, .directMessages, .savedMessages:
            self.topicSelection = .typed(conversation.topic)
        }
    }
}
