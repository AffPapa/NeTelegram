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
    case purchaseRequired
    case unsupported
    case authorized
    case verifyingIdentity
    case logoutCleanupPending
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
        case .purchaseRequired: "требуется покупка"
        case .unsupported: "шаг не поддерживается"
        case .authorized: "подключён"
        case .verifyingIdentity: "проверяет identity"
        case .logoutCleanupPending: "очистка после выхода ожидает"
        case .failed: "ошибка"
        }
    }
}

public enum AccountConversationRestoration: Sendable, Equatable {
    case authorization
    case emptyConversation
    case reopen(chatID: Int64)
}

/// Produces a human-facing account label only after TDLib has confirmed the
/// server identity. Local AccountUUIDs are storage keys and must never leak
/// into account pickers or window titles as if they were Telegram profiles.
public enum AccountPresentation {
    /// A verified account normally clears its transient `ready` update after
    /// identity reconciliation. Restore its chat on unlock only when no newer
    /// authorization state superseded that identity state.
    public static func restoresAuthenticatedChat(
        telegramUserID: Int64?,
        authorizationState: String?
    ) -> Bool {
        guard telegramUserID != nil else { return false }
        return authorizationState == nil || authorizationState == "authorizationStateReady"
    }

    /// Selects the presentation path without creating or replacing an account
    /// runtime. Remembered chat state is restored only for a verified identity
    /// whose current authorization state still permits authenticated UI.
    public static func conversationRestoration(
        telegramUserID: Int64?,
        authorizationState: String?,
        selectedChatID: Int64?
    ) -> AccountConversationRestoration {
        guard restoresAuthenticatedChat(
            telegramUserID: telegramUserID,
            authorizationState: authorizationState
        ) else { return .authorization }
        guard let selectedChatID else { return .emptyConversation }
        return .reopen(chatID: selectedChatID)
    }

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
        hasError: Bool,
        logoutCleanupPending: Bool = false
    ) -> String {
        let ordinal = max(1, localOrdinal)
        let name = verifiedDisplayName(telegramUserID: telegramUserID, candidate: candidate)
        let identity = name.map { "\($0) · профиль \(ordinal)" } ?? "Локальный вход \(ordinal)"
        let status = pickerStatus(
            telegramUserID: telegramUserID,
            authorizationState: authorizationState,
            runtimeIsOpen: runtimeIsOpen,
            hasError: hasError,
            logoutCleanupPending: logoutCleanupPending
        ).label
        return "\(identity) — \(status)"
    }

    public static func pickerStatus(
        telegramUserID: Int64?,
        authorizationState: String?,
        runtimeIsOpen: Bool,
        hasError: Bool,
        logoutCleanupPending: Bool = false
    ) -> AccountProfilePickerStatus {
        if logoutCleanupPending { return .logoutCleanupPending }
        if authorizationState == nil, runtimeIsOpen { return .starting }
        let step = AuthorizationStep(tdlibType: authorizationState)
        if hasError || step == .closed { return .failed }
        switch step {
        case .phoneNumber: return .awaitingPhone
        case .code: return .awaitingCode
        case .password: return .awaitingPassword
        case .emailAddress: return .awaitingEmail
        case .emailCode: return .awaitingEmailCode
        case .registration: return .awaitingRegistration
        case .qrConfirmation: return .awaitingConfirmation
        case .premiumPurchase: return .purchaseRequired
        case .ready:
            return telegramUserID == nil ? .verifyingIdentity : .authorized
        case .parameters, .loggingOut, .closing:
            return runtimeIsOpen ? .starting : .notStarted
        case .unknown:
            return .unsupported
        case .closed:
            return runtimeIsOpen ? .starting : .notStarted
        }
    }
}
