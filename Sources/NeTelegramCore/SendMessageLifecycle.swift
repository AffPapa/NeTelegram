import Foundation

public struct SendMessageKey: Hashable, Sendable {
    public let account: AccountUUID
    public let generation: RuntimeGeneration
    public let chatID: Int64
    public let temporaryMessageID: Int64

    public init(account: AccountUUID, generation: RuntimeGeneration, chatID: Int64, temporaryMessageID: Int64) {
        self.account = account
        self.generation = generation
        self.chatID = chatID
        self.temporaryMessageID = temporaryMessageID
    }
}

public enum SendMessageOutcome: Sendable, Equatable {
    case succeeded
    case failed(canRetry: Bool)
    case deleted
}

public enum SendMessageDeletionClassification: Sendable, Equatable {
    case cacheEviction
    case nonPermanent
    case permanent
    case unknown

    public static func classify(isPermanent: Bool?, fromCache: Bool?) -> Self {
        guard let fromCache else { return .unknown }
        if fromCache { return .cacheEviction }
        guard isPermanent == true else { return .nonPermanent }
        return .permanent
    }
}

public enum StagedPhotoDeletionPolicy {
    /// A permanent message delete is insufficient while TDLib may still read
    /// the staged source. Missing upload state is deliberately not treated as idle.
    public static func mayReleaseSource(isTerminalDelete: Bool, uploadIsActive: Bool?) -> Bool {
        isTerminalDelete && uploadIsActive == false
    }
}

/// Correlates TDLib's asynchronous send lifecycle with the original immutable intent.
/// A bounded early-outcome cache handles a terminal update received before the
/// sendMessage response that supplies its temporary message ID.
public struct SendMessageLifecycle<Payload: Sendable>: Sendable {
    private var pending: [SendMessageKey: Payload] = [:]
    private var earlyOutcomes: [SendMessageKey: SendMessageOutcome] = [:]
    private var earlyOutcomeOrder: [SendMessageKey] = []
    private let earlyOutcomeLimit: Int

    public init(earlyOutcomeLimit: Int = 256) {
        self.earlyOutcomeLimit = max(1, earlyOutcomeLimit)
    }

    /// Registers the sendMessage response. Returns an outcome if TDLib reported
    /// one before this response was observed.
    public mutating func register(_ payload: Payload, for key: SendMessageKey) -> SendMessageOutcome? {
        if let outcome = earlyOutcomes.removeValue(forKey: key) {
            earlyOutcomeOrder.removeAll { $0 == key }
            return outcome
        }
        pending[key] = payload
        return nil
    }

    /// Removes and returns a registered payload so a retry can move its
    /// correlation to the new temporary message ID returned by TDLib.
    public mutating func take(for key: SendMessageKey) -> Payload? {
        pending.removeValue(forKey: key)
    }

    /// Records a later TDLib outcome and returns the original intent when known.
    /// Call with `bufferIfUnregistered` only for a local negative temporary ID.
    @discardableResult
    public mutating func resolve(
        _ outcome: SendMessageOutcome,
        for key: SendMessageKey,
        bufferIfUnregistered: Bool
    ) -> Payload? {
        if let payload = pending.removeValue(forKey: key) { return payload }
        guard bufferIfUnregistered else { return nil }
        if earlyOutcomes[key] == nil { earlyOutcomeOrder.append(key) }
        earlyOutcomes[key] = outcome
        while earlyOutcomeOrder.count > earlyOutcomeLimit {
            let expired = earlyOutcomeOrder.removeFirst()
            earlyOutcomes.removeValue(forKey: expired)
        }
        return nil
    }

    public mutating func removeAll(for account: AccountUUID) {
        pending = pending.filter { $0.key.account != account }
        earlyOutcomes = earlyOutcomes.filter { $0.key.account != account }
        earlyOutcomeOrder.removeAll { $0.account == account }
    }
}
