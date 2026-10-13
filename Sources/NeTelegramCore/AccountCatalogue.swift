import Foundation

public struct AccountProfile: Codable, Sendable, Equatable, Identifiable {
    public let id: AccountUUID
    public let createdAt: Date
    public private(set) var telegramUserID: Int64?
    public private(set) var displayName: String?
    public private(set) var logoutCleanupPending: Bool?
    public private(set) var unverifiedRemovalPending: Bool?

    public init(id: AccountUUID = AccountUUID(), createdAt: Date = Date(), telegramUserID: Int64? = nil, displayName: String? = nil, logoutCleanupPending: Bool? = nil, unverifiedRemovalPending: Bool? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.telegramUserID = telegramUserID
        self.displayName = displayName
        self.logoutCleanupPending = logoutCleanupPending
        self.unverifiedRemovalPending = unverifiedRemovalPending
    }

    public mutating func associateVerifiedIdentity(_ userID: Int64, displayName: String? = nil) {
        telegramUserID = userID
        self.displayName = displayName
    }

    public mutating func markUnverifiedRemovalPending() {
        unverifiedRemovalPending = true
    }

    public mutating func markLogoutCleanupPending() {
        logoutCleanupPending = true
    }
}

public enum AccountCatalogueError: Error, Equatable {
    case duplicateAccount
    case accountNotFound
    case identityMismatch
    case verifiedProfileCannotBeRemoved
    case persistence(String)
}

/// Removes a local login profile only after its TDLib runtime has reported
/// Closed. The durable marker excludes the profile from restoration, so an
/// interrupted key/file cleanup can be retried without reopening its database.
public enum PendingUnverifiedProfileCleanup {
    public static func resume(
        account: AccountUUID,
        catalogue: AccountCatalogue,
        removeKeys: @Sendable (AccountUUID) async throws -> Void,
        removeFiles: @Sendable (AccountUUID) async throws -> Void
    ) async throws {
        guard let profile = await catalogue.allProfiles().first(where: { $0.id == account }),
              profile.telegramUserID == nil,
              profile.logoutCleanupPending != true,
              profile.unverifiedRemovalPending == true else {
            throw AccountCatalogueError.identityMismatch
        }
        try await removeKeys(account)
        try await removeFiles(account)
        try await catalogue.removeUnverifiedProfile(account)
    }
}

/// Executes the destructive portion of a confirmed logout only after the
/// catalogue has durably marked the profile as pending cleanup. Injected
/// operations keep each irreversible boundary testable and make retries safe.
public enum PendingLogoutCleanup {
    public static func resume(
        account: AccountUUID,
        expectedTelegramUserID: Int64,
        catalogue: AccountCatalogue,
        removeKeys: @Sendable (AccountUUID) async throws -> Void,
        removeFiles: @Sendable (AccountUUID) async throws -> Void
    ) async throws {
        guard let profile = await catalogue.allProfiles().first(where: { $0.id == account }),
              profile.telegramUserID == expectedTelegramUserID,
              profile.logoutCleanupPending == true else {
            throw AccountCatalogueError.identityMismatch
        }
        try await removeKeys(account)
        try await removeFiles(account)
        try await catalogue.removeProfile(account, expectedTelegramUserID: expectedTelegramUserID)
    }
}

/// Stores only local namespaces and verified server identity. Session material
/// remains in TDLib's per-account database; OTP and 2FA values are never fields.
public actor AccountCatalogue {
    private let fileURL: URL
    private var profiles: [AccountProfile]

    public init(rootURL: URL) throws {
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: rootURL.path)
        let catalogueURL = rootURL.appendingPathComponent("accounts.json", isDirectory: false)
        let loadedProfiles: [AccountProfile]
        if FileManager.default.fileExists(atPath: catalogueURL.path) {
            do {
                let data = try Data(contentsOf: catalogueURL)
                loadedProfiles = try JSONDecoder.neTelegram.decode([AccountProfile].self, from: data)
            } catch {
                throw AccountCatalogueError.persistence("Unable to read account catalogue")
            }
        } else {
            loadedProfiles = []
        }
        self.fileURL = catalogueURL
        self.profiles = loadedProfiles
    }

    public func allProfiles() -> [AccountProfile] { profiles }

    @discardableResult
    public func addProfile(id: AccountUUID = AccountUUID()) throws -> AccountProfile {
        guard !profiles.contains(where: { $0.id == id }) else { throw AccountCatalogueError.duplicateAccount }
        let profile = AccountProfile(id: id)
        profiles.append(profile)
        do { try persist() } catch {
            profiles.removeAll { $0.id == id }
            throw error
        }
        return profile
    }

    public func associateVerifiedIdentity(_ userID: Int64, displayName: String? = nil, with account: AccountUUID) throws {
        guard let index = profiles.firstIndex(where: { $0.id == account }) else {
            throw AccountCatalogueError.accountNotFound
        }
        if let existingUserID = profiles[index].telegramUserID, existingUserID != userID {
            throw AccountCatalogueError.identityMismatch
        }
        guard profiles[index].unverifiedRemovalPending != true else {
            throw AccountCatalogueError.identityMismatch
        }
        let old = profiles[index]
        profiles[index].associateVerifiedIdentity(userID, displayName: displayName)
        do { try persist() } catch {
            profiles[index] = old
            throw error
        }
    }

    /// Persists the removal barrier before closing an unfinished login. If
    /// identity verification wins the race, the operation fails without
    /// touching the profile or its secrets.
    public func markUnverifiedRemovalPending(_ account: AccountUUID) throws {
        guard let index = profiles.firstIndex(where: { $0.id == account }) else {
            throw AccountCatalogueError.accountNotFound
        }
        guard profiles[index].telegramUserID == nil,
              profiles[index].logoutCleanupPending != true else {
            throw AccountCatalogueError.verifiedProfileCannotBeRemoved
        }
        let old = profiles[index]
        profiles[index].markUnverifiedRemovalPending()
        do { try persist() } catch {
            profiles[index] = old
            throw error
        }
    }

    /// The profile can be forgotten only after the caller's TDLib Closed
    /// barrier, and only while it has no verified Telegram identity.
    public func removeUnverifiedProfile(_ account: AccountUUID) throws {
        guard let index = profiles.firstIndex(where: { $0.id == account }) else {
            throw AccountCatalogueError.accountNotFound
        }
        guard profiles[index].telegramUserID == nil,
              profiles[index].logoutCleanupPending != true,
              profiles[index].unverifiedRemovalPending == true else {
            throw AccountCatalogueError.verifiedProfileCannotBeRemoved
        }
        let removed = profiles.remove(at: index)
        do { try persist() } catch {
            profiles.insert(removed, at: index)
            throw error
        }
    }

    /// Persists a cleanup barrier before deleting any local account data after
    /// Telegram has confirmed logout. A restart must not reopen this profile as
    /// the previous identity if cleanup stops partway through.
    public func markLogoutCleanupPending(_ account: AccountUUID, expectedTelegramUserID: Int64) throws {
        guard let index = profiles.firstIndex(where: { $0.id == account }) else {
            throw AccountCatalogueError.accountNotFound
        }
        guard profiles[index].telegramUserID == expectedTelegramUserID else {
            throw AccountCatalogueError.identityMismatch
        }
        let old = profiles[index]
        profiles[index].markLogoutCleanupPending()
        do { try persist() } catch {
            profiles[index] = old
            throw error
        }
    }

    /// Removes a local profile only after the caller has observed TDLib's
    /// confirmed logout/Closed barrier and still knows which server identity
    /// the profile represented. Persistence failure restores the record.
    public func removeProfile(_ account: AccountUUID, expectedTelegramUserID: Int64) throws {
        guard let index = profiles.firstIndex(where: { $0.id == account }) else {
            throw AccountCatalogueError.accountNotFound
        }
        guard profiles[index].telegramUserID == expectedTelegramUserID else {
            throw AccountCatalogueError.identityMismatch
        }
        let removed = profiles.remove(at: index)
        do { try persist() } catch {
            profiles.insert(removed, at: index)
            throw error
        }
    }

    private func persist() throws {
        do {
            let data = try JSONEncoder.neTelegram.encode(profiles)
            try AtomicPrivateFile.replace(data, at: fileURL)
        } catch {
            throw AccountCatalogueError.persistence("Unable to save account catalogue")
        }
    }
}

public struct AccountStoragePaths: Sendable, Equatable {
    public let accountRoot: URL
    public let database: URL
    public let files: URL
    public let appState: URL

    public init(rootURL: URL, account: AccountUUID) throws {
        let accountRoot = rootURL.appendingPathComponent(account.id.uuidString.lowercased(), isDirectory: true)
        let database = accountRoot.appendingPathComponent("database", isDirectory: true)
        let files = accountRoot.appendingPathComponent("files", isDirectory: true)
        let appState = accountRoot.appendingPathComponent("state", isDirectory: true)
        for directory in [accountRoot, database, files, appState] {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        }
        self.accountRoot = accountRoot
        self.database = database
        self.files = files
        self.appState = appState
    }
}

private extension JSONEncoder {
    static var neTelegram: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var neTelegram: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
