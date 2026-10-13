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
    public let photo: PhotoFileVariant?

    public init?(tdlibObject: [String: Any]) {
        guard let messageID = (tdlibObject["message_id"] as? NSNumber)?.int64Value,
              let title = tdlibObject["title"] as? String,
              let content = tdlibObject["content"] as? [String: Any],
              let sponsor = tdlibObject["sponsor"] as? [String: Any] else { return nil }
        let contentType = content["@type"] as? String ?? ""
        let photo: PhotoFileVariant?
        if contentType == "messagePhoto",
           let photoObject = content["photo"] as? [String: Any],
           let sizes = photoObject["sizes"] as? [[String: Any]] {
            photo = PhotoSizeCatalog.original(from: sizes)
        } else {
            photo = nil
        }
        let text: String
        let formattedContent = contentType == "messageText"
            ? content["text"] as? [String: Any]
            : contentType == "messagePhoto" ? content["caption"] as? [String: Any] : nil
        if let formatted = formattedContent,
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
        self.photo = photo
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

    /// Returns insertion points after ordinary messages, without splitting albums.
    /// TDLib defines `messages_between` as the minimum ordinary-message distance
    /// between sponsored messages; zero means only one sponsored message is shown.
    public static func placements(
        cardCount: Int,
        ordinaryMessageCount: Int,
        albumEndMessageCounts: [Int],
        messagesBetween: Int32
    ) -> [SponsoredMessagePlacement] {
        guard cardCount > 0 else { return [] }
        let total = max(0, ordinaryMessageCount)
        var result = [SponsoredMessagePlacement(cardIndex: 0, afterMessageCount: total)]
        guard messagesBetween > 0 else { return result }

        let boundaries = Set(albumEndMessageCounts.filter { $0 >= 0 && $0 < total } + [0])
            .sorted(by: >)
        var previous = total
        for cardIndex in 1..<cardCount {
            guard let boundary = boundaries.first(where: { previous - $0 >= Int(messagesBetween) }) else { break }
            result.append(SponsoredMessagePlacement(cardIndex: cardIndex, afterMessageCount: boundary))
            previous = boundary
        }
        return result
    }
}

public struct SponsoredMessagePlacement: Equatable, Sendable {
    public let cardIndex: Int
    public let afterMessageCount: Int

    public init(cardIndex: Int, afterMessageCount: Int) {
        self.cardIndex = cardIndex
        self.afterMessageCount = afterMessageCount
    }
}
