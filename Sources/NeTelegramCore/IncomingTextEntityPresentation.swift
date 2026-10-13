import Foundation

/// A validated range from TDLib's `formattedText.entities` array. Offsets are
/// UTF-16 code units, matching TDLib and NSString's range model.
public struct IncomingTextEntitySpan: Equatable, Sendable {
    public let offsetUTF16: Int
    public let lengthUTF16: Int
    public let type: String
    public let argument: String?

    public init(offsetUTF16: Int, lengthUTF16: Int, type: String, argument: String? = nil) {
        self.offsetUTF16 = offsetUTF16
        self.lengthUTF16 = lengthUTF16
        self.type = type
        self.argument = argument
    }
}

public enum IncomingTextEntityPresentation {
    private static let supportedTypes: Set<String> = [
        "textEntityTypeUrl",
        "textEntityTypeTextUrl",
        "textEntityTypeEmailAddress",
        "textEntityTypeBold",
        "textEntityTypeItalic",
        "textEntityTypeUnderline",
        "textEntityTypeStrikethrough",
        "textEntityTypeCode",
        "textEntityTypePre",
        "textEntityTypeSpoiler",
        "textEntityTypeMention",
        "textEntityTypeHashtag",
        "textEntityTypeCashtag",
        "textEntityTypeBotCommand",
        "textEntityTypePhoneNumber",
        "textEntityTypeBankCardNumber",
        "textEntityTypeMentionName",
        "textEntityTypeCustomEmoji",
        "textEntityTypeBlockQuote",
        "textEntityTypeExpandableBlockQuote",
    ]

    /// Parses TDLib JSON without assuming entity order, and drops malformed or
    /// out-of-bounds ranges so a bad server/entity offset cannot crash UI code.
    public static func spans(in formattedText: [String: Any]) -> [IncomingTextEntitySpan] {
        guard let text = formattedText["text"] as? String,
              let entities = formattedText["entities"] as? [[String: Any]] else { return [] }
        let utf16Length = (text as NSString).length
        return entities.compactMap { entity in
            guard let offset = (entity["offset"] as? NSNumber)?.intValue,
                  let length = (entity["length"] as? NSNumber)?.intValue,
                  offset >= 0,
                  length > 0,
                  offset <= utf16Length,
                  length <= utf16Length - offset,
                  let typeObject = entity["type"] as? [String: Any],
                  let type = typeObject["@type"] as? String,
                  supportedTypes.contains(type) else { return nil }
            let argument: String?
            switch type {
            case "textEntityTypeTextUrl":
                argument = typeObject["url"] as? String
            case "textEntityTypePre":
                argument = typeObject["language"] as? String
            case "textEntityTypeMentionName":
                if let userID = typeObject["user_id"] as? NSNumber {
                    argument = userID.stringValue
                } else {
                    argument = nil
                }
            default:
                argument = nil
            }
            return IncomingTextEntitySpan(
                offsetUTF16: offset,
                lengthUTF16: length,
                type: type,
                argument: argument
            )
        }
    }

    /// Resolves only links that can safely be handed to Launch Services. URLs
    /// typed as ordinary text may omit a scheme; explicit textUrl values must
    /// carry an allowed scheme. Unsupported entity kinds remain plain text.
    public static func destination(for span: IncomingTextEntitySpan, in text: String) -> URL? {
        let candidate: String
        switch span.type {
        case "textEntityTypeTextUrl":
            guard let argument = span.argument else { return nil }
            candidate = argument
        case "textEntityTypeUrl", "textEntityTypeEmailAddress":
            let source = text as NSString
            guard span.offsetUTF16 >= 0,
                  span.lengthUTF16 > 0,
                  span.offsetUTF16 <= source.length,
                  span.lengthUTF16 <= source.length - span.offsetUTF16 else { return nil }
            let visible = source.substring(with: NSRange(location: span.offsetUTF16, length: span.lengthUTF16))
            candidate = span.type == "textEntityTypeEmailAddress" ? "mailto:\(visible)" : visible
        default:
            return nil
        }

        var resolvedCandidate = candidate
        if span.type == "textEntityTypeUrl",
           !candidate.contains(":"),
           !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resolvedCandidate = "https://\(candidate)"
        }
        guard let components = URLComponents(string: resolvedCandidate),
              let scheme = components.scheme?.lowercased(),
              ["http", "https", "mailto", "tg"].contains(scheme),
              let url = components.url else { return nil }
        if ["http", "https"].contains(scheme) {
            guard let host = components.host, !host.isEmpty else { return nil }
        }
        return url
    }
}
