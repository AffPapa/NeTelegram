import Foundation
import Testing
@testable import NeTelegramCore

struct ProductIdentityTests {
    @Test func productDisplayNameMatchesCurrentProductIdentity() {
        #expect(ProductIdentity.displayName == "NeTide")
        #expect(ProductIdentity.repositoryCodename == "NeTelegram")
        #expect(!ProductIdentity.displayName.localizedCaseInsensitiveContains("telegram"))
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

        // Keep the codename-based storage path stable across public branding changes.
        #expect(release.path == support.appendingPathComponent("NeTelegram", isDirectory: true).path)
        #expect(development.path.hasPrefix(support.appendingPathComponent("NeTelegram/Development", isDirectory: true).path))
        #expect(development != release)
        #expect(!release.path.localizedCaseInsensitiveContains("Telegram Desktop"))
        #expect(!release.path.localizedCaseInsensitiveContains("org.telegram"))
    }

    @Test func developmentSupportRootUsesLaunchOverrideThenEnvironmentThenBuildInfo() throws {
        let buildInfo = try JSONSerialization.data(withJSONObject: ["support_root": "/tmp/netelegram-build-root"])
        let arguments = ["NeTelegram", "--app-support-root", "/tmp/netelegram-argument-root"]
        let environment = ["NETELEGRAM_APP_SUPPORT_ROOT": "/tmp/netelegram-environment-root"]

        #expect(AccountStorageRoot.developmentOverride(
            arguments: arguments,
            environment: environment,
            buildInfo: buildInfo
        )?.path == "/tmp/netelegram-argument-root")
        #expect(AccountStorageRoot.developmentOverride(
            arguments: ["NeTelegram"],
            environment: environment,
            buildInfo: buildInfo
        )?.path == "/tmp/netelegram-environment-root")
        #expect(AccountStorageRoot.developmentOverride(
            arguments: ["NeTelegram"],
            environment: [:],
            buildInfo: buildInfo
        )?.path == "/tmp/netelegram-build-root")
        #expect(AccountStorageRoot.developmentOverride(
            arguments: ["NeTelegram", "--app-support-root", "relative/path"],
            environment: [:],
            buildInfo: nil
        ) == nil)
    }
}
