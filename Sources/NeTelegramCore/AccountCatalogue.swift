import Foundation

public struct AccountProfile: Codable, Sendable, Equatable, Identifiable {
    public let id: AccountUUID
    public let createdAt: Date
    public private(set) var telegramUserID: Int64?
    public private(set) var displayName: String?

    public init(id: AccountUUID = AccountUUID(), createdAt: Date = Date(), telegramUserID: Int64? = nil, displayName: String? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.telegramUserID = telegramUserID
        self.displayName = displayName
    }

    public mutating func associateVerifiedIdentity(_ userID: Int64, displayName: String? = nil) {
        telegramUserID = userID
        self.displayName = displayName
    }
}

public enum AccountCatalogueError: Error, Equatable {
    case duplicateAccount
    case accountNotFound
    case identityMismatch
    case persistence(String)
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
        let old = profiles[index]
        profiles[index].associateVerifiedIdentity(userID, displayName: displayName)
        do { try persist() } catch {
            profiles[index] = old
            throw error
        }
    }

    private func persist() throws {
        do {
            let data = try JSONEncoder.neTelegram.encode(profiles)
            try data.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
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
