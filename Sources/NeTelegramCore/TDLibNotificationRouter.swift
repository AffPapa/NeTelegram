import Foundation

/// A TDLib notification routed through the runtime that produced it. IDs are
/// namespaced by account and group because TDLib's counters are per database.
public struct RoutedTDLibNotification: Hashable, Sendable {
    public let account: AccountUUID
    public let groupID: Int32
    public let notificationID: Int32
    public let conversation: ConversationKey
    public let messageID: Int64
    public let date: Int64
    public let isSilent: Bool
    public let showsPreview: Bool
    public let preview: String?

    public var systemIdentifier: String {
        Self.systemIdentifier(account: account, groupID: groupID, notificationID: notificationID)
    }

    public static func systemIdentifier(account: AccountUUID, groupID: Int32, notificationID: Int32) -> String {
        "netelegram.\(account.id.uuidString.lowercased()).\(groupID).\(notificationID)"
    }
}

public struct TDLibNotificationPresentation: Equatable, Sendable {
    public let title: String
    public let body: String
    public let playsSound: Bool

    public init(title: String, body: String, playsSound: Bool) {
        self.title = title
        self.body = body
        self.playsSound = playsSound
    }
}

/// Converts TDLib's per-client update payloads into explicit account/chat/topic
/// targets. Unknown topics and non-message notification kinds fail closed.
public enum TDLibNotificationRouter {
    /// Routes an update that replaces the content of an active notification.
    /// A NewPushMessage may not yet contain enough information to open a
    /// conversation; TDLib can later send this update with a full NewMessage.
    public static func routeUpdate(account: AccountUUID, update: [String: Any]) -> RoutedTDLibNotification? {
        guard update["@type"] as? String == "updateNotification",
              let groupID = (update["notification_group_id"] as? NSNumber)?.int32Value,
              let notification = update["notification"] as? [String: Any] else { return nil }
        return route(account: account, groupID: groupID, groupChatID: 0, notification: notification)
    }

    public static func presentation(
        for notification: RoutedTDLibNotification,
        isPrivacyLocked: Bool,
        chatTitle: String?,
        isReconciliation: Bool = false
    ) -> TDLibNotificationPresentation {
        let playsSound = !isReconciliation && !notification.isSilent
        guard !isPrivacyLocked else {
            return TDLibNotificationPresentation(title: ProductIdentity.displayName, body: "Новое сообщение", playsSound: playsSound)
        }
        return TDLibNotificationPresentation(
            title: chatTitle ?? "Новое сообщение",
            body: notification.showsPreview ? (notification.preview ?? "Новое сообщение") : "Новое сообщение",
            playsSound: playsSound
        )
    }

    public static func route(
        account: AccountUUID,
        groupID: Int32,
        groupChatID: Int64,
        notification: [String: Any]
    ) -> RoutedTDLibNotification? {
        guard let notificationID = (notification["id"] as? NSNumber)?.int32Value,
              let type = notification["type"] as? [String: Any],
              let typeName = type["@type"] as? String else { return nil }

        let message: [String: Any]
        let messageID: Int64
        let showsPreview: Bool
        switch typeName {
        case "notificationTypeNewMessage":
            guard let value = type["message"] as? [String: Any],
                  let id = (value["id"] as? NSNumber)?.int64Value else { return nil }
            message = value
            messageID = id
            showsPreview = type["show_preview"] as? Bool == true
        case "notificationTypeNewPushMessage":
            // The push-only form has no chat_id or topic_id. Do not infer a
            // main-chat route from its group: forum/topic identity is absent.
            return nil
        default:
            // Calls, secret-chat notices, and unknown future notification kinds
            // must not be misrepresented as ordinary message notifications.
            return nil
        }

        let chatID = (message["chat_id"] as? NSNumber)?.int64Value ?? groupChatID
        guard chatID != 0,
              let topic = topicKey(message["topic_id"] as? [String: Any]) else { return nil }
        let preview = showsPreview ? previewText(message["content"] as? [String: Any]) : nil
        return RoutedTDLibNotification(
            account: account,
            groupID: groupID,
            notificationID: notificationID,
            conversation: ConversationKey(account: account, chatID: chatID, topic: topic),
            messageID: messageID,
            date: (notification["date"] as? NSNumber)?.int64Value ?? 0,
            isSilent: notification["is_silent"] as? Bool ?? true,
            showsPreview: showsPreview,
            preview: preview
        )
    }

    private static func topicKey(_ object: [String: Any]?) -> ConversationTopicKey? {
        guard let object else { return .main }
        guard let type = object["@type"] as? String else { return nil }
        switch type {
        case "messageTopicThread":
            guard let id = (object["message_thread_id"] as? NSNumber)?.int64Value, id != 0 else { return nil }
            return .thread(messageThreadID: id)
        case "messageTopicForum":
            guard let id = (object["forum_topic_id"] as? NSNumber)?.int32Value, id != 0 else { return nil }
            return .forum(topicID: id)
        case "messageTopicDirectMessages":
            guard let id = (object["direct_messages_chat_topic_id"] as? NSNumber)?.int64Value, id != 0 else { return nil }
            return .directMessages(topicID: id)
        case "messageTopicSavedMessages":
            guard let id = (object["saved_messages_topic_id"] as? NSNumber)?.int64Value, id != 0 else { return nil }
            return .savedMessages(topicID: id)
        default:
            return nil
        }
    }

    private static func previewText(_ content: [String: Any]?) -> String? {
        guard let content, let type = content["@type"] as? String else { return nil }
        let formatted: [String: Any]?
        switch type {
        case "messageText": formatted = content["text"] as? [String: Any]
        case "messagePhoto", "messageVideo", "messageAnimation", "messageDocument": formatted = content["caption"] as? [String: Any]
        case "messageSticker": return "Стикер"
        case "messageVoiceNote": return "Голосовое сообщение"
        case "messageVideoNote": return "Видеосообщение"
        case "messageLocation", "messageVenue": return "Местоположение"
        case "messagePoll": return "Опрос"
        default: return "Новое сообщение"
        }
        guard let value = formatted?["text"] as? String else {
            switch type {
            case "messagePhoto": return "Фотография"
            case "messageVideo": return "Видео"
            case "messageAnimation": return "Анимация"
            case "messageDocument": return "Файл"
            default: return "Новое сообщение"
            }
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Новое сообщение" }
        return String(trimmed.prefix(240))
    }
}
