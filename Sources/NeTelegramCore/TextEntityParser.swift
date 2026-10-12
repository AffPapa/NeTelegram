import Foundation

/// Detects explicit HTTP(S) links without rewriting message text. NSRange offsets
/// are UTF-16 code units, matching TDLib's `textEntity` contract.
public enum TextEntityParser {
    private static let urlExpression = try! NSRegularExpression(
        pattern: "https?://[^\\s<>]+",
        options: [.caseInsensitive]
    )
    private static let trailingPunctuation = CharacterSet(charactersIn: ".,!?;:")

    public static func entities(in text: String) -> [TextEntitySpan] {
        let source = text as NSString
        let fullRange = NSRange(location: 0, length: source.length)
        return urlExpression.matches(in: text, range: fullRange).compactMap { match in
            var range = match.range
            while range.length > 0 {
                let last = source.substring(with: NSRange(location: NSMaxRange(range) - 1, length: 1))
                guard let scalar = last.unicodeScalars.first, trailingPunctuation.contains(scalar) else { break }
                range.length -= 1
            }
            guard range.length > 0,
                  range.location <= Int(Int32.max),
                  range.length <= Int(Int32.max) else { return nil }
            let candidate = source.substring(with: range)
            guard let components = URLComponents(string: candidate),
                  ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
                  let host = components.host, !host.isEmpty else { return nil }
            return TextEntitySpan(
                offsetUTF16: Int32(range.location),
                lengthUTF16: Int32(range.length),
                type: "textEntityTypeUrl"
            )
        }
    }
}
