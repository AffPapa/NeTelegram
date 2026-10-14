import Foundation

public enum AuthorizationUIAvailability: Sendable, Equatable {
    case interactive
    case purchaseNotAvailable
    case unsupported
    case nonInteractive
}

/// Authorization recovery actions that TDLib explicitly permits from the
/// current state. This is intentionally narrower than "any login screen":
/// changing the phone number is supported from WaitCode, but not from QR
/// confirmation or email/password steps.
public enum AuthorizationRecoveryPolicy {
    public static func canChangePhoneNumber(
        from tdlibType: String?,
        hasRuntime: Bool,
        isLocked: Bool,
        requestInFlight: Bool
    ) -> Bool {
        hasRuntime
            && !isLocked
            && !requestInFlight
            && AuthorizationStep(tdlibType: tdlibType) == .code
    }
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

/// Static VoiceOver copy for authorization states. It accepts only the typed
/// state, never TDLib's full payload, so entered credentials and destinations
/// cannot accidentally enter an announcement.
public enum AuthorizationAnnouncement {
    public static func message(for step: AuthorizationStep) -> String? {
        switch step {
        case .phoneNumber: "Вход: введите номер телефона. Поле номера выбрано."
        case .code: "Вход: введите код подтверждения. Поле кода выбрано."
        case .password: "Вход: введите пароль двухэтапной проверки. Поле пароля выбрано."
        case .emailAddress: "Вход: введите адрес электронной почты. Поле адреса выбрано."
        case .emailCode: "Вход: введите код из письма. Поле кода выбрано."
        case .registration: "Вход: завершите регистрацию, указав имя и согласие с условиями."
        case .qrConfirmation: "Вход по QR: отсканируйте код в Telegram на телефоне для подтверждения."
        case .parameters, .premiumPurchase, .ready, .loggingOut, .closing, .closed, .unknown:
            nil
        }
    }
}

/// Static, non-sensitive feedback for rejected authorization submissions.
/// The input value and TDLib error payload are deliberately not included.
public enum AuthenticationFailureAnnouncement {
    public static func message(for step: AuthorizationStep) -> String? {
        switch step {
        case .phoneNumber: "Номер не принят Telegram. Проверьте код страны и номер."
        case .code: "Код не принят. Проверьте последнее сообщение с кодом и попробуйте снова."
        case .password: "Пароль двухэтапной проверки не принят. Попробуйте снова."
        case .emailAddress: "Адрес почты не принят. Проверьте его и попробуйте снова."
        case .emailCode: "Код из письма не принят. Проверьте последнее письмо и попробуйте снова."
        case .registration: "Не удалось завершить регистрацию. Проверьте имя и попробуйте снова."
        case .qrConfirmation: "Не удалось запросить QR-код. Попробуйте вход по номеру телефона."
        case .parameters, .premiumPurchase, .ready, .loggingOut, .closing, .closed, .unknown:
            nil
        }
    }
}

/// Suppresses repeated announcements from duplicate updates while allowing
/// the same state to be announced after switching account or client generation.
public struct AuthorizationAnnouncementContext: Hashable, Sendable {
    public let account: AccountUUID
    public let generation: RuntimeGeneration
    public let step: AuthorizationStep

    public init(account: AccountUUID, generation: RuntimeGeneration, step: AuthorizationStep) {
        self.account = account
        self.generation = generation
        self.step = step
    }

    public func shouldAnnounce(after previous: AuthorizationAnnouncementContext?) -> Bool {
        AuthorizationAnnouncement.message(for: step) != nil && previous != self
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
