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

    /// Resolves the isolated data root for a debug bundle launched either by
    /// the build script or directly through LaunchServices. BuildInfo keeps
    /// direct bundle launches on the same root recorded by the build record.
    public static func developmentOverride(
        arguments: [String],
        environment: [String: String],
        buildInfo: Data?
    ) -> URL? {
        func usableURL(_ raw: String?) -> URL? {
            guard let raw else { return nil }
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard value.hasPrefix("/"), !value.isEmpty else { return nil }
            let url = URL(fileURLWithPath: value, isDirectory: true).standardizedFileURL
            return url
        }

        if let index = arguments.firstIndex(of: "--app-support-root"),
           arguments.indices.contains(index + 1),
           let value = usableURL(arguments[index + 1]) {
            return value
        }
        if let value = usableURL(environment["NETELEGRAM_APP_SUPPORT_ROOT"]) {
            return value
        }
        guard let buildInfo,
              let object = try? JSONSerialization.jsonObject(with: buildInfo) as? [String: Any],
              let value = object["support_root"] as? String else {
            return nil
        }
        return usableURL(value)
    }
}
