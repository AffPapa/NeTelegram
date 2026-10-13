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

@Test func accountStorageLeaseDoesNotAllowAnAliasedSymlinkRoot() throws {
    let parent = FileManager.default.temporaryDirectory
        .appendingPathComponent("netelegram-storage-alias-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: parent) }
    let physicalRoot = parent.appendingPathComponent("accounts", isDirectory: true)
    let aliasRoot = parent.appendingPathComponent("accounts-alias", isDirectory: true)
    try FileManager.default.createDirectory(at: physicalRoot, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: aliasRoot, withDestinationURL: physicalRoot)

    let lease = try AccountStorageLease(rootURL: physicalRoot)
    #expect(throws: AccountStorageLeaseError.alreadyInUse) {
        _ = try AccountStorageLease(rootURL: aliasRoot)
    }
    withExtendedLifetime(lease) {}
}

@Test func accountStorageUpgradeGateRecordsAdvancesAndRejectsDowngrade() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("netelegram-build-gate-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let lease = try AccountStorageLease(rootURL: root)
    #expect(try lease.prepareUpgradeGate(bundleBuildNumber: "17") == 17)
    #expect(try lease.prepareUpgradeGate(bundleBuildNumber: "17") == 17)
    #expect(try lease.prepareUpgradeGate(bundleBuildNumber: "18") == 18)
    #expect(throws: AccountStorageUpgradeError.downgrade(current: 17, highestOpened: 18)) {
        try lease.prepareUpgradeGate(bundleBuildNumber: "17")
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

    let lease = try AccountStorageLease(rootURL: root)
    #expect(throws: AccountStorageUpgradeError.corruptState) {
        try lease.prepareUpgradeGate(bundleBuildNumber: "1")
    }
    #expect(try Data(contentsOf: marker) == corrupt)
    #expect(throws: AccountStorageUpgradeError.invalidBuildNumber) {
        try lease.prepareUpgradeGate(bundleBuildNumber: "1.2")
    }
    #expect(throws: AccountStorageUpgradeError.invalidBuildNumber) {
        try lease.prepareUpgradeGate(bundleBuildNumber: "0")
    }
    let developmentRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("netelegram-development-build-gate-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: developmentRoot) }
    let developmentLease = try AccountStorageLease(rootURL: developmentRoot)
    #expect(try developmentLease.prepareUpgradeGate(
        bundleBuildNumber: "0",
        allowDevelopmentZeroBuild: true
    ) == 0)
}
