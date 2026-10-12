import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct PhotoPreviewToken: Hashable, Sendable {
    fileprivate let id: UUID
}

/// Bounded, account-namespaced ImageIO previews. Download policy stays with
/// the visible conversation UI; this pipeline only decodes explicitly requested
/// local files and never walks TDLib's account directories.
public final class PhotoPipeline: @unchecked Sendable {
    private let queue: OperationQueue
    private let cache = NSCache<NSString, NSData>()
    private let lock = NSLock()
    private let decoder: @Sendable (URL, Int) -> Data?
    private var operations: [UUID: Operation] = [:]
    private var accountByOperation: [UUID: AccountUUID] = [:]
    private var keysByAccount: [AccountUUID: Set<String>] = [:]
    private var generationByAccount: [AccountUUID: UInt64] = [:]
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
        decoder: @escaping @Sendable (URL, Int) -> Data?
    ) {
        self.maxConcurrentDecodes = max(1, maxConcurrentDecodes)
        self.maxQueuedDecodes = max(0, maxQueuedDecodes)
        let totalDecodeLimit = self.maxConcurrentDecodes + self.maxQueuedDecodes
        let reservedForOtherAccounts = self.maxQueuedDecodes == 0 ? 0 : max(1, self.maxQueuedDecodes / 2)
        self.maxOutstandingDecodesPerAccount = max(1, totalDecodeLimit - reservedForOtherAccounts)
        self.decoder = decoder
        queue = OperationQueue()
        queue.name = "NeTelegram.PhotoDecode"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = self.maxConcurrentDecodes
        cache.totalCostLimit = max(1, cacheCostLimit)
    }

    @discardableResult
    public func requestPreview(
        account: AccountUUID,
        messageID: Int64,
        fileID: Int32,
        fileURL: URL,
        maxPixelSize: Int,
        completion: @escaping @Sendable (PhotoPreviewToken, Data?) -> Void
    ) -> PhotoPreviewToken {
        let token = PhotoPreviewToken(id: UUID())
        let pixelSize = max(1, maxPixelSize)
        let cacheKey = key(account: account, messageID: messageID, fileID: fileID, fileURL: fileURL, maxPixelSize: pixelSize)
        let cachedData = cache.object(forKey: cacheKey as NSString).map(Data.init(referencing:))
        lock.lock()
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
        lock.unlock()

        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self, weak operation] in
            guard let self, let operation, !operation.isCancelled else { return }
            let data = cachedData ?? self.decoder(fileURL, pixelSize)
            guard !operation.isCancelled, let data else { return }
            if cachedData == nil {
                self.lock.lock()
                if self.generationByAccount[account, default: 0] == requestGeneration, !operation.isCancelled {
                    self.cache.setObject(data as NSData, forKey: cacheKey as NSString, cost: data.count)
                    self.keysByAccount[account, default: []].insert(cacheKey)
                    if let keys = self.keysByAccount[account], keys.count > 2048 {
                        for staleKey in keys.prefix(keys.count - 2048) {
                            self.cache.removeObject(forKey: staleKey as NSString)
                            self.keysByAccount[account]?.remove(staleKey)
                        }
                    }
                }
                self.lock.unlock()
            }
            DispatchQueue.main.async {
                guard !operation.isCancelled else { return }
                completion(token, data)
            }
        }
        operation.completionBlock = { [weak self] in
            guard let self else { return }
            self.lock.lock()
            self.operations.removeValue(forKey: token.id)
            self.accountByOperation.removeValue(forKey: token.id)
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
        lock.unlock()
        queue.addOperation(operation)
        return token
    }

    public func cancelPreview(_ token: PhotoPreviewToken) {
        lock.lock()
        let operation = operations.removeValue(forKey: token.id)
        accountByOperation.removeValue(forKey: token.id)
        lock.unlock()
        operation?.cancel()
    }

    public func cancelPreviews(for account: AccountUUID) {
        lock.lock()
        generationByAccount[account, default: 0] &+= 1
        let ids = accountByOperation.compactMap { $0.value == account ? $0.key : nil }
        let cancelled = ids.compactMap { id -> Operation? in
            accountByOperation.removeValue(forKey: id)
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
        lock.unlock()
        pending.forEach { $0.cancel() }
    }

    public func removeCachedPreviews(for account: AccountUUID) {
        lock.lock()
        generationByAccount[account, default: 0] &+= 1
        let keys = keysByAccount.removeValue(forKey: account) ?? []
        for key in keys { cache.removeObject(forKey: key as NSString) }
        lock.unlock()
    }

    func outstandingDecodeCount(for account: AccountUUID) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return queuedDecodeCountByAccount[account, default: 0]
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

    private func key(account: AccountUUID, messageID: Int64, fileID: Int32, fileURL: URL, maxPixelSize: Int) -> String {
        let pathHash = SHA256.hash(data: Data(fileURL.standardizedFileURL.path.utf8)).map { String(format: "%02x", $0) }.joined()
        return "\(account.id.uuidString.lowercased())/\(messageID)/\(fileID)/\(maxPixelSize)/\(pathHash)"
    }
}
