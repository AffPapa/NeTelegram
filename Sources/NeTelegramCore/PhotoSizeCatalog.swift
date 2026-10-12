import Foundation

public struct PhotoFileVariant: Equatable, Sendable {
    public let fileID: Int32
    public let width: Int32
    public let height: Int32
    public let expectedSize: Int64
    public let canBeDownloaded: Bool
    public let localPath: String?
    public let isDownloaded: Bool

    public var pixelArea: Int64 { Int64(width) * Int64(height) }

    fileprivate init?(json: [String: Any]) {
        guard let width = (json["width"] as? NSNumber)?.int32Value, width > 0,
              let height = (json["height"] as? NSNumber)?.int32Value, height > 0,
              let photo = json["photo"] as? [String: Any],
              let fileID = (photo["id"] as? NSNumber)?.int32Value else { return nil }
        let local = photo["local"] as? [String: Any]
        self.fileID = fileID
        self.width = width
        self.height = height
        self.expectedSize = (photo["expected_size"] as? NSNumber)?.int64Value
            ?? (photo["size"] as? NSNumber)?.int64Value ?? 0
        self.canBeDownloaded = local?["can_be_downloaded"] as? Bool ?? true
        self.localPath = local?["path"] as? String
        self.isDownloaded = local?["is_downloading_completed"] as? Bool ?? false
    }
}

/// Chooses explicit TDLib photo variants. Previews stay near the UI's 960px
/// target; original access is an independent user action over the largest
/// available variant and never triggers a download by itself.
public enum PhotoSizeCatalog {
    public static func variants(from sizes: [[String: Any]]) -> [PhotoFileVariant] {
        sizes.compactMap(PhotoFileVariant.init(json:))
    }

    public static func preview(from sizes: [[String: Any]], targetPixelSize: Int32 = 960) -> PhotoFileVariant? {
        let candidates = variants(from: sizes)
        guard !candidates.isEmpty else { return nil }
        let targetArea = Int64(max(1, targetPixelSize)) * Int64(max(1, targetPixelSize))
        return candidates.filter { $0.pixelArea >= targetArea }.min(by: preferredOrder)
            ?? candidates.max(by: preferredOrder)
    }

    public static func original(from sizes: [[String: Any]]) -> PhotoFileVariant? {
        variants(from: sizes).max(by: preferredOrder)
    }

    private static func preferredOrder(_ lhs: PhotoFileVariant, _ rhs: PhotoFileVariant) -> Bool {
        if lhs.pixelArea != rhs.pixelArea { return lhs.pixelArea < rhs.pixelArea }
        if lhs.expectedSize != rhs.expectedSize { return lhs.expectedSize < rhs.expectedSize }
        return lhs.fileID < rhs.fileID
    }
}
