import Foundation

public enum AuthorizationUIAvailability: Sendable, Equatable {
    case interactive
    case purchaseNotAvailable
    case unsupported
    case nonInteractive
}

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

    /// Whether this client has an implemented, safe presentation for the
    /// current TDLib state. Purchase requests intentionally never dispatch a
    /// purchase command; unknown states must not retain stale input controls.
    public var uiAvailability: AuthorizationUIAvailability {
        switch self {
        case .phoneNumber, .code, .password, .emailAddress, .emailCode, .registration, .qrConfirmation:
            return .interactive
        case .premiumPurchase:
            return .purchaseNotAvailable
        case .unknown:
            return .unsupported
        case .parameters, .ready, .loggingOut, .closing, .closed:
            return .nonInteractive
        }
    }
}
