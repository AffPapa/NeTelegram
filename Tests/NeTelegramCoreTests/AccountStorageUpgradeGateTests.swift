import Foundation
import Testing
@testable import NeTelegramCore

@Test func accountStorageLeaseAllowsOnlyOneLiveOwnerAndReleasesOnClose() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("netelegram-storage-lease-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    do {
        let lease = try AccountStorageLease(rootURL: root)
        #expect(throws: AccountStorageLeaseError.alreadyInUse) {
            _ = try AccountStorageLease(rootURL: root)
        }
        withExtendedLifetime(lease) {}
    }
    let reopened = try AccountStorageLease(rootURL: root)
    withExtendedLifetime(reopened) {}
}

@Test func accountStorageUpgradeGateRecordsAdvancesAndRejectsDowngrade() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("netelegram-build-gate-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    #expect(try AccountStorageUpgradeGate.prepare(rootURL: root, bundleBuildNumber: "17") == 17)
    #expect(try AccountStorageUpgradeGate.prepare(rootURL: root, bundleBuildNumber: "17") == 17)
    #expect(try AccountStorageUpgradeGate.prepare(rootURL: root, bundleBuildNumber: "18") == 18)
    #expect(throws: AccountStorageUpgradeError.downgrade(current: 17, highestOpened: 18)) {
        try AccountStorageUpgradeGate.prepare(rootURL: root, bundleBuildNumber: "17")
    }
}

@Test func accountStorageUpgradeGateFailsClosedOnCorruptMarkerAndInvalidBuild() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("netelegram-corrupt-gate-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let marker = root.appendingPathComponent(".account-storage-version.json")
    let corrupt = Data("not-json".utf8)
    try corrupt.write(to: marker)

    #expect(throws: AccountStorageUpgradeError.corruptState) {
        try AccountStorageUpgradeGate.prepare(rootURL: root, bundleBuildNumber: "1")
    }
    #expect(try Data(contentsOf: marker) == corrupt)
    #expect(throws: AccountStorageUpgradeError.invalidBuildNumber) {
        try AccountStorageUpgradeGate.prepare(
            rootURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
            bundleBuildNumber: "1.2"
        )
    }
}
