/// Reconciles an asynchronous UNUserNotificationCenter.add completion with
/// the current privacy epoch and route. A completion from an earlier state
/// must never be treated as proof that its payload is still current.
public enum NotificationAddCompletionPolicy {
    public enum Action: Equatable, Sendable {
        case keep
        case replaceCurrent
        case remove
    }

    public static func action(
        enqueuedEpoch: UInt64,
        currentEpoch: UInt64,
        enqueuedTarget: RoutedTDLibNotification,
        currentTarget: RoutedTDLibNotification?
    ) -> Action {
        guard let currentTarget else { return .remove }
        guard enqueuedEpoch == currentEpoch, enqueuedTarget == currentTarget else {
            return .replaceCurrent
        }
        return .keep
    }
}
