import Foundation

/// Reduces the authorization state reported by one TDLib client into a
/// user-facing runtime availability. The caller must first validate that the
/// event belongs to the currently registered RuntimeRoute.
public enum AccountReducer {
    public static func reduce(
        current: AccountAvailability?,
        authorizationState: String,
        telegramUserID: Int64?
    ) -> AccountAvailability {
        switch authorizationState {
        case "authorizationStateWaitTdlibParameters",
             "authorizationStateWaitEncryptionKey":
            return .starting

        case "authorizationStateWaitPhoneNumber",
             "authorizationStateWaitCode",
             "authorizationStateWaitPassword",
             "authorizationStateWaitEmailAddress",
             "authorizationStateWaitEmailCode",
             "authorizationStateWaitRegistration",
             "authorizationStateWaitOtherDeviceConfirmation":
            return .needsAuthorization

        case "authorizationStateReady":
            guard let telegramUserID else { return .readyIdentityPending }
            return .active(telegramUserID: telegramUserID)

        case "authorizationStateLoggingOut", "authorizationStateClosing":
            return .closing

        case "authorizationStateClosed":
            return .closed

        default:
            // TDLib retains authorizationStateReady while transport changes
            // between connecting, updating, and waiting for the network.
            if let telegramUserID { return .active(telegramUserID: telegramUserID) }
            return current ?? .waitingForAuthorization
        }
    }
}
