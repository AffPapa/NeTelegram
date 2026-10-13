import Foundation

public struct SponsoredMessagesKey: Hashable, Sendable {
    public let account: AccountUUID
    public let generation: RuntimeGeneration
    public let chatID: Int64

    public init(account: AccountUUID, generation: RuntimeGeneration, chatID: Int64) {
        self.account = account
        self.generation = generation
        self.chatID = chatID
    }
}

public struct SponsoredMessageCard: Equatable, Sendable {
    public let messageID: Int64
    public let recommended: Bool
    public let reportable: Bool
    public let title: String
    public let text: String
    public let buttonText: String
    public let sponsorURL: String
    public let sponsorInfo: String
    public let additionalInfo: String
    public let contentType: String

    public init?(tdlibObject: [String: Any]) {
        guard let messageID = (tdlibObject["message_id"] as? NSNumber)?.int64Value,
              let title = tdlibObject["title"] as? String,
              let content = tdlibObject["content"] as? [String: Any],
              let sponsor = tdlibObject["sponsor"] as? [String: Any] else { return nil }
        let contentType = content["@type"] as? String ?? ""
        let text: String
        if contentType == "messageText",
           let formatted = content["text"] as? [String: Any],
           let value = formatted["text"] as? String {
            text = value
        } else {
            text = ""
        }
        self.messageID = messageID
        recommended = tdlibObject["is_recommended"] as? Bool ?? false
        reportable = tdlibObject["can_be_reported"] as? Bool ?? false
        self.title = title
        self.text = text
        buttonText = tdlibObject["button_text"] as? String ?? ""
        sponsorURL = sponsor["url"] as? String ?? ""
        sponsorInfo = sponsor["info"] as? String ?? ""
        additionalInfo = tdlibObject["additional_info"] as? String ?? ""
        self.contentType = contentType
    }
}

public struct SponsoredReportOption: Equatable, Sendable {
    public let id: String
    public let text: String

    public init?(tdlibObject: [String: Any]) {
        guard let id = tdlibObject["id"] as? String,
              let text = tdlibObject["text"] as? String,
              !id.isEmpty, !text.isEmpty else { return nil }
        self.id = id
        self.text = text
    }
}

public enum SponsoredReportResult {
    public static func options(from object: [String: Any]) -> [SponsoredReportOption] {
        (object["options"] as? [[String: Any]] ?? []).compactMap(SponsoredReportOption.init(tdlibObject:))
    }

    public static func type(from object: [String: Any]) -> String? {
        object["@type"] as? String
    }
}

public enum SponsoredMessagesPolicy {
    public static let cacheDuration: TimeInterval = 5 * 60

    public static func shouldRequest(lastFetchedAt: Date?, now: Date) -> Bool {
        guard let lastFetchedAt else { return true }
        let age = now.timeIntervalSince(lastFetchedAt)
        return age < 0 || age >= cacheDuration
    }

    public static func request(chatID: Int64, extra: String) -> [String: Any] {
        ["@type": "getChatSponsoredMessages", "chat_id": chatID, "@extra": extra]
    }

    public static func click(chatID: Int64, messageID: Int64, media: Bool = false, fullscreen: Bool = false) -> [String: Any] {
        ["@type": "clickChatSponsoredMessage", "chat_id": chatID, "message_id": messageID, "is_media_click": media, "from_fullscreen": fullscreen]
    }

    public static func report(chatID: Int64, messageID: Int64, optionID: String = "", extra: String? = nil) -> [String: Any] {
        var request: [String: Any] = ["@type": "reportChatSponsoredMessage", "chat_id": chatID, "message_id": messageID, "option_id": optionID]
        if let extra { request["@extra"] = extra }
        return request
    }
}
