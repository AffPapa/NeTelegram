import Foundation

/// Storage identities required before a profile's TDLib client can be created.
/// Account preparation is isolated so a Keychain or filesystem failure remains
/// local to that profile and can be exercised without real account credentials.
public struct PreparedProfileStorage: Sendable, Equatable {
    public let paths: AccountStoragePaths
    public let databaseKey: Data
    public let appStateKey: Data

    public init(paths: AccountStoragePaths, databaseKey: Data, appStateKey: Data) {
        self.paths = paths
        self.databaseKey = databaseKey
        self.appStateKey = appStateKey
    }
}

public enum ProfileStoragePreparer {
    /// Prepares this account's private directories and its independent keys.
    /// Existing database/draft files prohibit silently creating replacement keys.
    public static func prepare(
        account: AccountUUID,
        rootURL: URL,
        secrets: SecretsStore
    ) throws -> PreparedProfileStorage {
        let paths = try AccountStoragePaths(rootURL: rootURL, account: account)
        let hasDatabaseFiles = try !FileManager.default.contentsOfDirectory(atPath: paths.database.path).isEmpty
        let databaseKey = try secrets.databaseKey(for: account, createIfMissing: !hasDatabaseFiles)
        let draftsURL = paths.appState.appendingPathComponent("drafts.aesgcm")
        let appStateKey = try secrets.appStateKey(
            for: account,
            createIfMissing: !FileManager.default.fileExists(atPath: draftsURL.path)
        )
        return PreparedProfileStorage(paths: paths, databaseKey: databaseKey, appStateKey: appStateKey)
    }
}
