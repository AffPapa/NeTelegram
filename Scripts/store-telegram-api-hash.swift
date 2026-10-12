import Darwin
import Foundation
import Security

guard let input = getpass("Telegram api_hash (input hidden): "),
      let value = String(validatingUTF8: input), !value.isEmpty else {
    fputs("No api_hash supplied.\n", stderr)
    exit(2)
}
let service = "org.affpapa.netelegram.telegram-api"
let account = "api-hash"
let valueData = Data(value.utf8)
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: service,
    kSecAttrAccount as String: account,
]
let attributes: [String: Any] = [
    kSecValueData as String: valueData,
    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
]
let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
let status: OSStatus
if updateStatus == errSecItemNotFound {
    var add = query
    attributes.forEach { add[$0.key] = $0.value }
    status = SecItemAdd(add as CFDictionary, nil)
} else {
    status = updateStatus
}
guard status == errSecSuccess else {
    fputs("Keychain write failed (OSStatus \(status)). The api_hash was not stored.\n", stderr)
    exit(1)
}
print("Telegram API hash stored in the macOS Keychain; no secret value was printed.")
