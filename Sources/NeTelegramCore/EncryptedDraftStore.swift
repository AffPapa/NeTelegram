import CryptoKit
import Foundation

public enum EncryptedDraftStoreError: Error, Equatable {
    case invalidKey
    case accountMismatch
    case corruptOrUnauthenticatedData
    case persistence
}

/// Stores app-owned drafts independently from TDLib's database and file cache.
/// The caller supplies a per-account 256-bit key held in Keychain.
public final class EncryptedDraftStore: @unchecked Sendable {
    private struct Entry: Codable {
        let conversation: ConversationKey
        let text: String
    }

    private let account: AccountUUID
    private let fileURL: URL
    private let key: SymmetricKey
    private let lock = NSLock()

    public init(account: AccountUUID, stateDirectory: URL, key: Data) throws {
        guard key.count == 32 else { throw EncryptedDraftStoreError.invalidKey }
        self.account = account
        self.fileURL = stateDirectory.appendingPathComponent("drafts.aesgcm", isDirectory: false)
        self.key = SymmetricKey(data: key)
        do {
            try FileManager.default.createDirectory(
                at: stateDirectory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: stateDirectory.path)
        } catch {
            throw EncryptedDraftStoreError.persistence
        }
    }

    public func load() throws -> [ConversationKey: String] {
        lock.lock()
        defer { lock.unlock() }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [:] }
        do {
            let sealedData = try Data(contentsOf: fileURL)
            guard let box = try? AES.GCM.SealedBox(combined: sealedData),
                  let clearData = try? AES.GCM.open(box, using: key),
                  let entries = try? JSONDecoder().decode([Entry].self, from: clearData) else {
                throw EncryptedDraftStoreError.corruptOrUnauthenticatedData
            }
            var result: [ConversationKey: String] = [:]
            for entry in entries {
                guard entry.conversation.account == account else { throw EncryptedDraftStoreError.accountMismatch }
                result[entry.conversation] = entry.text
            }
            return result
        } catch let error as EncryptedDraftStoreError {
            throw error
        } catch {
            throw EncryptedDraftStoreError.corruptOrUnauthenticatedData
        }
    }

    /// Atomic authenticated-encryption write. A failure leaves the previous
    /// ciphertext intact so the caller can retain an in-memory dirty barrier.
    public func save(_ drafts: [ConversationKey: String]) throws {
        lock.lock()
        defer { lock.unlock() }
        guard drafts.keys.allSatisfy({ $0.account == account }) else {
            throw EncryptedDraftStoreError.accountMismatch
        }
        do {
            let entries = drafts
                .filter { !$0.value.isEmpty }
                .map { Entry(conversation: $0.key, text: $0.value) }
                .sorted {
                    if $0.conversation.chatID != $1.conversation.chatID {
                        return $0.conversation.chatID < $1.conversation.chatID
                    }
                    return String(describing: $0.conversation.topic) < String(describing: $1.conversation.topic)
                }
            let clearData = try JSONEncoder().encode(entries)
            let box = try AES.GCM.seal(clearData, using: key)
            guard let sealedData = box.combined else { throw EncryptedDraftStoreError.persistence }
            try sealedData.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        } catch let error as EncryptedDraftStoreError {
            throw error
        } catch {
            throw EncryptedDraftStoreError.persistence
        }
    }
}
