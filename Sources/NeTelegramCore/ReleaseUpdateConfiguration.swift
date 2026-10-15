import Foundation

public enum ReleaseUpdateChannel: String, Sendable, Equatable, CaseIterable {
    case stable
    case alpha

    public var feedURL: URL {
        switch self {
        case .stable:
            URL(string: "https://netelegram.iryadom.chatgpt.site/updates/stable.xml")!
        case .alpha:
            URL(string: "https://netelegram.iryadom.chatgpt.site/updates/alpha.xml")!
        }
    }
}

/// Release-only updater settings. Development bundles and unknown channels
/// deliberately receive no updater, and each channel is pinned to its own
/// first-party HTTPS feed.
public struct ReleaseUpdateConfiguration: Sendable, Equatable {
    public let channel: ReleaseUpdateChannel
    public let feedURL: URL
    public let publicEdKey: String

    public static func resolve(bundleIdentifier: String?, infoDictionary: [String: Any]) -> Self? {
        guard bundleIdentifier == "org.affpapa.netelegram",
              let channelValue = infoDictionary["NeTelegramReleaseChannel"] as? String,
              let channel = ReleaseUpdateChannel(rawValue: channelValue),
              let feedValue = infoDictionary["SUFeedURL"] as? String,
              feedValue == channel.feedURL.absoluteString,
              let feedURL = URL(string: feedValue),
              feedURL.scheme == "https",
              feedURL.host == "netelegram.iryadom.chatgpt.site",
              let publicEdKey = infoDictionary["SUPublicEDKey"] as? String,
              let publicKeyBytes = Data(base64Encoded: publicEdKey),
              publicKeyBytes.count == 32,
              infoDictionary["SUVerifyUpdateBeforeExtraction"] as? Bool == true,
              infoDictionary["SUEnableAutomaticChecks"] as? Bool == false,
              infoDictionary["SUAutomaticallyUpdate"] as? Bool == false else {
            return nil
        }

        return Self(channel: channel, feedURL: feedURL, publicEdKey: publicEdKey)
    }

    private init(channel: ReleaseUpdateChannel, feedURL: URL, publicEdKey: String) {
        self.channel = channel
        self.feedURL = feedURL
        self.publicEdKey = publicEdKey
    }
}
