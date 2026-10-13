import Foundation
import Testing
@testable import NeTelegramCore

struct ProductIdentityTests {
    @Test func publicDisplayNameMatchesRepositoryName() {
        #expect(ProductIdentity.displayName == "NeTelegram")
        #expect(ProductIdentity.repositoryCodename == "NeTelegram")
    }

    @Test func accountStorageUsesOnlyTheApplicationsOwnSupportDirectory() {
        let support = URL(fileURLWithPath: "/tmp/netelegram-storage-test/Library/Application Support", isDirectory: true)
        let release = AccountStorageRoot.resolve(
            applicationSupportDirectory: support,
            bundleIdentifier: "org.affpapa.netelegram",
            isDevelopmentBuild: false
        )
        let development = AccountStorageRoot.resolve(
            applicationSupportDirectory: support,
            bundleIdentifier: "org.affpapa.netelegram.dev",
            isDevelopmentBuild: true
        )

        #expect(release.path == support.appendingPathComponent("NeTelegram", isDirectory: true).path)
        #expect(development.path.hasPrefix(support.appendingPathComponent("NeTelegram/Development", isDirectory: true).path))
        #expect(development != release)
        #expect(!release.path.localizedCaseInsensitiveContains("Telegram Desktop"))
        #expect(!release.path.localizedCaseInsensitiveContains("org.telegram"))
    }
}
