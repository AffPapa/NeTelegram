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

    /// Suppresses duplicate path notifications. Wake handling can force one
    /// reapplication because the transport may have changed during sleep.
    public static func shouldApply(current: String, next: String, force: Bool = false) -> Bool {
        force || current != next
    }
}
