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

/// Builds the short instruction shown while TDLib waits for a login code.
/// The destination is deliberately masked because this screen can be visible
/// during support or screen sharing.
public enum AuthenticationCodePrompt {
    public static func message(codeType: String?, phoneNumber: String?) -> String {
        let instruction: String
        switch codeType ?? "" {
        case "authenticationCodeTypeTelegramMessage": instruction = "Введите код из сообщения Telegram на другом устройстве."
        case "authenticationCodeTypeSms": instruction = "Введите код из SMS."
        case "authenticationCodeTypeCall": instruction = "Введите код из телефонного звонка."
        case "authenticationCodeTypeSmsWord": instruction = "Введите слово из SMS."
        case "authenticationCodeTypeSmsPhrase": instruction = "Введите фразу из SMS."
        case "authenticationCodeTypeFlashCall", "authenticationCodeTypeMissedCall": instruction = "Следуйте инструкции для подтверждения звонком."
        default: instruction = "Введите код, указанный в сообщении Telegram или способом, выбранным для этого входа."
        }
        guard let masked = maskedPhoneNumber(phoneNumber) else { return instruction }
        return "\(instruction)\nНомер: \(masked)"
    }

    public static func maskedPhoneNumber(_ phoneNumber: String?) -> String? {
        guard let phoneNumber else { return nil }
        let digits = phoneNumber.filter(\.isNumber)
        guard digits.count >= 4 else { return nil }
        let suffix = digits.suffix(2)
        let prefix = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("+") ? "+" : ""
        return "\(prefix)••••••\(suffix)"
    }
}
