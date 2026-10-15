import Testing
@testable import NeTelegramCore

@Suite("Channel access policy")
struct ChannelAccessPolicyTests {
    @Test("Development bundles retain channel access unless explicitly disabled")
    func developmentDefaultAndOverride() {
        #expect(ChannelAccessPolicy.isReadingEnabled(
            bundleIdentifier: "org.affpapa.netelegram.dev",
            infoDictionary: [:]
        ))
        #expect(!ChannelAccessPolicy.isReadingEnabled(
            bundleIdentifier: "org.affpapa.netelegram.dev",
            infoDictionary: [ChannelAccessPolicy.infoPlistKey: false]
        ))
    }

    @Test("Distribution defaults closed and unknown chat types fail closed")
    func distributionDefaultFailsClosed() {
        let bundleID = "org.affpapa.netelegram"
        #expect(!ChannelAccessPolicy.isReadingEnabled(bundleIdentifier: bundleID, infoDictionary: [:]))
        #expect(!ChannelAccessPolicy.permitsOpening(
            isChannel: true,
            bundleIdentifier: bundleID,
            infoDictionary: [:]
        ))
        #expect(!ChannelAccessPolicy.permitsOpening(
            isChannel: nil,
            bundleIdentifier: bundleID,
            infoDictionary: [:]
        ))
        #expect(ChannelAccessPolicy.permitsOpening(
            isChannel: false,
            bundleIdentifier: bundleID,
            infoDictionary: [:]
        ))
        #expect(!ChannelAccessPolicy.permitsNotification(
            isChannel: nil,
            bundleIdentifier: bundleID,
            infoDictionary: [:]
        ))
        #expect(!ChannelAccessPolicy.permitsNotification(
            isChannel: true,
            bundleIdentifier: bundleID,
            infoDictionary: [:]
        ))
        #expect(ChannelAccessPolicy.permitsNotification(
            isChannel: false,
            bundleIdentifier: bundleID,
            infoDictionary: [:]
        ))
    }

    @Test("Explicit distribution opt-in is required to enable channel reading")
    func explicitDistributionOptIn() {
        #expect(ChannelAccessPolicy.isReadingEnabled(
            bundleIdentifier: "org.affpapa.netelegram",
            infoDictionary: [ChannelAccessPolicy.infoPlistKey: true]
        ))
    }
}
