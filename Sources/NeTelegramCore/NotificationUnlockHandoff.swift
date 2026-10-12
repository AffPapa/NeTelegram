import Foundation

public struct LockedNotificationRoute: Hashable, Sendable {
    public let notification: RoutedTDLibNotification
    public let runtimeGeneration: RuntimeGeneration
    public let expectedTelegramUserID: Int64

    public init(
        notification: RoutedTDLibNotification,
        runtimeGeneration: RuntimeGeneration,
        expectedTelegramUserID: Int64
    ) {
        self.notification = notification
        self.runtimeGeneration = runtimeGeneration
        self.expectedTelegramUserID = expectedTelegramUserID
    }
}

/// Holds a notification destination only while the user completes privacy
/// authentication. It never persists across process restarts.
public struct NotificationUnlockHandoff: Sendable {
    public private(set) var pending: LockedNotificationRoute?

    public init() {}

    public mutating func stage(
        _ notification: RoutedTDLibNotification,
        runtimeGeneration: RuntimeGeneration,
        expectedTelegramUserID: Int64
    ) {
        pending = LockedNotificationRoute(
            notification: notification,
            runtimeGeneration: runtimeGeneration,
            expectedTelegramUserID: expectedTelegramUserID
        )
    }

    /// Resolves and clears the pending route after one authentication attempt.
    /// A newer runtime, identity, authorization state, or removed notification
    /// cannot inherit a route that was issued to a different UI generation.
    public mutating func resolve(
        unlockSucceeded: Bool,
        account: AccountUUID?,
        runtimeGeneration: RuntimeGeneration?,
        telegramUserID: Int64?,
        authorizationState: String?,
        notificationIsCurrent: Bool
    ) -> RoutedTDLibNotification? {
        guard let candidate = pending else { return nil }
        pending = nil
        guard unlockSucceeded,
              notificationIsCurrent,
              account == candidate.notification.account,
              runtimeGeneration == candidate.runtimeGeneration,
              telegramUserID == candidate.expectedTelegramUserID,
              AccountPresentation.restoresAuthenticatedChat(
                telegramUserID: telegramUserID,
                authorizationState: authorizationState
              ) else { return nil }
        return candidate.notification
    }

    public mutating func clear() {
        pending = nil
    }

    public mutating func clear(account: AccountUUID) {
        guard pending?.notification.account == account else { return }
        pending = nil
    }
}
