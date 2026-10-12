import Foundation

public enum TelegramApplicationIdentity {
    /// Application identifier supplied by the project owner.
    public static let apiID: Int32 = 37_110_989

    /// The corresponding api_hash is deliberately kept out of source control.
    /// A local development copy is read from Keychain by SecretsStore.
    public static let keychainService = "org.affpapa.netelegram.telegram-api"
    public static let keychainAccount = "api-hash"
}
