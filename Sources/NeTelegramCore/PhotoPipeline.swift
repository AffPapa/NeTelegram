import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct PhotoPreviewToken: Hashable, Sendable {
    fileprivate let id: UUID
}

private struct PhotoMessageKey: Hashable {
    let account: AccountUUID
    let chatID: Int64
    let messageID: Int64
}

protocol PhotoPreviewCache: AnyObject {
    func data(forKey key: String) -> Data?
    func insert(_ data: Data, forKey key: String, cost: Int)
    func remove(forKey key: String)
}

private final class SystemPhotoPreviewCache: PhotoPreviewCache {
    private let storage = NSCache<NSString, NSData>()

    init(costLimit: Int) {
        storage.totalCostLimit = max(1, costLimit)
    }

    func data(forKey key: String) -> Data? {
        storage.object(forKey: key as NSString).map(Data.init(referencing:))
    }

    func insert(_ data: Data, forKey key: String, cost: Int) {
        storage.setObject(data as NSData, forKey: key as NSString, cost: cost)
    }

    func remove(forKey key: String) {
        storage.removeObject(forKey: key as NSString)
    }
}

/// Bounded, account-namespaced ImageIO previews. Download policy stays with
/// the visible conversation UI; this pipeline only decodes explicitly requested
/// local files and never walks TDLib's account directories.
public final class PhotoPipeline: @unchecked Sendable {
    private let queue: OperationQueue
    private let cache: any PhotoPreviewCache
    private let lock = NSLock()
    private let decoder: @Sendable (URL, Int) -> Data?
    private var operations: [UUID: Operation] = [:]
    private var accountByOperation: [UUID: AccountUUID] = [:]
    private var chatIDByOperation: [UUID: Int64] = [:]
    private var messageIDByOperation: [UUID: Int64] = [:]
    private var keysByAccount: [AccountUUID: Set<String>] = [:]
    private var generationByAccount: [AccountUUID: UInt64] = [:]
    private var generationByMessage: [PhotoMessageKey: UInt64] = [:]
    private var queuedDecodeCount = 0
    private var queuedDecodeCountByAccount: [AccountUUID: Int] = [:]

    public let maxConcurrentDecodes: Int
    public let maxQueuedDecodes: Int
    /// Caps one account below the global bound so late visible-work from a
    /// previous account cannot consume every queued slot after a UI switch.
    private let maxOutstandingDecodesPerAccount: Int

    public convenience init(maxConcurrentDecodes: Int = 2, maxQueuedDecodes: Int = 4, cacheCostLimit: Int = 128 * 1024 * 1024) {
        self.init(
            maxConcurrentDecodes: maxConcurrentDecodes,
            maxQueuedDecodes: maxQueuedDecodes,
            cacheCostLimit: cacheCostLimit,
            decoder: { url, size in Self.downsample(fileURL: url, maxPixelSize: size) }
        )
    }

    init(
        maxConcurrentDecodes: Int,
        maxQueuedDecodes: Int,
        cacheCostLimit: Int = 128 * 1024 * 1024,
        cache: (any PhotoPreviewCache)? = nil,
        decoder: @escaping @Sendable (URL, Int) -> Data?
    ) {
        self.maxConcurrentDecodes = max(1, maxConcurrentDecodes)
        self.maxQueuedDecodes = max(0, maxQueuedDecodes)
        let totalDecodeLimit = self.maxConcurrentDecodes + self.maxQueuedDecodes
        let reservedForOtherAccounts = self.maxQueuedDecodes == 0 ? 0 : max(1, self.maxQueuedDecodes / 2)
        self.maxOutstandingDecodesPerAccount = max(1, totalDecodeLimit - reservedForOtherAccounts)
        self.decoder = decoder
        self.cache = cache ?? SystemPhotoPreviewCache(costLimit: cacheCostLimit)
        queue = OperationQueue()
        queue.name = "NeTelegram.PhotoDecode"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = self.maxConcurrentDecodes
    }

    @discardableResult
    public func requestPreview(
        account: AccountUUID,
        chatID: Int64 = 0,
        messageID: Int64,
        fileID: Int32,
        fileURL: URL,
        maxPixelSize: Int,
        completion: @escaping @Sendable (PhotoPreviewToken, Data?) -> Void
    ) -> PhotoPreviewToken {
        let token = PhotoPreviewToken(id: UUID())
        let pixelSize = max(1, maxPixelSize)
        let cacheKey = key(account: account, chatID: chatID, messageID: messageID, fileID: fileID, fileURL: fileURL, maxPixelSize: pixelSize)
        let messageKey = PhotoMessageKey(account: account, chatID: chatID, messageID: messageID)
        lock.lock()
        let cachedData = cache.data(forKey: cacheKey)
        if cachedData == nil,
           (queuedDecodeCount >= maxConcurrentDecodes + maxQueuedDecodes
                || queuedDecodeCountByAccount[account, default: 0] >= maxOutstandingDecodesPerAccount) {
            lock.unlock()
            DispatchQueue.main.async { completion(token, nil) }
            return token
        }
        if cachedData == nil {
            queuedDecodeCount += 1
            queuedDecodeCountByAccount[account, default: 0] += 1
        }
        let requestGeneration = generationByAccount[account, default: 0]
        let requestMessageGeneration = generationByMessage[messageKey, default: 0]
        lock.unlock()

        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self, weak operation] in
            guard let self, let operation, !operation.isCancelled else { return }
            self.lock.lock()
            let generationIsCurrent = self.generationByAccount[account, default: 0] == requestGeneration
                && self.generationByMessage[messageKey, default: 0] == requestMessageGeneration
            self.lock.unlock()
            guard generationIsCurrent, !operation.isCancelled else { return }
            let data = cachedData ?? self.decoder(fileURL, pixelSize)
            guard !operation.isCancelled, let data else { return }
            if cachedData == nil {
                self.lock.lock()
                if self.generationByAccount[account, default: 0] == requestGeneration,
                   self.generationByMessage[messageKey, default: 0] == requestMessageGeneration,
                   !operation.isCancelled {
                    self.cache.insert(data, forKey: cacheKey, cost: data.count)
                    self.keysByAccount[account, default: []].insert(cacheKey)
                    if let keys = self.keysByAccount[account], keys.count > 2048 {
                        for staleKey in keys.prefix(keys.count - 2048) {
                            self.cache.remove(forKey: staleKey)
                            self.keysByAccount[account]?.remove(staleKey)
                        }
                    }
                }
                self.lock.unlock()
            }
            DispatchQueue.main.async {
                guard !operation.isCancelled else { return }
                self.lock.lock()
                let generationIsCurrent = self.generationByAccount[account, default: 0] == requestGeneration
                    && self.generationByMessage[messageKey, default: 0] == requestMessageGeneration
                self.lock.unlock()
                guard generationIsCurrent else { return }
                completion(token, data)
            }
        }
        operation.completionBlock = { [weak self] in
            guard let self else { return }
            self.lock.lock()
            self.operations.removeValue(forKey: token.id)
            self.accountByOperation.removeValue(forKey: token.id)
            self.chatIDByOperation.removeValue(forKey: token.id)
            self.messageIDByOperation.removeValue(forKey: token.id)
            if cachedData == nil {
                self.queuedDecodeCount = max(0, self.queuedDecodeCount - 1)
                let remainingForAccount = max(0, self.queuedDecodeCountByAccount[account, default: 0] - 1)
                if remainingForAccount == 0 {
                    self.queuedDecodeCountByAccount.removeValue(forKey: account)
                } else {
                    self.queuedDecodeCountByAccount[account] = remainingForAccount
                }
            }
            self.lock.unlock()
        }
        lock.lock()
        operations[token.id] = operation
        accountByOperation[token.id] = account
        chatIDByOperation[token.id] = chatID
        messageIDByOperation[token.id] = messageID
        lock.unlock()
        queue.addOperation(operation)
        return token
    }

    public func cancelPreview(_ token: PhotoPreviewToken) {
        lock.lock()
        let operation = operations.removeValue(forKey: token.id)
        accountByOperation.removeValue(forKey: token.id)
        chatIDByOperation.removeValue(forKey: token.id)
        messageIDByOperation.removeValue(forKey: token.id)
        lock.unlock()
        operation?.cancel()
    }

    public func cancelPreviews(for account: AccountUUID) {
        lock.lock()
        generationByAccount[account, default: 0] &+= 1
        let ids = accountByOperation.compactMap { $0.value == account ? $0.key : nil }
        let cancelled = ids.compactMap { id -> Operation? in
            accountByOperation.removeValue(forKey: id)
            chatIDByOperation.removeValue(forKey: id)
            messageIDByOperation.removeValue(forKey: id)
            return operations.removeValue(forKey: id)
        }
        lock.unlock()
        cancelled.forEach { $0.cancel() }
    }

    public func cancelAllPreviews() {
        lock.lock()
        for account in accountByOperation.values { generationByAccount[account, default: 0] &+= 1 }
        let pending = Array(operations.values)
        operations.removeAll()
        accountByOperation.removeAll()
        chatIDByOperation.removeAll()
        messageIDByOperation.removeAll()
        lock.unlock()
        pending.forEach { $0.cancel() }
    }

    public func removeCachedPreviews(for account: AccountUUID) {
        lock.lock()
        generationByAccount[account, default: 0] &+= 1
        let keys = keysByAccount.removeValue(forKey: account) ?? []
        for key in keys { cache.remove(forKey: key) }
        lock.unlock()
    }

    /// Purges previews and in-flight decodes for deleted or expired messages
    /// without invalidating visible work in other conversations.
    public func removeCachedPreviews(for account: AccountUUID, chatID: Int64, messageIDs: Set<Int64>) {
        guard !messageIDs.isEmpty else { return }
        lock.lock()
        for messageID in messageIDs {
            let key = PhotoMessageKey(account: account, chatID: chatID, messageID: messageID)
            generationByMessage[key, default: 0] &+= 1
        }
        let prefixes = messageIDs.map { "\(account.id.uuidString.lowercased())/\(chatID)/\($0)/" }
        let keys = keysByAccount[account] ?? []
        for key in keys where prefixes.contains(where: { key.hasPrefix($0) }) {
            cache.remove(forKey: key)
            keysByAccount[account]?.remove(key)
        }
        if keysByAccount[account]?.isEmpty == true { keysByAccount.removeValue(forKey: account) }

        let ids = messageIDByOperation.compactMap { id, value in
            accountByOperation[id] == account && chatIDByOperation[id] == chatID && messageIDs.contains(value) ? id : nil
        }
        let cancelled = ids.compactMap { id -> Operation? in
            accountByOperation.removeValue(forKey: id)
            chatIDByOperation.removeValue(forKey: id)
            messageIDByOperation.removeValue(forKey: id)
            return operations.removeValue(forKey: id)
        }
        lock.unlock()
        cancelled.forEach { $0.cancel() }
    }

    func outstandingDecodeCount(for account: AccountUUID) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return queuedDecodeCountByAccount[account, default: 0]
    }

    func hasCachedPreview(
        account: AccountUUID,
        chatID: Int64,
        messageID: Int64,
        fileID: Int32,
        fileURL: URL,
        maxPixelSize: Int
    ) -> Bool {
        let cacheKey = key(
            account: account,
            chatID: chatID,
            messageID: messageID,
            fileID: fileID,
            fileURL: fileURL,
            maxPixelSize: max(1, maxPixelSize)
        )
        lock.lock()
        defer { lock.unlock() }
        return cache.data(forKey: cacheKey) != nil
    }

    public static func downsample(fileURL: URL, maxPixelSize: Int) -> Data? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, options) else { return nil }
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixelSize),
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.84] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    private func key(account: AccountUUID, chatID: Int64, messageID: Int64, fileID: Int32, fileURL: URL, maxPixelSize: Int) -> String {
        let pathHash = SHA256.hash(data: Data(fileURL.standardizedFileURL.path.utf8)).map { String(format: "%02x", $0) }.joined()
        return "\(account.id.uuidString.lowercased())/\(chatID)/\(messageID)/\(fileID)/\(maxPixelSize)/\(pathHash)"
    }
}
