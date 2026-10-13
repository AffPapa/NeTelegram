import Foundation

/// Ensures account startup asks macOS for notification permission at most
/// once per app process. TDLib notification options are still configured for
/// every account independently.
public struct NotificationAuthorizationRequestGate: Sendable {
    private var hasRequested = false

    public init() {}

    /// Returns true for the first caller only. A denied system permission does
    /// not disable or close any Telegram runtime.
    public mutating func claimRequest() -> Bool {
        guard !hasRequested else { return false }
        hasRequested = true
        return true
    }
}
