import Foundation

/// Captures the exact user action that should mark photo content as opened.
/// It is created only from an explicit UI action and dispatched only after the
/// matching preview has decoded successfully.
public struct PhotoContentOpenIntent: Equatable, Sendable {
    public let account: AccountUUID
    public let expectedTelegramUserID: Int64
    public let runtimeGeneration: RuntimeGeneration
    public let chatID: Int64
    public let messageID: Int64
    public let privacyEpoch: UInt64

    public init(
        account: AccountUUID,
        expectedTelegramUserID: Int64,
        runtimeGeneration: RuntimeGeneration,
        chatID: Int64,
        messageID: Int64,
        privacyEpoch: UInt64
    ) {
        self.account = account
        self.expectedTelegramUserID = expectedTelegramUserID
        self.runtimeGeneration = runtimeGeneration
        self.chatID = chatID
        self.messageID = messageID
        self.privacyEpoch = privacyEpoch
    }

    @discardableResult
    public func dispatch(
        through barrier: PrivacyDispatchBarrier,
        currentAccount: AccountUUID,
        currentTelegramUserID: Int64,
        currentGeneration: RuntimeGeneration,
        send: () throws -> Void
    ) rethrows -> Bool {
        try barrier.dispatchBoundUserCommand(
            account: account,
            expectedTelegramUserID: expectedTelegramUserID,
            runtimeGeneration: runtimeGeneration,
            privacyEpoch: privacyEpoch,
            currentAccount: currentAccount,
            currentTelegramUserID: currentTelegramUserID,
            currentGeneration: currentGeneration,
            send: send
        )
    }
}

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
        // A missing capability is not permission. TDLib normally supplies this
        // flag; sparse, stale, or malformed updates must not enable a download.
        self.canBeDownloaded = local?["can_be_downloaded"] as? Bool ?? false
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
        let allCandidates = variants(from: sizes)
        guard !allCandidates.isEmpty else { return nil }
        let candidates = selectableCandidates(from: allCandidates)
        let targetArea = Int64(max(1, targetPixelSize)) * Int64(max(1, targetPixelSize))
        return candidates.filter { $0.pixelArea >= targetArea }.min(by: preferredOrder)
            ?? candidates.max(by: preferredOrder)
    }

    public static func original(from sizes: [[String: Any]]) -> PhotoFileVariant? {
        let allCandidates = variants(from: sizes)
        guard !allCandidates.isEmpty else { return nil }
        return selectableCandidates(from: allCandidates).max(by: preferredOrder)
    }

    private static func selectableCandidates(from candidates: [PhotoFileVariant]) -> [PhotoFileVariant] {
        let available = candidates.filter {
            $0.canBeDownloaded || ($0.isDownloaded && !($0.localPath ?? "").isEmpty)
        }
        // Preserve a useful variant for the UI to explain an unavailable photo
        // when TDLib marks every size as inaccessible.
        return available.isEmpty ? candidates : available
    }

    private static func preferredOrder(_ lhs: PhotoFileVariant, _ rhs: PhotoFileVariant) -> Bool {
        if lhs.pixelArea != rhs.pixelArea { return lhs.pixelArea < rhs.pixelArea }
        if lhs.expectedSize != rhs.expectedSize { return lhs.expectedSize < rhs.expectedSize }
        return lhs.fileID < rhs.fileID
    }
}
