import Foundation
import Security

public enum SecretsStoreError: Error, Equatable {
    case missing(String)
    case keychain(OSStatus)
}

/// Keychain access for local project credentials and per-account encryption keys.
public struct SecretsStore: Sendable {
    public init() {}

    public func telegramAPIHash() throws -> String {
        var query = Self.itemQuery(
            account: TelegramApplicationIdentity.keychainAccount,
            service: TelegramApplicationIdentity.keychainService
        )
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status != errSecItemNotFound else { throw SecretsStoreError.missing("Telegram API hash") }
        guard status == errSecSuccess else { throw SecretsStoreError.keychain(status) }
        guard let data = result as? Data, let value = String(data: data, encoding: .utf8), !value.isEmpty else {
            throw SecretsStoreError.missing("Telegram API hash")
        }
        return value
    }

    /// Returns the stable 256-bit TDLib database key for this local namespace.
    /// A Keychain failure never creates a replacement over an existing item.
    public func databaseKey(for account: AccountUUID, createIfMissing: Bool = true) throws -> Data {
        try key(for: account, service: "org.affpapa.netelegram.database-key", createIfMissing: createIfMissing)
    }

    /// Separate key namespace for app-owned sensitive state such as drafts.
    /// It is deliberately independent from TDLib's database encryption key.
    public func appStateKey(for account: AccountUUID, createIfMissing: Bool = true) throws -> Data {
        try key(for: account, service: "org.affpapa.netelegram.app-state-key", createIfMissing: createIfMissing)
    }

    /// Removes only this account's local database and app-state keys. Call
    /// after its TDLib client has acknowledged logout and reached Closed.
    public func removeAccountKeys(for account: AccountUUID) throws {
        let accountName = account.id.uuidString.lowercased()
        try removeKey(account: accountName, service: "org.affpapa.netelegram.database-key")
        try removeKey(account: accountName, service: "org.affpapa.netelegram.app-state-key")
    }

    private func removeKey(account: String, service: String) throws {
        let query = Self.itemQuery(account: account, service: service)
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecretsStoreError.keychain(status)
        }
    }

    private func key(for account: AccountUUID, service: String, createIfMissing: Bool) throws -> Data {
        let accountName = account.id.uuidString.lowercased()
        let baseQuery = Self.itemQuery(account: accountName, service: service)

        var readQuery = baseQuery
        readQuery[kSecReturnData as String] = true
        readQuery[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let readStatus = SecItemCopyMatching(readQuery as CFDictionary, &result)
        if readStatus == errSecSuccess, let data = result as? Data, data.count == 32 {
            return data
        }
        if readStatus == errSecItemNotFound, !createIfMissing {
            throw SecretsStoreError.missing("Existing key for \(service)")
        }
        guard readStatus == errSecItemNotFound else {
            throw SecretsStoreError.keychain(readStatus == errSecSuccess ? errSecDecode : readStatus)
        }

        var generated = Data(count: 32)
        let randomStatus = generated.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, bytes.count, bytes.baseAddress!)
        }
        guard randomStatus == errSecSuccess else { throw SecretsStoreError.keychain(randomStatus) }

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = generated
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecSuccess { return generated }
        if addStatus == errSecDuplicateItem {
            var retryQuery = baseQuery
            retryQuery[kSecReturnData as String] = true
            retryQuery[kSecMatchLimit as String] = kSecMatchLimitOne
            result = nil
            let retryStatus = SecItemCopyMatching(retryQuery as CFDictionary, &result)
            guard retryStatus == errSecSuccess, let existing = result as? Data, existing.count == 32 else {
                throw SecretsStoreError.keychain(retryStatus == errSecSuccess ? errSecDecode : retryStatus)
            }
            return existing
        }
        throw SecretsStoreError.keychain(addStatus)
    }

    /// Uses the user's standard macOS login Keychain. Accessibility attributes
    /// and the Data Protection Keychain are intentionally omitted because this
    /// app has no Data Protection Keychain entitlement.
    static func itemQuery(
        account: String,
        service: String
    ) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
