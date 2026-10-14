/// Resolves a user-facing chat title without exposing internal TDLib routing IDs.
public enum ChatDisplayTitlePolicy {
    public static let unavailableTitle = "Чат без названия"

    public static func resolve(_ serverTitle: String?) -> String {
        guard let title = serverTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else {
            return unavailableTitle
        }
        return title
    }
}
