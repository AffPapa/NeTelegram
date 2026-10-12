import Foundation

/// Typed view of TDLib authorization states used to keep account-status copy
/// and interactive login handling aligned with the pinned TDLib schema.
public enum AuthorizationStep: String, CaseIterable, Sendable {
    case parameters
    case phoneNumber
    case code
    case password
    case emailAddress
    case emailCode
    case registration
    case qrConfirmation
    case premiumPurchase
    case ready
    case loggingOut
    case closing
    case closed
    case unknown

    public init(tdlibType: String?) {
        switch tdlibType {
        case "authorizationStateWaitTdlibParameters": self = .parameters
        case "authorizationStateWaitPhoneNumber": self = .phoneNumber
        case "authorizationStateWaitCode": self = .code
        case "authorizationStateWaitPassword": self = .password
        case "authorizationStateWaitEmailAddress": self = .emailAddress
        case "authorizationStateWaitEmailCode": self = .emailCode
        case "authorizationStateWaitRegistration": self = .registration
        case "authorizationStateWaitOtherDeviceConfirmation": self = .qrConfirmation
        case "authorizationStateWaitPremiumPurchase": self = .premiumPurchase
        case "authorizationStateReady": self = .ready
        case "authorizationStateLoggingOut": self = .loggingOut
        case "authorizationStateClosing": self = .closing
        case "authorizationStateClosed": self = .closed
        default: self = .unknown
        }
    }

    public var awaitsUserInput: Bool {
        switch self {
        case .phoneNumber, .code, .password, .emailAddress, .emailCode, .registration, .qrConfirmation, .premiumPurchase:
            return true
        case .parameters, .ready, .loggingOut, .closing, .closed, .unknown:
            return false
        }
    }
}
