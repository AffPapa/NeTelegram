import Foundation

public struct ForumTopicDescriptor: Identifiable, Hashable, Sendable {
    public let id: Int32
    public let title: String
    public let isGeneral: Bool
    public let isClosed: Bool

    public init(id: Int32, title: String, isGeneral: Bool = false, isClosed: Bool = false) {
        self.id = id
        self.title = title
        self.isGeneral = isGeneral
        self.isClosed = isClosed
    }
}

/// Parses only the stable identity and display name needed by a read-only topic picker.
public enum ForumTopicCatalog {
    public static func parse(_ values: [[String: Any]]) -> [ForumTopicDescriptor] {
        let parsed = values.compactMap { value -> ForumTopicDescriptor? in
            guard let info = value["info"] as? [String: Any],
                  let id = (info["forum_topic_id"] as? NSNumber)?.int32Value,
                  id > 0,
                  let title = info["name"] as? String,
                  !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return ForumTopicDescriptor(
                id: id,
                title: title,
                isGeneral: info["is_general"] as? Bool ?? false,
                isClosed: info["is_closed"] as? Bool ?? false
            )
        }
        var seen = Set<Int32>()
        return parsed.filter { seen.insert($0.id).inserted }.sorted {
            if $0.isGeneral != $1.isGeneral { return $0.isGeneral }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }
}
