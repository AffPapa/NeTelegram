import Foundation

/// Builds the pinned TDLib history request for an exact conversation target.
/// Keeping topic identity in this request prevents notification navigation from
/// silently falling back to the chat's main timeline.
public enum ConversationHistoryRequest {
    public static func make(for conversation: ConversationKey, fromMessageID: Int64 = 0, limit: Int32 = 50) -> [String: Any] {
        switch conversation.topic {
        case .main:
            return ["@type": "getChatHistory", "chat_id": conversation.chatID, "from_message_id": fromMessageID, "offset": 0, "limit": limit, "only_local": false]
        case .thread(let messageThreadID):
            return ["@type": "getMessageThreadHistory", "chat_id": conversation.chatID, "message_id": messageThreadID, "from_message_id": fromMessageID, "offset": 0, "limit": limit]
        case .forum(let topicID):
            return ["@type": "getForumTopicHistory", "chat_id": conversation.chatID, "forum_topic_id": topicID, "from_message_id": fromMessageID, "offset": 0, "limit": limit]
        case .directMessages(let topicID):
            return ["@type": "getDirectMessagesChatTopicHistory", "chat_id": conversation.chatID, "topic_id": topicID, "from_message_id": fromMessageID, "offset": 0, "limit": limit]
        case .savedMessages(let topicID):
            return ["@type": "getSavedMessagesTopicHistory", "saved_messages_topic_id": topicID, "from_message_id": fromMessageID, "offset": 0, "limit": limit]
        }
    }
}
