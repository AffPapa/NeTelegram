import Foundation

public enum AccountProfilePickerStatus: Sendable, Equatable {
    case notStarted
    case starting
    case awaitingPhone
    case awaitingCode
    case awaitingPassword
    case awaitingEmail
    case awaitingEmailCode
    case awaitingRegistration
    case awaitingConfirmation
    case authorized
    case verifyingIdentity
    case failed

    public var label: String {
        switch self {
        case .notStarted: "не запущен"
        case .starting: "подключается"
        case .awaitingPhone: "ожидает номер"
        case .awaitingCode: "ожидает код"
        case .awaitingPassword: "ожидает пароль 2FA"
        case .awaitingEmail: "ожидает email"
        case .awaitingEmailCode: "ожидает код из email"
        case .awaitingRegistration: "ожидает регистрацию"
        case .awaitingConfirmation: "ожидает подтверждение"
        case .authorized: "подключён"
        case .verifyingIdentity: "проверяет identity"
        case .failed: "ошибка"
        }
    }
}

/// Produces a human-facing account label only after TDLib has confirmed the
/// server identity. Local AccountUUIDs are storage keys and must never leak
/// into account pickers or window titles as if they were Telegram profiles.
public enum AccountPresentation {
    public static func verifiedDisplayName(telegramUserID: Int64?, candidate: String?) -> String? {
        guard telegramUserID != nil,
              let name = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty,
              UUID(uuidString: name) == nil else { return nil }
        return name
    }

    /// Makes every local profile understandable without presenting its storage
    /// UUID as a Telegram account. The ordinal is derived from catalogue order;
    /// a Telegram display name is used only after its server identity is saved.
    public static func pickerTitle(
        localOrdinal: Int,
        telegramUserID: Int64?,
        candidate: String?,
        authorizationState: String?,
        runtimeIsOpen: Bool,
        hasError: Bool
    ) -> String {
        let ordinal = max(1, localOrdinal)
        let name = verifiedDisplayName(telegramUserID: telegramUserID, candidate: candidate)
        let identity = name.map { "\($0) · профиль \(ordinal)" } ?? "Локальный вход \(ordinal)"
        let status = pickerStatus(
            telegramUserID: telegramUserID,
            authorizationState: authorizationState,
            runtimeIsOpen: runtimeIsOpen,
            hasError: hasError
        ).label
        return "\(identity) — \(status)"
    }

    public static func pickerStatus(
        telegramUserID: Int64?,
        authorizationState: String?,
        runtimeIsOpen: Bool,
        hasError: Bool
    ) -> AccountProfilePickerStatus {
        let step = AuthorizationStep(tdlibType: authorizationState)
        if hasError || step == .closed { return .failed }
        switch step {
        case .phoneNumber: return .awaitingPhone
        case .code: return .awaitingCode
        case .password: return .awaitingPassword
        case .emailAddress: return .awaitingEmail
        case .emailCode: return .awaitingEmailCode
        case .registration: return .awaitingRegistration
        case .qrConfirmation, .premiumPurchase: return .awaitingConfirmation
        case .ready:
            return telegramUserID == nil ? .verifyingIdentity : .authorized
        case .parameters, .loggingOut, .closing:
            return runtimeIsOpen ? .starting : .notStarted
        case .closed, .unknown:
            return runtimeIsOpen ? .starting : .notStarted
        }
    }
}
