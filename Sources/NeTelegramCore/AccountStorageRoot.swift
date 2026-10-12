import Foundation

public enum AccountStorageRoot {
    /// Keeps development bundles from reopening one another's local catalogue.
    /// Release builds intentionally use a stable root across upgrades.
    public static func resolve(
        applicationSupportDirectory: URL,
        bundleIdentifier: String?,
        isDevelopmentBuild: Bool,
        override: URL? = nil
    ) -> URL {
        if let override { return override.standardizedFileURL }
        let productRoot = applicationSupportDirectory
            .appendingPathComponent("NeTelegram", isDirectory: true)
        guard isDevelopmentBuild else { return productRoot }

        let rawIdentifier = bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let safeIdentifier = rawIdentifier
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
        let component = safeIdentifier.isEmpty || safeIdentifier == "." || safeIdentifier == ".."
            ? "development"
            : safeIdentifier
        return productRoot
            .appendingPathComponent("Development", isDirectory: true)
            .appendingPathComponent(component, isDirectory: true)
    }
}
