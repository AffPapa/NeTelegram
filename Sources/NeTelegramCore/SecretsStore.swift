import Foundation
import LocalAuthentication
import Security

protocol KeychainItemBackend: Sendable {
    func read(account: String, service: String) -> (status: OSStatus, data: Data?)
    func add(data: Data, account: String, service: String) -> OSStatus
    func update(data: Data, account: String, service: String) -> OSStatus
    func delete(account: String, service: String) -> OSStatus
}

private struct SecurityKeychainItemBackend: KeychainItemBackend {
    func read(account: String, service: String) -> (status: OSStatus, data: Data?) {
        var query = SecretsStore.keychainReadQuery(account: account, service: service)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return (status, result as? Data)
    }

    func add(data: Data, account: String, service: String) -> OSStatus {
        var query = SecretsStore.itemQuery(account: account, service: service)
        query[kSecValueData as String] = data
        return SecItemAdd(query as CFDictionary, nil)
    }

    func update(data: Data, account: String, service: String) -> OSStatus {
        let query = SecretsStore.itemQuery(account: account, service: service)
        return SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
    }

    func delete(account: String, service: String) -> OSStatus {
        let query = SecretsStore.itemQuery(account: account, service: service)
        return SecItemDelete(query as CFDictionary)
    }
}

public enum SecretsStoreError: Error, Equatable {
    case missing(String)
    case keychain(OSStatus)
    case invalidTelegramAPIHash
}

/// Keychain access for local project credentials and per-account encryption keys.
public struct SecretsStore: Sendable {
    private static let keychainReadQueueKey = DispatchSpecificKey<Bool>()
    private static let keychainReadQueue: DispatchQueue = {
        let queue = DispatchQueue(label: "org.affpapa.netelegram.keychain-read", qos: .utility)
        queue.setSpecific(key: keychainReadQueueKey, value: true)
        return queue
    }()

    private let backend: any KeychainItemBackend

    enum KeyLookupDecision: Equatable {
        case use(Data)
        case create
        case missing
        case failure(OSStatus)
    }

    public init() {
        backend = SecurityKeychainItemBackend()
    }

    init(backend: any KeychainItemBackend) {
        self.backend = backend
    }

    /// SecItem calls are synchronous and may block while Keychain resolves
    /// access. Keep that work on a dedicated serial queue, outside both the
    /// AppKit main thread and Swift's cooperative executor.
    public static func performKeychainOperation<Value: Sendable>(
        _ operation: @escaping @Sendable () throws -> Value
    ) async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            keychainReadQueue.async {
                do {
                    continuation.resume(returning: try operation())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static var isExecutingOnKeychainReadQueue: Bool {
        DispatchQueue.getSpecific(key: keychainReadQueueKey) == true
    }

    public func telegramAPIHash() throws -> String {
        let result = backend.read(
            account: TelegramApplicationIdentity.keychainAccount,
            service: TelegramApplicationIdentity.keychainService
        )
        let status = result.status
        guard status != errSecItemNotFound else { throw SecretsStoreError.missing("Telegram API hash") }
        guard status == errSecSuccess else { throw SecretsStoreError.keychain(status) }
        guard let data = result.data, let value = String(data: data, encoding: .utf8), !value.isEmpty else {
            throw SecretsStoreError.missing("Telegram API hash")
        }
        return value
    }

    /// Stores an explicitly supplied project API hash in the macOS login
    /// Keychain. This never reads or imports credentials from another client.
    public func storeTelegramAPIHash(_ value: String) throws {
        guard Self.isValidTelegramAPIHash(value) else {
            throw SecretsStoreError.invalidTelegramAPIHash
        }
        let account = TelegramApplicationIdentity.keychainAccount
        let service = TelegramApplicationIdentity.keychainService
        let data = Data(value.utf8)
        let updateStatus = backend.update(data: data, account: account, service: service)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw SecretsStoreError.keychain(updateStatus) }

        let addStatus = backend.add(data: data, account: account, service: service)
        if addStatus == errSecSuccess { return }
        if addStatus == errSecDuplicateItem {
            let retryStatus = backend.update(data: data, account: account, service: service)
            guard retryStatus == errSecSuccess else { throw SecretsStoreError.keychain(retryStatus) }
            return
        }
        throw SecretsStoreError.keychain(addStatus)
    }

    public static func isValidTelegramAPIHash(_ value: String) -> Bool {
        value.utf8.count == 32 && value.utf8.allSatisfy {
            (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0)
        }
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
        let status = backend.delete(account: account, service: service)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecretsStoreError.keychain(status)
        }
    }

    private func key(for account: AccountUUID, service: String, createIfMissing: Bool) throws -> Data {
        let accountName = account.id.uuidString.lowercased()
        let readResult = backend.read(account: accountName, service: service)
        switch Self.keyLookupDecision(status: readResult.status, data: readResult.data, createIfMissing: createIfMissing) {
        case let .use(data):
            return data
        case .missing:
            throw SecretsStoreError.missing("Existing key for \(service)")
        case let .failure(status):
            throw SecretsStoreError.keychain(status)
        case .create:
            break
        }

        var generated = Data(count: 32)
        let randomStatus = generated.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, bytes.count, bytes.baseAddress!)
        }
        guard randomStatus == errSecSuccess else { throw SecretsStoreError.keychain(randomStatus) }

        let addStatus = backend.add(data: generated, account: accountName, service: service)
        if addStatus == errSecSuccess { return generated }
        if addStatus == errSecDuplicateItem {
            let retryResult = backend.read(account: accountName, service: service)
            guard retryResult.status == errSecSuccess, let existing = retryResult.data, existing.count == 32 else {
                throw SecretsStoreError.keychain(retryResult.status == errSecSuccess ? errSecDecode : retryResult.status)
            }
            return existing
        }
        throw SecretsStoreError.keychain(addStatus)
    }

    /// Key generation is allowed only for an explicit not-found response.
    /// Locked, unavailable, malformed, and all other Keychain responses fail
    /// closed so existing ciphertext can never be stranded under a replacement key.
    static func keyLookupDecision(status: OSStatus, data: Data?, createIfMissing: Bool) -> KeyLookupDecision {
        if status == errSecSuccess {
            guard let data, data.count == 32 else { return .failure(errSecDecode) }
            return .use(data)
        }
        if status == errSecItemNotFound {
            return createIfMissing ? .create : .missing
        }
        return .failure(status)
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

    static func keychainReadQuery(
        account: String,
        service: String
    ) -> [String: Any] {
        let context = LAContext()
        context.interactionNotAllowed = true
        var query = itemQuery(account: account, service: service)
        query[kSecUseAuthenticationContext as String] = context
        return query
    }
}
