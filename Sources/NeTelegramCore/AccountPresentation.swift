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
    case unverifiedRemovalPending
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
        case .unverifiedRemovalPending: "удаление незавершённого входа ожидает"
        case .failed: "ошибка"
        }
    }
}

public struct AccountStatusMenuRuntime: Sendable, Equatable {
    public let account: AccountUUID
    public let telegramUserID: Int64?
    public let authorizationState: String?
    public let hasError: Bool

    public init(account: AccountUUID, telegramUserID: Int64?, authorizationState: String?, hasError: Bool) {
        self.account = account
        self.telegramUserID = telegramUserID
        self.authorizationState = authorizationState
        self.hasError = hasError
    }
}

public struct AccountStatusMenuSummary: Sendable, Equatable {
    public let authorizedCount: Int
    public let awaitingInputCount: Int
    public let failedCount: Int

    public static func make(
        runtimes: [AccountStatusMenuRuntime],
        startupFailures: Set<AccountUUID>
    ) -> Self {
        var failedAccounts = startupFailures
        failedAccounts.formUnion(runtimes.filter {
            $0.authorizationState == "authorizationStateClosed" || $0.hasError
        }.map(\.account))

        return Self(
            authorizedCount: runtimes.filter { $0.telegramUserID != nil }.count,
            awaitingInputCount: runtimes.filter {
                AuthorizationStep(tdlibType: $0.authorizationState).awaitsUserInput
            }.count,
            failedCount: failedAccounts.count
        )
    }
}

public enum AccountConversationRestoration: Sendable, Equatable {
    case authorization
    case emptyConversation
    case reopen(chatID: Int64)
}

/// Immutable view state for one account selection. Conversation identity includes
/// the account and typed topic so identical chat IDs in different accounts never
/// share drafts or presentation state.
public struct AccountConversationSnapshot: Sendable, Equatable {
    public let account: AccountUUID
    public let generation: RuntimeGeneration
    public let conversation: ConversationKey?
    public let draft: String

    public init(
        account: AccountUUID,
        generation: RuntimeGeneration,
        conversation: ConversationKey?,
        draft: String
    ) {
        precondition(conversation == nil || conversation?.account == account)
        self.account = account
        self.generation = generation
        self.conversation = conversation
        self.draft = draft
    }

    public var selectedChatID: Int64? { conversation?.chatID }

    /// Returns a draft only when the snapshot still belongs to the exact
    /// account runtime and typed conversation being presented. AppKit uses
    /// this same policy when reopening a remembered chat after account changes.
    public func restoredDraft(
        account expectedAccount: AccountUUID,
        generation expectedGeneration: RuntimeGeneration,
        conversation expectedConversation: ConversationKey
    ) -> String? {
        guard account == expectedAccount,
              generation == expectedGeneration,
              conversation == expectedConversation else { return nil }
        return draft
    }
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

    public static func conversationRestoration(
        telegramUserID: Int64?,
        authorizationState: String?,
        snapshot: AccountConversationSnapshot,
        expectedAccount: AccountUUID,
        expectedGeneration: RuntimeGeneration
    ) -> AccountConversationRestoration {
        guard snapshot.account == expectedAccount,
              snapshot.generation == expectedGeneration else { return .authorization }
        return conversationRestoration(
            telegramUserID: telegramUserID,
            authorizationState: authorizationState,
            selectedChatID: snapshot.selectedChatID
        )
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
        logoutCleanupPending: Bool = false,
        unverifiedRemovalPending: Bool = false,
        networkUpdatePending: Bool = false
    ) -> String {
        let ordinal = max(1, localOrdinal)
        let name = verifiedDisplayName(telegramUserID: telegramUserID, candidate: candidate)
        let identity = name.map { "\($0) · аккаунт \(ordinal)" } ?? "Вход \(ProductIdentity.displayName) \(ordinal)"
        let status = pickerStatus(
            telegramUserID: telegramUserID,
            authorizationState: authorizationState,
            runtimeIsOpen: runtimeIsOpen,
            hasError: hasError,
            logoutCleanupPending: logoutCleanupPending,
            unverifiedRemovalPending: unverifiedRemovalPending
        ).label
        let networkStatus = networkUpdatePending ? " · ожидает обновление сети" : ""
        return "\(identity) — \(status)\(networkStatus)"
    }

    /// Explains the origin of an unfinished local login instead of implying
    /// that the entry was discovered in another Telegram client. A server
    /// identity is named only after TDLib has verified and persisted it.
    public static func selectionStatus(
        localOrdinal: Int,
        telegramUserID: Int64?,
        candidate: String?
    ) -> String {
        guard telegramUserID != nil else {
            return "Локальный вход \(ProductIdentity.displayName) \(max(1, localOrdinal)): запись создана в этом приложении. Сессии других приложений не импортируются."
        }
        let name = verifiedDisplayName(telegramUserID: telegramUserID, candidate: candidate) ?? "Аккаунт"
        return "Выбран аккаунт \(name). Остальные авторизованные аккаунты продолжают работу."
    }

    public static func pickerStatus(
        telegramUserID: Int64?,
        authorizationState: String?,
        runtimeIsOpen: Bool,
        hasError: Bool,
        logoutCleanupPending: Bool = false,
        unverifiedRemovalPending: Bool = false
    ) -> AccountProfilePickerStatus {
        if unverifiedRemovalPending { return .unverifiedRemovalPending }
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
