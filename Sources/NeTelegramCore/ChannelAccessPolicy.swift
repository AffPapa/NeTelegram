public enum ChannelAccessPolicy {
    public static let infoPlistKey = "NeTideChannelAccessEnabled"

    /// Development bundles stay usable by default. Distribution bundles fail
    /// closed unless the packager explicitly enables channel access after the
    /// required sponsored-media compatibility work is complete.
    public static func isReadingEnabled(
        bundleIdentifier: String?,
        infoDictionary: [String: Any]
    ) -> Bool {
        if let configured = infoDictionary[infoPlistKey] as? Bool {
            return configured
        }
        return bundleIdentifier?.hasSuffix(".dev") == true
    }

    public static func permitsOpening(
        isChannel: Bool?,
        bundleIdentifier: String?,
        infoDictionary: [String: Any]
    ) -> Bool {
        isReadingEnabled(bundleIdentifier: bundleIdentifier, infoDictionary: infoDictionary)
            || isChannel == false
    }

    public static func permitsNotification(
        isChannel: Bool?,
        bundleIdentifier: String?,
        infoDictionary: [String: Any]
    ) -> Bool {
        permitsOpening(
            isChannel: isChannel,
            bundleIdentifier: bundleIdentifier,
            infoDictionary: infoDictionary
        )
    }
}
