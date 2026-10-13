import Foundation

public enum NetworkTypeUpdatePolicy {
    /// Maps a point-in-time Network.framework path snapshot to TDLib's
    /// process-wide network type. Wi-Fi takes precedence when paths are
    /// multipath; non-Wi-Fi transports use TDLib's generic mobile/other types.
    public static func tdlibType(isSatisfied: Bool, usesWiFi: Bool, usesCellular: Bool) -> String {
        guard isSatisfied else { return "networkTypeNone" }
        if usesWiFi { return "networkTypeWiFi" }
        if usesCellular { return "networkTypeMobile" }
        return "networkTypeOther"
    }

    /// A new Network.framework observation is meaningful even when TDLib's
    /// coarse network type is unchanged (for example, Wi-Fi to another Wi-Fi
    /// route). Reprocessing the same observation is suppressed. Wake handling
    /// can force one reapplication for the latest observation.
    public static func shouldApply(currentRevision: UInt64, nextRevision: UInt64, force: Bool = false) -> Bool {
        force || nextRevision > currentRevision
    }
}

/// Produces unique IDs for callbacks from a serial network-monitor queue and
/// main-actor wake reconciliation. The counter exposes no network details.
public final class NetworkPathRevisionCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value: UInt64 = 0

    public init() {}

    public func next() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        precondition(value < UInt64.max, "Network path revision exhausted")
        value += 1
        return value
    }
}

/// Rejects duplicated or superseded observations so cancelled debounce tasks
/// cannot apply an older path after a newer event has arrived.
public struct NetworkPathRevisionGate: Sendable {
    public private(set) var latestRevision: UInt64 = 0

    public init() {}

    @discardableResult
    public mutating func accept(_ revision: UInt64) -> Bool {
        guard revision > latestRevision else { return false }
        latestRevision = revision
        return true
    }

    public func isLatest(_ revision: UInt64) -> Bool {
        revision == latestRevision
    }
}

/// Coordinates debounced path observations and wake reconciliation before
/// broadcasting TDLib's process-wide network type to every live account.
/// Runtime creation, sends, and notification work are deliberately outside
/// this coordinator: its only effect is one network-type callback per account.
@MainActor
public struct NetworkTypeFanoutCoordinator {
    private var revisionGate = NetworkPathRevisionGate()
    private var appliedRevision: UInt64 = 0

    public init() {}

    /// Accepts a new observation or a wake reapplication of the current one.
    @discardableResult
    public mutating func accept(revision: UInt64, force: Bool = false) -> Bool {
        let accepted = revisionGate.accept(revision)
        return accepted || (force && revisionGate.isLatest(revision))
    }

    /// Applies only the latest accepted observation, in stable account order.
    /// Returns false when the work was duplicated or superseded.
    @discardableResult
    public mutating func applyIfCurrent(
        type: String,
        revision: UInt64,
        force: Bool = false,
        accounts: [AccountUUID],
        apply: (AccountUUID, String) -> Void
    ) -> Bool {
        guard revisionGate.isLatest(revision),
              NetworkTypeUpdatePolicy.shouldApply(
                currentRevision: appliedRevision,
                nextRevision: revision,
                force: force
              ) else { return false }

        appliedRevision = revision
        for account in accounts.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            apply(account, type)
        }
        return true
    }

    public func isLatest(_ revision: UInt64) -> Bool {
        revisionGate.isLatest(revision)
    }
}
