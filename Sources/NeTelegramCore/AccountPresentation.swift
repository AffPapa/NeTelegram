import Foundation

/// Produces a human-facing account label only after TDLib has confirmed the
/// server identity. Local AccountUUIDs are storage keys and must never leak
/// into account pickers or window titles as if they were Telegram profiles.
public enum AccountPresentation {
    public static func verifiedDisplayName(telegramUserID: Int64?, candidate: String?) -> String? {
        guard telegramUserID != nil,
              let name = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty,
              UUID(uuidString: name) == nil else { return nil }
        return name
    }
}
