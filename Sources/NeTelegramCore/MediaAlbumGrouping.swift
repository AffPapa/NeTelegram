import Foundation

public struct MediaAlbumRun: Equatable, Sendable {
    public let albumID: Int64?
    public let messageIndices: Range<Int>

    public init(albumID: Int64?, messageIndices: Range<Int>) {
        self.albumID = albumID
        self.messageIndices = messageIndices
    }
}

/// Groups only adjacent messages sharing a nonzero TDLib media_album_id.
/// Ordinary messages and album order remain unchanged.
public enum MediaAlbumGrouping {
    public static func runs(albumIDs: [Int64]) -> [MediaAlbumRun] {
        guard !albumIDs.isEmpty else { return [] }
        var result: [MediaAlbumRun] = []
        var start = 0
        var activeID: Int64? = albumIDs[0] == 0 ? nil : albumIDs[0]
        for index in 1...albumIDs.count {
            let nextID = index < albumIDs.count && albumIDs[index] != 0 ? albumIDs[index] : nil
            if index == albumIDs.count || nextID != activeID {
                result.append(MediaAlbumRun(albumID: activeID, messageIndices: start..<index))
                start = index
                activeID = nextID
            }
        }
        return result
    }
}
