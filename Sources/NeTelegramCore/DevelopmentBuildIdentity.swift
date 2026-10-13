import Foundation

public enum DevelopmentBuildIdentity {
    public static func windowTitle(_ title: String, bundleIdentifier: String?, sourceCommit: String?, hasUncommittedChanges: Bool = false) -> String {
        guard bundleIdentifier == "org.affpapa.netelegram.dev" else { return title }
        let commit = sourceCommit?.trimmingCharacters(in: .whitespacesAndNewlines)
        let isValidCommit = commit.map {
            (8...40).contains($0.count) && $0.utf8.allSatisfy {
                (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0)
            }
        } ?? false
        let marker: String
        if isValidCommit, let commit {
            marker = String(commit.prefix(8)).lowercased()
        } else {
            marker = "unknown"
        }
        return "\(title) · dev \(marker)\(hasUncommittedChanges ? "+dirty" : "")"
    }
}
