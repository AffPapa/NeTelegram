import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import LocalAuthentication
import Network
import ServiceManagement
import UniformTypeIdentifiers
import UserNotifications
import NeTelegramCore

private extension NSLayoutConstraint {
    func withPriority(_ value: NSLayoutConstraint.Priority) -> NSLayoutConstraint {
        priority = value
        return self
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, @preconcurrency UNUserNotificationCenterDelegate, NSTextViewDelegate, NSTextFieldDelegate, NSControlTextEditingDelegate, @unchecked Sendable {
    private var window: NSWindow!
    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var logoutAccountMenuItem: NSMenuItem?
    private var statusLabel: NSTextField!
    private var inputField: NSTextField!
    private var secureInputField: NSSecureTextField!
    private var actionButton: NSButton!
    private var addAccountButton: NSButton!
    private var accountPicker: NSPopUpButton!
    private var accountPickerAccounts: [AccountUUID] = []
    private var topicPicker: NSPopUpButton!
    private var countryPicker: NSPopUpButton!
    private var phoneField: NSTextField!
    private var emailField: NSTextField!
    private var firstNameField: NSTextField!
    private var lastNameField: NSTextField!
    private var registrationConsent: NSButton!
    private var registrationTermsScroll: NSScrollView!
    private var registrationTermsTextView: NSTextView!
    private var registrationTermsAvailable = false
    private var qrButton: NSButton!
    private var qrImageView: NSImageView!
    private var loginHeading: NSTextField!
    private var loginSubtitle: NSTextField!
    private var authCard: AuthenticationCardView!
    private var authStack: NSStackView!
    private var runtime: LocalAccountRuntime?
    private var gateway: TDLibGateway?
    private var updatePipeline: TDLibUpdatePipeline?
    private var tdlibReceiveFailed = false
    private let runtimeCoordinator = RuntimeCoordinator(startupParallelism: 2)
    private let startupScheduler = RuntimeStartupScheduler(parallelism: 2)
    private var catalogue: AccountCatalogue?
    private var accountStorageLease: AccountStorageLease?
    private var knownProfilesByAccount: [AccountUUID: AccountProfile] = [:]
    private var profileOrder: [AccountUUID] = []
    private var profileStartupFailures: Set<AccountUUID> = []
    private var profileOpenRequests: Set<AccountUUID> = []
    private var profileStartupTasks: [AccountUUID: (id: UUID, task: Task<Void, Never>)] = [:]
    private var closedProfileToRetry: AccountUUID?
    private var catalogueRoot: URL?
    private var runtimesByClient: [Int32: LocalAccountRuntime] = [:]
    private var runtimesByAccount: [AccountUUID: LocalAccountRuntime] = [:]
    private var pendingAuthorizationType: String?
    private var pendingInitialAuthorizationAction: InitialAuthorizationAction?
    private var initialAccountCreationInProgress = false
    private var lockState = false
    private var terminationBarrier = TerminationBarrier()
    private var terminationReply: ((Bool) -> Void)?
    private var pendingClosures: Set<Int32> = []
    private var closingForTermination: Bool { terminationBarrier.isPending }
    private var shutdownProgressTask: Task<Void, Never>?
    private var resumeProfilesAfterAbortedTermination = false
    private var profileRestoreInProgress = false
    private var profileRestoreGenerationGate = ProfileRestoreGenerationGate()
    private var phoneCountries: [PhoneCountry] = []
    private var selectedCallingCode = "1"
    private var showingQR = false
    private var authRequestInFlight = false
    private var pendingAuthRequestsByExtra: [String: (account: AccountUUID, step: String)] = [:]
    private var authPresentationInfoByAccount: [AccountUUID: [String: Any]] = [:]
    private var lockedView: NSView!
    private let privacyDispatchBarrier = PrivacyDispatchBarrier()
    private var unlockInProgress = false
    private var chatPane: NSView!
    private var sidebarPane: NSView!
    private var chatListScroll: NSScrollView!
    private var conversationTitleLabel: NSTextField!
    private var sidebarTitleLabel: NSTextField!
    private var chatList: NSStackView!
    private var searchField: NSSearchField!
    private var searchDebounceTask: Task<Void, Never>?
    private var activeSearchQuery = ""
    private var searchGeneration: UInt64 = 0
    private var searchResults = AccountSearchResults(maximumPerAccount: 21)
    private var searchResultByControlID: [String: AccountSearchResult] = [:]
    private var pendingSearchRequests = AccountSearchRequestRegistry()
    private var deferredSearch: DeferredSearch?
    private var historyAnchorByConversation: [ConversationKey: Int64] = [:]
    private var messageList: NSStackView!
    private var messageScroll: NSScrollView!
    private var messageReadViewsByID: [Int64: NSView] = [:]
    private var visibleReadReceiptRegistry = VisibleMessageReadRegistry()
    private var visibleReadReceiptTask: Task<Void, Never>?
    private var composerScroll: NSScrollView!
    private var composer: NSTextView!
    private var replyStatusLabel: NSTextField!
    private var clearReplyButton: NSButton!
    private var replyTargetsByConversation: [ConversationKey: Int64] = [:]
    private var typingActionPolicy = TypingActionPolicy()
    private var replyCandidatesByControlID: [String: MessageKey] = [:]
    private var messageActionTargetsByControlID: [String: MessageActionTarget] = [:]
    private var messageActionButtonsByControlID: [String: NSButton] = [:]
    private var pendingMessagePropertiesByExtra: [String: MessageActionContext] = [:]
    private var pendingMessageMutationsByExtra: [String: PendingMessageMutation] = [:]
    private var messageEditDrafts: [MessageKey: String] = [:]
    private var activeMessageActionAlert: NSAlert?
    private var activeMessageEditor: NSTextView?
    private var sendButton: NSButton!
    private var photoSendButton: NSButton!
    private var chatStatusLabel: NSTextField!
    private let photoPipeline = PhotoPipeline(maxConcurrentDecodes: 2, cacheCostLimit: 128 * 1024 * 1024)
    private var photoViews: [PhotoPresentationKey: NSImageView] = [:]
    private var photoButtons: [PhotoPresentationKey: NSButton] = [:]
    private var photoActionKeysByControlID: [String: PhotoPresentationKey] = [:]
    private var photoLocalURLs: [PhotoPresentationKey: URL] = [:]
    private var photoOriginalFileIDs: [PhotoPresentationKey: Int32] = [:]
    private var photoOriginalCanBeDownloaded: [PhotoPresentationKey: Bool] = [:]
    private var photoOriginalLocalURLs: [PhotoPresentationKey: URL] = [:]
    private var photoOriginalKeysByFileID: [AccountUUID: [Int32: Set<PhotoPresentationKey>]] = [:]
    private var photoTokens: [PhotoPresentationKey: PhotoPreviewToken] = [:]
    private var pendingPhotoByExtra: [String: PhotoPresentationKey] = [:]
    private var pendingOriginalPhotoByExtra: [String: PhotoPresentationKey] = [:]
    private var requestedOriginalPhotos: Set<PhotoPresentationKey> = []
    private var photoDownloadsByConversation: [ConversationKey: Set<Int32>] = [:]
    private var photoPresentationGeneration: UInt64 = 0
    private var photoViewerWindow: NSWindow?
    private var photoViewerImageView: NSImageView?
    private var photoViewerKey: PhotoPresentationKey?
    private var photoViewerToken: PhotoPreviewToken?
    private var photoViewerPrivacyEpoch: UInt64?
    private var draftsByConversation: [ConversationKey: String] = [:]
    private var draftStoresByAccount: [AccountUUID: EncryptedDraftStore] = [:]
    private var dirtyDraftAccounts: Set<AccountUUID> = []
    private var unavailableDraftAccounts: Set<AccountUUID> = []
    private var lockedDirtyDraftRecovery: [ConversationKey: String] = [:]
    private var sendEligibilityByAccount: [AccountUUID: [Int64: ChatSendPermission]] = [:]
    private var pendingSendByExtra: [String: PendingSend] = [:]
    private var pendingSendLifecycle = SendMessageLifecycle<PendingSend>()
    private var retryableFailedSends: [MessageKey: PendingSend] = [:]
    private var pendingRetryByExtra: [String: PendingRetryRequest] = [:]
    private var pendingRetryRefreshByExtra: [String: PendingRetryRefresh] = [:]
    private var retryingSendKeys: Set<SendMessageKey> = []
    private var stagedOutgoingPhotosByFileID: [AccountUUID: [Int32: URL]] = [:]
    private var pendingStagedPhotoPaths: [AccountUUID: Set<URL>] = [:]
    private var completedOutgoingPhotoFileIDs: [AccountUUID: Set<Int32>] = [:]
    private var outgoingPhotoUploadActiveByFileID: [AccountUUID: [Int32: Bool]] = [:]
    private var terminallyDeletedOutgoingPhotoURLs: [AccountUUID: Set<URL>] = [:]
    private var outgoingPhotoManifestStoresByAccount: [AccountUUID: OutgoingPhotoManifestStore] = [:]
    private var unavailableOutgoingPhotoManifestAccounts: Set<AccountUUID> = []
    private let networkMonitor = NWPathMonitor()
    private let networkMonitorQueue = DispatchQueue(label: "org.affpapa.netelegram.network-monitor", qos: .utility)
    private let networkPathRevisionCounter = NetworkPathRevisionCounter()
    private var networkPathRevisionGate = NetworkPathRevisionGate()
    private var currentAppliedNetworkPathRevision: UInt64 = 0
    private var currentTDLibNetworkType = "networkTypeNone"
    private var networkTypeUpdateTask: Task<Void, Never>?
    private var pendingProfileStorageWarnings = 0
    private var suppressDraftUpdate = false
    private var chatRowsByAccount: [AccountUUID: [Int64: (title: String, lastText: String)]] = [:]
    private var chatOrderByAccount: [AccountUUID: [Int64: UInt64]] = [:]
    private var selectedChatByAccount: [AccountUUID: Int64] = [:]
    private var messagesByConversation: [ConversationKey: [[String: Any]]] = [:]
    private var pendingHistoryRequests = ConversationHistoryRequestRegistry()
    private var historyRequestGenerationByConversation: [ConversationKey: UInt64] = [:]
    private var sponsoredMessagesByKey: [SponsoredMessagesKey: [SponsoredMessageCard]] = [:]
    private var sponsoredMessagesBetweenByKey: [SponsoredMessagesKey: Int32] = [:]
    private var sponsoredMessagesFetchedAt: [SponsoredMessagesKey: Date] = [:]
    private var pendingSponsoredMessagesByExtra: [String: SponsoredMessagesKey] = [:]
    private var pendingSponsoredBotUsersByExtra: [String: SponsoredMessagesKey] = [:]
    private var pendingSponsoredReportsByExtra: [String: (key: SponsoredMessagesKey, card: SponsoredMessageCard)] = [:]
    private var sponsoredEligibleChatKeys: Set<SponsoredMessagesKey> = []
    private var sponsoredChannelKeys: Set<SponsoredMessagesKey> = []
    private var sponsoredBotKeys: Set<SponsoredMessagesKey> = []
    private var sponsoredActionByControlID: [String: (key: SponsoredMessagesKey, card: SponsoredMessageCard)] = [:]
    private var sponsoredReportActionByControlID: [String: (key: SponsoredMessagesKey, card: SponsoredMessageCard)] = [:]
    private var pendingSponsoredPhotoByExtra: [String: SponsoredPhotoKey] = [:]
    private var sponsoredPhotoURLs: [SponsoredPhotoKey: URL] = [:]
    private var requestedSponsoredPhotos: Set<SponsoredPhotoKey> = []
    private var failedSponsoredPhotos: Set<SponsoredPhotoKey> = []
    private var sponsoredPhotoRetryByControlID: [String: (key: SponsoredMessagesKey, card: SponsoredMessageCard)] = [:]
    private var pendingForumTopicsByExtra: [String: Int64] = [:]
    private var forumTopicsByAccount: [AccountUUID: [Int64: [ForumTopicDescriptor]]] = [:]
    private var forumChatsByAccount: [AccountUUID: Set<Int64>] = [:]
    private var selectedForumTopicIDsByAccount: [AccountUUID: [Int64: Int32]] = [:]
    private var selectedConversationTopicsByAccount: [AccountUUID: [Int64: ConversationTopicKey]] = [:]
    private var topicPickerIDs: [Int32] = []
    private var historyRequestCounter: UInt64 = 0
    private var notificationIDsByAccount: [AccountUUID: Set<String>] = [:]
    private var notificationTargets: [String: RoutedTDLibNotification] = [:]
    private var notificationUnlockHandoff = NotificationUnlockHandoff()
    private var notificationAuthorizationRequestGate = NotificationAuthorizationRequestGate()

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        NSApp.setActivationPolicy(.regular)
        buildMainMenu()
        buildWindow()
        buildStatusItem()
        startConnectionObservers()
        NSApp.activate(ignoringOtherApps: true)
        Task { @MainActor in await restoreProfiles() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        networkTypeUpdateTask?.cancel()
        networkMonitor.cancel()
        NSWorkspace.shared.notificationCenter.removeObserver(self, name: NSWorkspace.didWakeNotification, object: nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showWindow() }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if terminationBarrier.isFinished { return .terminateNow }
        guard flushDirtyDraftsBeforeQuit() else { return .terminateCancel }
        if profileRestoreInProgress {
            _ = profileRestoreGenerationGate.invalidate()
            profileRestoreInProgress = false
        }
        guard !resumeProfilesAfterAbortedTermination, pendingClosures.isEmpty else {
            setStatus("Ожидаю подтверждения TDLib перед повторной попыткой выхода.")
            return .terminateCancel
        }
        let cancelledProfileStarts = cancelPendingProfileStartsForTermination()
        if runtimesByClient.isEmpty {
            guard let gateway, !gateway.receiveWorkerHasExited else { return .terminateNow }
            terminationBarrier.begin()
            terminationReply = { [weak self] allow in
                NSApp.reply(toApplicationShouldTerminate: allow)
                self?.terminationReply = nil
            }
            stopReceiverAndReplyWhenExited(gateway)
            return .terminateLater
        }
        terminationBarrier.begin()
        pendingClosures = Set(runtimesByClient.keys)
        let rejected = runtimesByClient.compactMap { client, target in
            target.close() ? nil : client
        }
        if !rejected.isEmpty {
            // Do not strand already-accepted close requests. Cancel this quit
            // attempt, wait for their Closed updates, then reopen only profiles
            // whose previous TDLib clients have fully closed.
            terminationBarrier.cancel()
            pendingClosures.subtract(rejected)
            resumeProfilesAfterAbortedTermination = !pendingClosures.isEmpty || cancelledProfileStarts
            setStatus("TDLib не принял закрытие одного или нескольких аккаунтов. Приложение осталось открытым; повторный выход будет доступен после восстановления runtime.")
            if pendingClosures.isEmpty, cancelledProfileStarts {
                scheduleProfileRecoveryAfterAbortedTermination()
            }
            return .terminateCancel
        }
        terminationReply = { [weak self] allow in
            NSApp.reply(toApplicationShouldTerminate: allow)
            self?.terminationReply = nil
        }
        setStatus("Завершаю работу: TDLib закрывает аккаунты и сохраняет данные…")
        shutdownProgressTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(60))
            guard let self, self.closingForTermination, !self.pendingClosures.isEmpty else { return }
            self.setStatus("TDLib всё ещё закрывает базы. Выход продолжится после подтверждения; не запускайте аккаунты повторно.")
        }
        return .terminateLater
    }

    private func buildWindow() {
        let contentWidth: CGFloat = 1060
        let contentHeight: CGFloat = 720
        let content = NSView(frame: NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight))
        content.autoresizingMask = [.width, .height]
        content.identifier = NSUserInterfaceItemIdentifier("rootContent")
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let mark = NSView(frame: .zero)
        mark.wantsLayer = true
        mark.layer?.backgroundColor = NSColor.systemBlue.cgColor
        mark.layer?.cornerRadius = 32
        let markLabel = NSTextField(labelWithString: "N")
        markLabel.font = .systemFont(ofSize: 34, weight: .bold)
        markLabel.textColor = .white
        markLabel.alignment = .center
        markLabel.frame = NSRect(x: 0, y: 11, width: 64, height: 42)
        mark.addSubview(markLabel)

        loginHeading = NSTextField(labelWithString: "Добро пожаловать")
        loginHeading.font = .systemFont(ofSize: 25, weight: .semibold)
        loginHeading.alignment = .center
        loginSubtitle = NSTextField(wrappingLabelWithString: "Введите номер телефона, чтобы войти в свой аккаунт.")
        loginSubtitle.font = .systemFont(ofSize: 14)
        loginSubtitle.textColor = .secondaryLabelColor
        loginSubtitle.alignment = .center

        accountPicker = NSPopUpButton(frame: NSRect(x: 16, y: 625, width: 298, height: 30), pullsDown: false)
        accountPicker.isHidden = true
        accountPicker.target = self
        accountPicker.action = #selector(selectAccount)
        accountPicker.setAccessibilityLabel("Локальный профиль и статус входа")

        countryPicker = NSPopUpButton(frame: .zero, pullsDown: false)
        countryPicker.isHidden = true
        countryPicker.target = self
        countryPicker.action = #selector(selectCountry)
        countryPicker.setAccessibilityLabel("Страна и телефонный код")
        phoneField = NSTextField(string: "")
        phoneField.placeholderString = "+код страны и номер"
        phoneField.font = .systemFont(ofSize: 17)
        phoneField.frame = .zero
        phoneField.alignment = .center
        phoneField.setAccessibilityLabel("Номер телефона")
        phoneField.isHidden = false
        phoneField.delegate = self

        emailField = NSTextField(string: "")
        emailField.placeholderString = "Электронная почта"
        emailField.font = .systemFont(ofSize: 17)
        emailField.alignment = .center
        emailField.setAccessibilityLabel("Электронная почта для входа")
        emailField.isHidden = true
        emailField.delegate = self

        firstNameField = NSTextField(string: "")
        firstNameField.placeholderString = "Имя"
        firstNameField.font = .systemFont(ofSize: 17)
        firstNameField.setAccessibilityLabel("Имя для регистрации")
        firstNameField.isHidden = true
        firstNameField.delegate = self
        lastNameField = NSTextField(string: "")
        lastNameField.placeholderString = "Фамилия (необязательно)"
        lastNameField.font = .systemFont(ofSize: 17)
        lastNameField.setAccessibilityLabel("Фамилия для регистрации, необязательно")
        lastNameField.isHidden = true
        lastNameField.delegate = self

        registrationConsent = NSButton(checkboxWithTitle: "Я прочитал(а) и принимаю условия регистрации Telegram", target: self, action: #selector(toggleRegistrationConsent))
        registrationConsent.setAccessibilityLabel("Подтвердить согласие с условиями регистрации Telegram")
        registrationConsent.isHidden = true
        registrationTermsTextView = NSTextView(frame: NSRect(x: 0, y: 0, width: 500, height: 144))
        registrationTermsTextView.isEditable = false
        registrationTermsTextView.isSelectable = true
        registrationTermsTextView.font = .systemFont(ofSize: 12)
        registrationTermsTextView.textContainerInset = NSSize(width: 10, height: 8)
        registrationTermsTextView.setAccessibilityLabel("Условия регистрации Telegram")
        registrationTermsScroll = NSScrollView()
        registrationTermsScroll.documentView = registrationTermsTextView
        registrationTermsScroll.hasVerticalScroller = true
        registrationTermsScroll.borderType = .bezelBorder
        registrationTermsScroll.isHidden = true

        inputField = NSTextField(string: "")
        inputField.placeholderString = "Код из Telegram"
        inputField.font = .systemFont(ofSize: 17)
        inputField.frame = .zero
        inputField.alignment = .center
        inputField.setAccessibilityLabel("Код подтверждения входа")
        inputField.isHidden = true
        inputField.delegate = self
        secureInputField = NSSecureTextField(string: "")
        secureInputField.placeholderString = "Пароль двухэтапной проверки"
        secureInputField.font = .systemFont(ofSize: 17)
        secureInputField.frame = .zero
        secureInputField.alignment = .center
        secureInputField.setAccessibilityLabel("Пароль двухэтапной проверки")
        secureInputField.isHidden = true
        secureInputField.delegate = self

        statusLabel = NSTextField(wrappingLabelWithString: "Подключаю экран входа…")
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center
        statusLabel.setAccessibilityLabel("Статус авторизации")

        qrImageView = NSImageView(frame: .zero)
        qrImageView.imageScaling = .scaleProportionallyUpOrDown
        qrImageView.isHidden = true
        qrImageView.setAccessibilityLabel("QR-код подтверждения входа в Telegram")
        qrImageView.setAccessibilityHelp("Откройте Telegram на телефоне, перейдите в Настройки → Устройства → Подключить устройство и отсканируйте код.")

        actionButton = NSButton(title: "Продолжить", target: self, action: #selector(primaryAction))
        actionButton.bezelStyle = .rounded
        actionButton.frame = .zero
        actionButton.setAccessibilityLabel("Продолжить вход")
        qrButton = NSButton(title: "Войти по QR-коду", target: self, action: #selector(beginQRLogin))
        qrButton.isBordered = false
        qrButton.contentTintColor = .systemBlue
        qrButton.frame = .zero
        qrButton.setAccessibilityLabel("Войти по QR-коду")
        addAccountButton = NSButton(title: "Добавить ещё аккаунт", target: self, action: #selector(addAccount))
        addAccountButton.isBordered = false
        addAccountButton.contentTintColor = .systemBlue
        addAccountButton.frame = .zero
        addAccountButton.isHidden = true
        addAccountButton.setAccessibilityLabel("Добавить ещё один Telegram аккаунт")
        authStack = NSStackView(views: [mark, loginHeading, loginSubtitle, registrationTermsScroll, countryPicker, phoneField, emailField, inputField, secureInputField, firstNameField, lastNameField, registrationConsent, qrImageView, statusLabel, actionButton, qrButton])
        authStack.orientation = .vertical
        authStack.alignment = .centerX
        authStack.distribution = .fill
        authStack.spacing = 14
        authStack.translatesAutoresizingMaskIntoConstraints = false
        authCard = AuthenticationCardView(frame: .zero)
        authCard.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(authCard)
        authCard.addSubview(authStack)
        NSLayoutConstraint.activate([
            authCard.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            authCard.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            authCard.widthAnchor.constraint(equalToConstant: 568),
            authCard.widthAnchor.constraint(lessThanOrEqualTo: content.widthAnchor, constant: -48),
            authCard.heightAnchor.constraint(lessThanOrEqualTo: content.heightAnchor, constant: -48),
            authStack.leadingAnchor.constraint(equalTo: authCard.leadingAnchor, constant: 32),
            authStack.trailingAnchor.constraint(equalTo: authCard.trailingAnchor, constant: -32),
            authStack.topAnchor.constraint(equalTo: authCard.topAnchor, constant: 28),
            authStack.bottomAnchor.constraint(equalTo: authCard.bottomAnchor, constant: -28),
            mark.widthAnchor.constraint(equalToConstant: 64), mark.heightAnchor.constraint(equalToConstant: 64),
            // Keep the form centered while allowing its explanatory text and
            // registration terms to shrink with a narrow window.
            loginHeading.widthAnchor.constraint(lessThanOrEqualTo: content.widthAnchor, constant: -64),
            loginHeading.widthAnchor.constraint(equalToConstant: 500).withPriority(.defaultHigh),
            loginSubtitle.widthAnchor.constraint(lessThanOrEqualTo: content.widthAnchor, constant: -64),
            loginSubtitle.widthAnchor.constraint(equalToConstant: 500).withPriority(.defaultHigh),
            registrationTermsScroll.widthAnchor.constraint(lessThanOrEqualTo: content.widthAnchor, constant: -64),
            registrationTermsScroll.widthAnchor.constraint(equalToConstant: 500).withPriority(.defaultHigh),
            registrationTermsScroll.heightAnchor.constraint(equalToConstant: 144),
            countryPicker.widthAnchor.constraint(equalToConstant: 300), countryPicker.heightAnchor.constraint(equalToConstant: 34),
            phoneField.widthAnchor.constraint(equalToConstant: 360), phoneField.heightAnchor.constraint(equalToConstant: 38),
            emailField.widthAnchor.constraint(equalToConstant: 360), emailField.heightAnchor.constraint(equalToConstant: 38),
            inputField.widthAnchor.constraint(equalToConstant: 360), inputField.heightAnchor.constraint(equalToConstant: 38),
            secureInputField.widthAnchor.constraint(equalToConstant: 360), secureInputField.heightAnchor.constraint(equalToConstant: 38),
            firstNameField.widthAnchor.constraint(equalToConstant: 360), firstNameField.heightAnchor.constraint(equalToConstant: 38),
            lastNameField.widthAnchor.constraint(equalToConstant: 360), lastNameField.heightAnchor.constraint(equalToConstant: 38),
            registrationConsent.widthAnchor.constraint(lessThanOrEqualTo: content.widthAnchor, constant: -64),
            registrationConsent.widthAnchor.constraint(equalToConstant: 500).withPriority(.defaultHigh),
            qrImageView.widthAnchor.constraint(equalToConstant: 180), qrImageView.heightAnchor.constraint(equalToConstant: 180),
            statusLabel.widthAnchor.constraint(lessThanOrEqualTo: content.widthAnchor, constant: -64),
            statusLabel.widthAnchor.constraint(equalToConstant: 500).withPriority(.defaultHigh),
            actionButton.widthAnchor.constraint(equalToConstant: 360), actionButton.heightAnchor.constraint(equalToConstant: 38),
            qrButton.widthAnchor.constraint(equalToConstant: 280), qrButton.heightAnchor.constraint(equalToConstant: 28),
        ])

        chatPane = NSView(frame: NSRect(x: 0, y: 0, width: 1060, height: 720))
        chatPane.autoresizingMask = [.width, .height]
        chatPane.isHidden = true
        sidebarPane = NSView(frame: NSRect(x: 0, y: 0, width: 330, height: 720))
        sidebarPane.wantsLayer = true
        sidebarPane.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        sidebarTitleLabel = NSTextField(labelWithString: "Переписки")
        sidebarTitleLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        sidebarTitleLabel.frame = NSRect(x: 20, y: 674, width: 280, height: 30)
        sidebarPane.addSubview(sidebarTitleLabel)
        accountPicker.frame = NSRect(x: 16, y: 625, width: 298, height: 30)
        addAccountButton.frame = NSRect(x: 16, y: 590, width: 298, height: 28)
        sidebarPane.addSubview(accountPicker)
        sidebarPane.addSubview(addAccountButton)
        searchField = NSSearchField(frame: NSRect(x: 16, y: 548, width: 298, height: 30))
        searchField.placeholderString = "Поиск аккаунтов, чатов и сообщений"
        searchField.target = self
        searchField.action = #selector(searchFieldChanged)
        searchField.sendsSearchStringImmediately = true
        searchField.setAccessibilityLabel("Поиск по аккаунтам, чатам и сообщениям")
        sidebarPane.addSubview(searchField)
        chatList = NSStackView()
        chatList.orientation = .vertical
        chatList.alignment = .leading
        chatList.spacing = 4
        chatList.translatesAutoresizingMaskIntoConstraints = false
        // Keep the list below account controls and search; the prior 660pt
        // frame overlapped the sidebar header controls.
        chatListScroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 330, height: 535))
        chatListScroll.hasVerticalScroller = true
        chatListScroll.drawsBackground = false
        chatListScroll.setAccessibilityLabel("Список переписок и результатов поиска")
        chatListScroll.documentView = chatList
        sidebarPane.addSubview(chatListScroll)
        NSLayoutConstraint.activate([
            chatList.leadingAnchor.constraint(equalTo: chatListScroll.contentView.leadingAnchor, constant: 10),
            chatList.trailingAnchor.constraint(equalTo: chatListScroll.contentView.trailingAnchor, constant: -10),
            chatList.topAnchor.constraint(equalTo: chatListScroll.contentView.topAnchor, constant: -8),
            chatList.widthAnchor.constraint(equalTo: chatListScroll.contentView.widthAnchor, constant: -20),
        ])
        chatPane.addSubview(sidebarPane)
        conversationTitleLabel = NSTextField(labelWithString: "Выберите чат")
        conversationTitleLabel.identifier = NSUserInterfaceItemIdentifier("conversationTitle")
        conversationTitleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        conversationTitleLabel.frame = NSRect(x: 360, y: 674, width: 320, height: 30)
        chatPane.addSubview(conversationTitleLabel)
        topicPicker = NSPopUpButton(frame: NSRect(x: 690, y: 674, width: 340, height: 30), pullsDown: false)
        topicPicker.isHidden = true
        topicPicker.target = self
        topicPicker.action = #selector(selectForumTopic)
        topicPicker.setAccessibilityLabel("Тема форума")
        chatPane.addSubview(topicPicker)
        chatStatusLabel = NSTextField(labelWithString: "")
        chatStatusLabel.font = .systemFont(ofSize: 11)
        chatStatusLabel.textColor = .secondaryLabelColor
        chatStatusLabel.frame = NSRect(x: 360, y: 646, width: 650, height: 20)
        chatPane.addSubview(chatStatusLabel)
        messageList = NSStackView()
        messageList.orientation = .vertical
        messageList.alignment = .leading
        messageList.spacing = 10
        messageList.translatesAutoresizingMaskIntoConstraints = false
        messageScroll = NSScrollView(frame: NSRect(x: 350, y: 125, width: 690, height: 520))
        messageScroll.hasVerticalScroller = true
        messageScroll.drawsBackground = false
        messageScroll.setAccessibilityLabel("История переписки")
        messageScroll.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(messageViewportBoundsDidChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: messageScroll.contentView
        )
        messageScroll.documentView = messageList
        chatPane.addSubview(messageScroll)
        NSLayoutConstraint.activate([
            messageList.leadingAnchor.constraint(equalTo: messageScroll.contentView.leadingAnchor, constant: 16),
            messageList.trailingAnchor.constraint(equalTo: messageScroll.contentView.trailingAnchor, constant: -16),
            messageList.topAnchor.constraint(equalTo: messageScroll.contentView.topAnchor, constant: -12),
            messageList.widthAnchor.constraint(equalTo: messageScroll.contentView.widthAnchor, constant: -32),
        ])
        replyStatusLabel = NSTextField(labelWithString: "")
        replyStatusLabel.font = .systemFont(ofSize: 11)
        replyStatusLabel.textColor = .secondaryLabelColor
        replyStatusLabel.frame = NSRect(x: 440, y: 96, width: 460, height: 18)
        replyStatusLabel.isHidden = true
        chatPane.addSubview(replyStatusLabel)
        clearReplyButton = NSButton(title: "Отмена", target: self, action: #selector(clearReplyTarget))
        clearReplyButton.bezelStyle = .inline
        clearReplyButton.frame = NSRect(x: 910, y: 92, width: 80, height: 24)
        clearReplyButton.isHidden = true
        clearReplyButton.setAccessibilityLabel("Отменить ответ на сообщение")
        chatPane.addSubview(clearReplyButton)
        composerScroll = NSScrollView(frame: NSRect(x: 440, y: 18, width: 480, height: 72))
        composerScroll.hasVerticalScroller = true
        composerScroll.borderType = .bezelBorder
        composer = NSTextView(frame: NSRect(x: 0, y: 0, width: 470, height: 68))
        composer.delegate = self
        composer.font = .systemFont(ofSize: 14)
        composer.setAccessibilityLabel("Текст сообщения")
        composer.setAccessibilityHelp("Введите сообщение. Черновик сохраняется отдельно для аккаунта, переписки и темы.")
        composer.isRichText = false
        composer.isAutomaticQuoteSubstitutionEnabled = false
        composerScroll.documentView = composer
        chatPane.addSubview(composerScroll)
        photoSendButton = NSButton(title: "Фото…", target: self, action: #selector(selectAndSendPhoto))
        photoSendButton.bezelStyle = .rounded
        photoSendButton.frame = NSRect(x: 360, y: 32, width: 72, height: 34)
        photoSendButton.setAccessibilityLabel("Выбрать фотографию для отправки")
        photoSendButton.isEnabled = false
        chatPane.addSubview(photoSendButton)
        sendButton = NSButton(title: "Отправить", target: self, action: #selector(sendText))
        sendButton.bezelStyle = .rounded
        sendButton.frame = NSRect(x: 930, y: 32, width: 100, height: 34)
        sendButton.isEnabled = false
        sendButton.setAccessibilityLabel("Отправить сообщение")
        chatPane.addSubview(sendButton)
        content.addSubview(chatPane)

        lockedView = NSView(frame: content.bounds)
        lockedView.autoresizingMask = [.width, .height]
        lockedView.wantsLayer = true
        lockedView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        lockedView.isHidden = true
        let lockedTitle = NSTextField(labelWithString: "\(ProductIdentity.displayName) заблокирован")
        lockedTitle.identifier = NSUserInterfaceItemIdentifier("lockedTitle")
        lockedTitle.font = .systemFont(ofSize: 24, weight: .semibold)
        lockedTitle.alignment = .center
        lockedTitle.frame = NSRect(x: 300, y: 380, width: 460, height: 40)
        lockedView.addSubview(lockedTitle)
        let lockedStatus = NSTextField(wrappingLabelWithString: "Для просмотра переписок подтвердите владельца этого Mac.")
        lockedStatus.identifier = NSUserInterfaceItemIdentifier("lockedStatus")
        lockedStatus.alignment = .center
        lockedStatus.textColor = .secondaryLabelColor
        lockedStatus.frame = NSRect(x: 300, y: 330, width: 460, height: 38)
        lockedView.addSubview(lockedStatus)
        let unlockButton = NSButton(title: "Разблокировать", target: self, action: #selector(unlock))
        unlockButton.bezelStyle = .rounded
        unlockButton.frame = NSRect(x: 430, y: 270, width: 200, height: 36)
        lockedView.addSubview(unlockButton)
        content.addSubview(lockedView)

        let window = NSWindow(contentRect: content.frame, styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = identifiedWindowTitle(ProductIdentity.displayName)
        window.contentView = content
        // NSWindow owns the content view's frame. The auth stack is centered
        // by Auto Layout inside that coordinate space, independent of window size.
        window.setContentSize(NSSize(width: contentWidth, height: contentHeight))
        window.center()
        // The auth flow includes code, 2FA, QR, and registration states. Keep
        // enough vertical room for these states so the centered form cannot
        // disappear above or below a short window.
        window.minSize = NSSize(width: 900, height: 700)
        window.isReleasedWhenClosed = false
        window.delegate = self
        self.window = window
        layoutWindowContents()
        showWindow()
    }

    func windowDidResize(_ notification: Notification) {
        guard (notification.object as? NSWindow) === window else { return }
        layoutWindowContents()
        scheduleVisibleReadReceiptEvaluation()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        guard (notification.object as? NSWindow) === window else { return }
        scheduleVisibleReadReceiptEvaluation()
    }

    private func setAuthCardVisible(_ visible: Bool) {
        authCard.isHidden = !visible
    }

    @objc private func messageViewportBoundsDidChange(_ notification: Notification) {
        guard let clipView = notification.object as? NSClipView,
              clipView === messageScroll?.contentView else { return }
        scheduleVisibleReadReceiptEvaluation()
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow,
              closingWindow === photoViewerWindow else { return }
        if let key = photoViewerKey { requestedOriginalPhotos.remove(key) }
        if let key = photoViewerKey, let button = photoButtons[key] {
            button.isEnabled = true
            button.title = "Полный размер"
        }
        photoViewerImageView?.image = nil
        if let token = photoViewerToken { photoPipeline.cancelPreview(token) }
        photoViewerWindow = nil
        photoViewerImageView = nil
        photoViewerKey = nil
        photoViewerPrivacyEpoch = nil
        photoViewerToken = nil
    }

    private func layoutWindowContents() {
        guard let window, let content = window.contentView else { return }
        let size = content.bounds.size
        guard size.width > 0, size.height > 0 else { return }

        authStack?.needsUpdateConstraints = true
        content.layoutSubtreeIfNeeded()

        chatPane.frame = NSRect(origin: .zero, size: size)
        let sidebarWidth = min(330, max(280, size.width * 0.32))
        sidebarPane.frame = NSRect(x: 0, y: 0, width: sidebarWidth, height: size.height)
        sidebarTitleLabel.frame = NSRect(x: 20, y: size.height - 46, width: sidebarWidth - 40, height: 30)
        accountPicker.frame = NSRect(x: 16, y: size.height - 95, width: sidebarWidth - 32, height: 30)
        addAccountButton.frame = NSRect(x: 16, y: size.height - 130, width: sidebarWidth - 32, height: 28)
        searchField.frame = NSRect(x: 16, y: size.height - 172, width: sidebarWidth - 32, height: 30)
        chatListScroll.frame = NSRect(x: 0, y: 0, width: sidebarWidth, height: max(180, size.height - 185))

        let mainX = sidebarWidth + 20
        let mainWidth = max(200, size.width - mainX - 20)
        conversationTitleLabel.frame = NSRect(x: mainX + 10, y: size.height - 46, width: min(320, max(220, mainWidth - 190)), height: 30)
        topicPicker.frame = NSRect(x: mainX + 340, y: size.height - 46, width: max(180, size.width - mainX - 360), height: 30)
        chatStatusLabel.frame = NSRect(x: mainX + 10, y: size.height - 74, width: mainWidth - 20, height: 20)
        messageScroll.frame = NSRect(x: mainX, y: 125, width: mainWidth, height: max(200, size.height - 200))
        replyStatusLabel.frame = NSRect(x: mainX + 90, y: 96, width: max(180, size.width - mainX - 240), height: 18)
        clearReplyButton.frame = NSRect(x: size.width - 150, y: 92, width: 80, height: 24)
        composerScroll.frame = NSRect(x: mainX + 90, y: 18, width: max(220, size.width - mainX - 230), height: 72)
        composer.frame = NSRect(x: 0, y: 0, width: composerScroll.contentView.bounds.width, height: 68)
        photoSendButton.frame = NSRect(x: mainX + 10, y: 32, width: 72, height: 34)
        sendButton.frame = NSRect(x: size.width - 130, y: 32, width: 100, height: 34)

        if let lockedTitle = lockedView.subviews.first(where: { $0.identifier?.rawValue == "lockedTitle" }) {
            lockedTitle.frame = NSRect(x: (size.width - 460) / 2, y: size.height / 2 + 20, width: 460, height: 40)
        }
        if let lockedStatus = lockedView.subviews.first(where: { $0.identifier?.rawValue == "lockedStatus" }) {
            lockedStatus.frame = NSRect(x: (size.width - 460) / 2, y: size.height / 2 - 30, width: 460, height: 38)
        }
        if let unlockButton = lockedView.subviews.first(where: { $0 is NSButton }) {
            unlockButton.frame = NSRect(x: (size.width - 200) / 2, y: size.height / 2 - 100, width: 200, height: 36)
        }
    }

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "N"
        let menu = NSMenu()
        statusMenuItem = NSMenuItem(title: "Аккаунты ещё не загружены", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Открыть", action: #selector(openWindow), keyEquivalent: "")
        menu.addItem(withTitle: "Заблокировать", action: #selector(lock), keyEquivalent: "")
        menu.addItem(withTitle: "Выйти", action: #selector(quit), keyEquivalent: "")
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
        refreshStatusMenu()
    }

    private func startConnectionObservers() {
        let revisionCounter = networkPathRevisionCounter
        networkMonitor.pathUpdateHandler = { [weak self, revisionCounter] path in
            // NWPathMonitor delivers path-change observations. Keep their
            // identity separate from TDLib's coarse Wi-Fi/mobile/other type.
            let revision = revisionCounter.next()
            let type = NetworkTypeUpdatePolicy.tdlibType(
                isSatisfied: path.status == .satisfied,
                usesWiFi: path.usesInterfaceType(.wifi),
                usesCellular: path.usesInterfaceType(.cellular)
            )
            Task { @MainActor [weak self] in
                self?.scheduleNetworkTypeUpdate(type, revision: revision)
            }
        }
        networkMonitor.start(queue: networkMonitorQueue)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(didWakeFromSleep(_:)),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    private func scheduleNetworkTypeUpdate(_ type: String, revision: UInt64, force: Bool = false) {
        let accepted = networkPathRevisionGate.accept(revision)
        guard accepted || (force && networkPathRevisionGate.isLatest(revision)) else { return }
        networkTypeUpdateTask?.cancel()
        networkTypeUpdateTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled, let self else { return }
            guard self.networkPathRevisionGate.isLatest(revision) else { return }
            guard NetworkTypeUpdatePolicy.shouldApply(
                currentRevision: self.currentAppliedNetworkPathRevision,
                nextRevision: revision,
                force: force
            ) else { return }
            self.currentAppliedNetworkPathRevision = revision
            self.currentTDLibNetworkType = type
            for accountRuntime in self.runtimesByAccount.values {
                do { try accountRuntime.applyNetworkType(type) }
                catch where accountRuntime === self.runtime { self.setStatus("Не удалось обновить сетевое состояние TDLib для выбранного аккаунта.") }
                catch { }
            }
        }
    }

    @objc private func didWakeFromSleep(_ notification: Notification) {
        // The cached TDLib type may predate sleep. Reconcile from the current
        // Network.framework snapshot, then reapply once to every existing
        // client without recreating runtimes or keeping the Mac awake.
        let path = networkMonitor.currentPath
        let revision = networkPathRevisionCounter.next()
        scheduleNetworkTypeUpdate(
            NetworkTypeUpdatePolicy.tdlibType(
                isSatisfied: path.status == .satisfied,
                usesWiFi: path.usesInterfaceType(.wifi),
                usesCellular: path.usesInterfaceType(.cellular)
            ),
            revision: revision,
            force: true
        )
    }

    private func refreshStatusMenu() {
        guard statusMenuItem != nil else { return }
        let accounts = Array(runtimesByAccount.values)
        let summary = AccountStatusMenuSummary.make(
            runtimes: accounts.map {
                AccountStatusMenuRuntime(
                    account: $0.account,
                    telegramUserID: $0.telegramUserID,
                    authorizationState: $0.authorizationState,
                    hasError: $0.lastTDLibError != nil
                )
            },
            startupFailures: profileStartupFailures
        )
        let storageWarning = pendingProfileStorageWarnings > 0
            ? " · \(pendingProfileStorageWarnings) локальных профилей не проверены"
            : ""
        if accounts.isEmpty, knownProfilesByAccount.isEmpty {
            statusMenuItem.title = "Аккаунтов пока нет\(storageWarning)"
        } else {
            statusMenuItem.title = "Аккаунты: \(summary.authorizedCount) авторизованы · \(summary.awaitingInputCount) требуют входа · \(summary.failedCount) с ошибкой\(storageWarning)"
        }
        logoutAccountMenuItem?.isEnabled = !lockState
            && runtime?.telegramUserID != nil
            && runtime?.isLogoutRequested == false
    }

    private func buildMainMenu() {
        let main = NSMenu()
        let appMenuItem = NSMenuItem()
        main.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "О \(ProductIdentity.displayName)", action: nil, keyEquivalent: "")
        appMenu.addItem(.separator())
        let loginSettings = NSMenuItem(
            title: "Запускать при входе в macOS…",
            action: #selector(configureLoginAtStartup),
            keyEquivalent: ""
        )
        loginSettings.target = self
        appMenu.addItem(loginSettings)
        appMenu.addItem(.separator())
        let apiHashSettings = NSMenuItem(
            title: "Настроить или заменить API hash приложения…",
            action: #selector(configureTelegramAPIHash),
            keyEquivalent: ""
        )
        apiHashSettings.target = self
        appMenu.addItem(apiHashSettings)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Выйти", action: #selector(quit), keyEquivalent: "q")
        appMenu.items.forEach { $0.target = self }
        appMenuItem.submenu = appMenu

        let accountMenuItem = NSMenuItem(title: "Аккаунт", action: nil, keyEquivalent: "")
        main.addItem(accountMenuItem)
        let accountMenu = NSMenu(title: "Аккаунт")
        let addAccount = NSMenuItem(title: "Добавить аккаунт…", action: #selector(addAccountFromMenu), keyEquivalent: "")
        addAccount.target = self
        accountMenu.addItem(addAccount)
        accountMenu.addItem(.separator())
        let logout = NSMenuItem(title: "Выйти из выбранного аккаунта…", action: #selector(logOutSelectedAccount), keyEquivalent: "")
        logout.target = self
        logoutAccountMenuItem = logout
        accountMenu.addItem(logout)
        accountMenuItem.submenu = accountMenu

        let windowMenuItem = NSMenuItem()
        main.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Окно")
        let close = NSMenuItem(title: "Закрыть окно", action: #selector(closeWindow), keyEquivalent: "w")
        close.keyEquivalentModifierMask = [.command]
        close.target = self
        windowMenu.addItem(close)
        windowMenuItem.submenu = windowMenu
        NSApp.mainMenu = main
        NSApp.windowsMenu = windowMenu
    }

    @objc private func configureLoginAtStartup() {
        let service = SMAppService.mainApp
        guard service.status != .notFound else {
            let error = NSAlert()
            error.messageText = "macOS не нашла службу автозапуска \(ProductIdentity.displayName)"
            error.informativeText = "Откройте приложение из установленного пакета и повторите попытку."
            error.runModal()
            return
        }

        let enabled = service.status == .enabled || service.status == .requiresApproval
        let toggle = NSButton(checkboxWithTitle: "Запускать \(ProductIdentity.displayName) при входе в macOS", target: nil, action: nil)
        toggle.state = enabled ? .on : .off

        let alert = NSAlert()
        alert.messageText = "Автозапуск \(ProductIdentity.displayName)"
        alert.informativeText = service.status == .requiresApproval
            ? "Подтвердите \(ProductIdentity.displayName) в Системных настройках → Основные → Объекты входа. Выключите переключатель здесь, чтобы отменить регистрацию."
            : "Настройка использует встроенную службу входа macOS. По умолчанию автозапуск выключен."
        alert.accessoryView = toggle
        alert.addButton(withTitle: "Применить")
        alert.addButton(withTitle: "Отмена")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            if toggle.state == .on {
                if service.status == .requiresApproval {
                    setStatus("Автозапуск ожидает разрешения в Системных настройках.")
                    SMAppService.openSystemSettingsLoginItems()
                    return
                }
                if service.status != .enabled { try service.register() }
                if service.status == .requiresApproval {
                    setStatus("Автозапуск ожидает разрешения в Системных настройках.")
                    SMAppService.openSystemSettingsLoginItems()
                } else {
                    setStatus("Автозапуск \(ProductIdentity.displayName) при входе включён.")
                }
            } else {
                if service.status != .notRegistered { try service.unregister() }
                setStatus("Автозапуск \(ProductIdentity.displayName) при входе выключен.")
            }
        } catch {
            setStatus("macOS не изменила настройку автозапуска. Проверьте объекты входа в Системных настройках.")
        }
    }

    @objc private func configureTelegramAPIHash() {
        guard !lockState, !closingForTermination else {
            setStatus("Разблокируйте приложение, чтобы изменить его Telegram API credentials.")
            return
        }
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 28))
        field.placeholderString = "32 шестнадцатеричных символа"
        field.setAccessibilityLabel("Telegram API hash приложения")
        field.setAccessibilityHelp("Сохраняется только в Связке ключей macOS. Не вводите код входа или пароль Telegram сюда.")
        let alert = NSAlert()
        alert.messageText = "Настройка подключения Neridian"
        alert.informativeText = "Введите API hash этого приложения из my.telegram.org. Значение хранится в Связке ключей macOS и не записывается в файлы проекта."
        alert.accessoryView = field
        alert.addButton(withTitle: "Сохранить в Связку ключей")
        alert.addButton(withTitle: "Отмена")
        guard alert.runModal() == .alertFirstButtonReturn else {
            field.stringValue = ""
            return
        }
        let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        field.stringValue = ""
        guard SecretsStore.isValidTelegramAPIHash(value) else {
            setStatus("API hash должен содержать ровно 32 шестнадцатеричных символа. Значение не сохранено.")
            return
        }
        setStatus("Сохраняю API hash в Связку ключей macOS…")
        Task { @MainActor [weak self] in
            do {
                try await SecretsStore.performKeychainRead {
                    try SecretsStore().storeTelegramAPIHash(value)
                }
                self?.setStatus("API hash сохранён в Связке ключей. Введите номер и нажмите «Продолжить», чтобы начать новый вход.")
            } catch {
                self?.setStatus("Не удалось сохранить API hash в Связку ключей. Значение не записано в файлы проекта.")
            }
        }
    }

    @objc private func primaryAction() {
        guard !lockState else { return }
        guard let runtime else {
            guard pendingAuthorizationType == "authorizationStateWaitPhoneNumber" else {
                setStatus("Подождите, пока подготовится экран входа.")
                return
            }
            guard let number = validatedPhoneNumber() else { return }
            pendingInitialAuthorizationAction = .phoneNumber(number)
            beginFirstAccount()
            return
        }
        guard let authType = pendingAuthorizationType, !authRequestInFlight else { return }
        let target = runtime
        let account = target.account
        let generation = target.generation
        let privacyEpoch = privacyDispatchBarrier.currentEpoch()
        do {
            let request: [String: Any]
            switch authType {
            case "authorizationStateWaitPhoneNumber":
                guard let number = validatedPhoneNumber() else { return }
                request = ["@type": "setAuthenticationPhoneNumber", "phone_number": number, "settings": NSNull()]
            case "authorizationStateWaitCode":
                let code = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !code.isEmpty else { setStatus("Введите код из сообщения Telegram."); return }
                request = ["@type": "checkAuthenticationCode", "code": code]
            case "authorizationStateWaitPassword":
                let password = secureInputField.stringValue
                guard !password.isEmpty else { setStatus("Введите пароль двухэтапной проверки."); return }
                request = ["@type": "checkAuthenticationPassword", "password": password]
            case "authorizationStateWaitEmailAddress":
                let email = emailField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                let pieces = email.split(separator: "@", omittingEmptySubsequences: false)
                guard pieces.count == 2, !pieces[0].isEmpty, pieces[1].contains(".") else {
                    setStatus("Проверьте адрес электронной почты.")
                    return
                }
                request = ["@type": "setAuthenticationEmailAddress", "email_address": email]
            case "authorizationStateWaitEmailCode":
                let code = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !code.isEmpty else { setStatus("Введите код из письма."); return }
                request = ["@type": "checkAuthenticationEmailCode", "code": ["@type": "emailAddressAuthenticationCode", "code": code]]
            case "authorizationStateWaitRegistration":
                let firstName = firstNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                let lastName = lastNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !firstName.isEmpty else { setStatus("Введите имя для нового аккаунта."); return }
                guard registrationTermsAvailable, registrationConsent.state == .on else { setStatus("Чтобы продолжить, прочитайте и примите полученные условия регистрации Telegram."); return }
                request = ["@type": "registerUser", "first_name": firstName, "last_name": lastName, "disable_notification": false]
            default:
                setStatus("TDLib ожидает другой шаг авторизации.")
                return
            }
            historyRequestCounter &+= 1
            let extra = "auth-\(historyRequestCounter)"
            var routedRequest = request
            routedRequest["@extra"] = extra
            let dispatched = try privacyDispatchBarrier.dispatchAuthenticationCommand(
                account: account,
                runtimeGeneration: generation,
                privacyEpoch: privacyEpoch,
                currentAccount: target.account,
                currentGeneration: target.generation
            ) { try target.send(routedRequest) }
            guard dispatched else {
                setStatus("Шаг входа отменён: приложение заблокировано или профиль изменился.")
                return
            }
            pendingAuthRequestsByExtra[extra] = (runtime.account, authType)
            authRequestInFlight = true
            actionButton.isEnabled = false
            setStatus("Запрос отправлен TDLib. Ожидание следующего шага…")
        } catch {
            setStatus("Не удалось отправить запрос авторизации.")
        }
    }

    private func validatedPhoneNumber() -> String? {
        let result = PhoneNumberInputPolicy.validate(phoneField.stringValue, selectedCallingCode: selectedCallingCode)
        guard case let .accepted(number) = result else {
            switch result {
            case .empty:
                setStatus("Введите номер телефона.")
            case .invalidCharacters:
                setStatus("Проверьте номер: используйте цифры и разделители, без букв или второго знака +.")
            case .invalidCountryCode:
                setStatus("Не удалось определить код выбранной страны. Выберите страну или введите номер с +.")
            case .repeatedCountryCode:
                setStatus("Код страны уже выбран. Введите национальную часть или начните полный международный номер с +.")
            case .invalidLength:
                setStatus("Введите номер с кодом страны: от 4 до 15 цифр.")
            case .accepted:
                break
            }
            return nil
        }
        let explicitlyInternational = phoneField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("+")
        guard explicitlyInternational || !phoneCountries.isEmpty else {
            setStatus("Загружается список стран. Можно также ввести номер полностью, начиная с +.")
            return nil
        }
        return number
    }

    private func beginFirstAccount() {
        guard !initialAccountCreationInProgress else { return }
        initialAccountCreationInProgress = true
        Task { @MainActor in
            await addAccountProfile()
            initialAccountCreationInProgress = false
            if runtime == nil {
                pendingInitialAuthorizationAction = nil
            }
        }
    }

    @objc private func selectAccount() {
        let index = accountPicker.indexOfSelectedItem
        guard accountPickerAccounts.indices.contains(index) else { return }
        let account = accountPickerAccounts[index]
        guard let selected = runtimesByAccount[account] else {
            retryOpeningProfile(account)
            return
        }
        authRequestInFlight = pendingAuthRequestsByExtra.values.contains { $0.account == account }
        closePhotoViewer()
        if let previous = runtime, previous !== selected,
           let previousChat = selectedChatByAccount[previous.account] {
            stopTypingAction()
            cancelPhotoDownloads(account: previous.account, chatID: previousChat)
            try? previous.send(["@type": "closeChat", "chat_id": previousChat])
        }
        presentRuntime(selected)
    }

    private func presentRuntime(_ selected: LocalAccountRuntime) {
        runtime = selected
        closedProfileToRetry = nil
        actionButton.target = self
        actionButton.action = #selector(primaryAction)
        pendingAuthorizationType = selected.authorizationState
        inputField.isHidden = true
        secureInputField.isHidden = true
        actionButton.isEnabled = false
        setStatus("Выбран аккаунт \(safeAccountName(selected) ?? "Аккаунт"). Остальные авторизованные аккаунты продолжают работу.")
        switch AccountPresentation.conversationRestoration(
            telegramUserID: selected.telegramUserID,
            authorizationState: selected.authorizationState,
            selectedChatID: selectedChatByAccount[selected.account]
        ) {
        case .reopen(let chatID):
            selected.loadMainChats()
            showAuthenticatedChatUI()
            refreshChatList()
            // selectAccount closed the previous account's visible chat. Restore
            // this account through the same TDLib openChat path so the restored
            // UI and TDLib's displayed-chat state cannot diverge.
            openChat(chatID: chatID, in: selected)
        case .emptyConversation:
            selected.loadMainChats()
            showAuthenticatedChatUI()
            refreshChatList()
            displaySelectedConversation()
            refreshComposerState()
        case .authorization:
            presentAuthorizationState(selected.authorizationState, info: authPresentationInfoByAccount[selected.account] ?? [:])
        }
    }

    private func refreshAccountPicker(select account: AccountUUID? = nil) {
        accountPickerAccounts = profileOrder.filter { knownProfilesByAccount[$0] != nil }
        accountPicker.removeAllItems()
        accountPickerAccounts.enumerated().forEach { index, id in
            guard let profile = knownProfilesByAccount[id] else { return }
            let runtime = runtimesByAccount[id]
            accountPicker.addItem(withTitle: AccountPresentation.pickerTitle(
                localOrdinal: index + 1,
                telegramUserID: runtime?.telegramUserID ?? profile.telegramUserID,
                candidate: runtime?.displayName ?? profile.displayName,
                authorizationState: runtime?.authorizationState,
                runtimeIsOpen: runtime != nil || profileStartupTasks[id] != nil,
                hasError: profileStartupFailures.contains(id) || runtime?.lastTDLibError != nil,
                logoutCleanupPending: profile.logoutCleanupPending == true
            ))
        }
        accountPicker.isHidden = accountPickerAccounts.isEmpty
        addAccountButton.isHidden = knownProfilesByAccount.isEmpty
        accountPicker.isEnabled = !accountPickerAccounts.isEmpty && !lockState
        if let account, let index = accountPickerAccounts.firstIndex(of: account) {
            accountPicker.selectItem(at: index)
            runtime = runtimesByAccount[account]
        } else if let runtime, let index = accountPickerAccounts.firstIndex(of: runtime.account) {
            accountPicker.selectItem(at: index)
        }
    }

    private func rememberProfiles(_ profiles: [AccountProfile]) {
        knownProfilesByAccount = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        profileOrder = profiles.sorted {
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.id.uuidString < $1.id.id.uuidString
        }.map(\.id)
    }

    private func retryOpeningProfile(_ account: AccountUUID) {
        guard !lockState, !profileRestoreInProgress, !closingForTermination,
              !profileOpenRequests.contains(account),
              profileStartupTasks[account] == nil,
              let profile = knownProfilesByAccount[account] else { return }
        prepareToSelectUnopenedProfile(account)
        if profile.logoutCleanupPending == true {
            retryPendingLogoutCleanup(profile)
            return
        }
        profileOpenRequests.insert(account)
        setStatus("Повторно открываю локальный профиль \(profileOrder.firstIndex(of: account).map { $0 + 1 } ?? 1)…")
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.profileOpenRequests.remove(account) }
            do {
                let apiHash = try await SecretsStore.performKeychainRead {
                    try SecretsStore().telegramAPIHash()
                }
                if let startup = self.scheduleProfileStartup(profile, apiHash: apiHash, select: true) {
                    await startup.value
                }
            } catch SecretsStoreError.missing {
                self.profileStartupFailures.insert(account)
                self.setStatus("API hash приложения не задан. Откройте меню Neridian → «Настроить или заменить API hash приложения…». Вход не начат; данные других Telegram-приложений не читались.")
            } catch {
                self.profileStartupFailures.insert(account)
                self.setStatus("Не удалось повторно открыть локальный профиль. Сохранённые данные не изменены.")
            }
            self.refreshAccountPicker(select: account)
        }
    }

    @objc private func retryClosedProfile() {
        guard let account = closedProfileToRetry, !lockState else { return }
        retryOpeningProfile(account)
    }

    private func retryPendingLogoutCleanup(_ profile: AccountProfile) {
        guard !profileRestoreInProgress, !closingForTermination,
              !profileOpenRequests.contains(profile.id),
              profile.logoutCleanupPending == true,
              let expectedTelegramUserID = profile.telegramUserID else { return }
        profileOpenRequests.insert(profile.id)
        setStatus("Продолжаю очистку профиля после подтверждённого выхода…")
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.profileOpenRequests.remove(profile.id) }
            do {
                try await self.completePendingLogoutCleanup(
                    profile.id,
                    expectedTelegramUserID: expectedTelegramUserID
                )
                self.profileStartupFailures.remove(profile.id)
                self.refreshAccountPicker()
                self.refreshStatusMenu()
                self.setStatus("Локальная очистка профиля после выхода завершена.")
                if self.runtimesByAccount.isEmpty, self.knownProfilesByAccount.isEmpty {
                    Task { @MainActor [weak self] in await self?.addAccountProfile() }
                }
            } catch {
                self.profileStartupFailures.insert(profile.id)
                self.refreshAccountPicker(select: profile.id)
                self.refreshStatusMenu()
                self.setStatus("Очистка после выхода не завершена. Профиль не будет запущен и не сможет принять другую identity; выберите его позже, чтобы повторить очистку.")
            }
        }
    }

    private func showClosedProfileRecovery(_ account: AccountUUID) {
        closedProfileToRetry = account
        closePhotoViewer()
        clearStack(messageList)
        setAuthCardVisible(true)
        chatPane.isHidden = true
        loginHeading.stringValue = "Профиль временно закрыт"
        loginSubtitle.stringValue = "Связь с Telegram для этого локального профиля закрылась. Профиль и база не удалены; можно повторно открыть именно этот профиль. Остальные аккаунты продолжают работу в фоне."
        phoneField.isHidden = true
        emailField.isHidden = true
        countryPicker.isHidden = true
        inputField.isHidden = true
        secureInputField.isHidden = true
        firstNameField.isHidden = true
        lastNameField.isHidden = true
        registrationTermsScroll.isHidden = true
        registrationConsent.isHidden = true
        qrImageView.isHidden = true
        qrButton.isHidden = true
        actionButton.title = "Повторить открытие профиля"
        actionButton.setAccessibilityLabel("Повторно открыть этот локальный профиль")
        actionButton.target = self
        actionButton.action = #selector(retryClosedProfile)
        actionButton.isEnabled = !profileRestoreInProgress && !closingForTermination
        actionButton.isHidden = false
        setStatus("Профиль закрыт. Локальные данные сохранены; повторный вход в другой аккаунт не выполняется.")
        window.title = identifiedWindowTitle("Профиль временно закрыт — \(ProductIdentity.displayName)")
    }

    /// Clears the previous account's visible conversation before opening a
    /// local profile that does not currently have a runtime. The profile's
    /// own TDLib database remains untouched; other account runtimes stay open.
    private func prepareToSelectUnopenedProfile(_ account: AccountUUID) {
        authRequestInFlight = false
        closePhotoViewer()
        if let previous = runtime,
           let previousChat = selectedChatByAccount[previous.account] {
            stopTypingAction()
            cancelPhotoDownloads(account: previous.account, chatID: previousChat)
            try? previous.send(["@type": "closeChat", "chat_id": previousChat])
        }
        runtime = nil
        pendingAuthorizationType = nil
        pendingInitialAuthorizationAction = nil
        chatPane.isHidden = true
        setAuthCardVisible(true)
        registrationTermsScroll.isHidden = true
        countryPicker.isHidden = true
        phoneField.isHidden = true
        emailField.isHidden = true
        inputField.isHidden = true
        secureInputField.isHidden = true
        firstNameField.isHidden = true
        lastNameField.isHidden = true
        registrationConsent.isHidden = true
        qrImageView.isHidden = true
        qrButton.isHidden = true
        actionButton.isHidden = true
        phoneField.stringValue = ""
        emailField.stringValue = ""
        inputField.stringValue = ""
        secureInputField.stringValue = ""
        firstNameField.stringValue = ""
        lastNameField.stringValue = ""
        loginHeading.stringValue = "Локальный профиль"
        loginSubtitle.stringValue = "Подготавливаю сохранённый вход. Данные предыдущего профиля скрыты."
        statusLabel.stringValue = "Открываю профиль \(profileOrder.firstIndex(of: account).map { $0 + 1 } ?? 1)…"
        window.title = identifiedWindowTitle(ProductIdentity.displayName)
    }

    private func finishLogoutProfile(_ target: LocalAccountRuntime, expectedTelegramUserID: Int64) async -> Bool {
        do {
            guard let catalogue else { return false }
            try await catalogue.markLogoutCleanupPending(
                target.account,
                expectedTelegramUserID: expectedTelegramUserID
            )
            if let updated = await catalogue.allProfiles().first(where: { $0.id == target.account }) {
                knownProfilesByAccount[target.account] = updated
            }
            try await completePendingLogoutCleanup(
                target.account,
                expectedTelegramUserID: expectedTelegramUserID
            )
            refreshAccountPicker()
            return true
        } catch {
            profileStartupFailures.insert(target.account)
            refreshAccountPicker()
            return false
        }
    }

    private func completePendingLogoutCleanup(
        _ account: AccountUUID,
        expectedTelegramUserID: Int64
    ) async throws {
        guard let catalogue else { throw AccountCatalogueError.accountNotFound }
        let storageRoot = try accountStorageRoot()
        try await PendingLogoutCleanup.resume(
            account: account,
            expectedTelegramUserID: expectedTelegramUserID,
            catalogue: catalogue,
            removeKeys: { account in
                try await Task.detached(priority: .utility) {
                    try SecretsStore().removeAccountKeys(for: account)
                }.value
            },
            removeFiles: { account in
                let accountRoot = storageRoot
                    .appendingPathComponent(account.id.uuidString.lowercased(), isDirectory: true)
                try await Task.detached(priority: .utility) {
                    if FileManager.default.fileExists(atPath: accountRoot.path) {
                        try FileManager.default.removeItem(at: accountRoot)
                    }
                }.value
            }
        )
        knownProfilesByAccount.removeValue(forKey: account)
        profileOrder.removeAll { $0 == account }
        profileStartupFailures.remove(account)
    }

    private func purgeInMemoryAccountState(_ account: AccountUUID) {
        notificationUnlockHandoff.clear(account: account)
        draftsByConversation = draftsByConversation.filter { $0.key.account != account }
        draftStoresByAccount.removeValue(forKey: account)
        dirtyDraftAccounts.remove(account)
        unavailableDraftAccounts.remove(account)
        sendEligibilityByAccount.removeValue(forKey: account)
        stagedOutgoingPhotosByFileID.removeValue(forKey: account)
        pendingStagedPhotoPaths.removeValue(forKey: account)
        completedOutgoingPhotoFileIDs.removeValue(forKey: account)
        outgoingPhotoUploadActiveByFileID.removeValue(forKey: account)
        terminallyDeletedOutgoingPhotoURLs.removeValue(forKey: account)
        outgoingPhotoManifestStoresByAccount.removeValue(forKey: account)
        unavailableOutgoingPhotoManifestAccounts.remove(account)
        chatRowsByAccount.removeValue(forKey: account)
        chatOrderByAccount.removeValue(forKey: account)
        selectedChatByAccount.removeValue(forKey: account)
        messagesByConversation = messagesByConversation.filter { $0.key.account != account }
        replyTargetsByConversation = replyTargetsByConversation.filter { $0.key.account != account }
        messageEditDrafts = messageEditDrafts.filter { $0.key.conversation.account != account }
        pendingMessagePropertiesByExtra = pendingMessagePropertiesByExtra.filter { $0.value.key.conversation.account != account }
        pendingMessageMutationsByExtra = pendingMessageMutationsByExtra.filter { $0.value.context.key.conversation.account != account }
        pendingSendByExtra = pendingSendByExtra.filter { $0.value.intent.account != account }
        pendingSendLifecycle.removeAll(for: account)
        retryableFailedSends = retryableFailedSends.filter { $0.key.conversation.account != account }
        pendingRetryByExtra = pendingRetryByExtra.filter { $0.value.key.account != account }
        pendingRetryRefreshByExtra = pendingRetryRefreshByExtra.filter { $0.value.key.conversation.account != account }
        retryingSendKeys = retryingSendKeys.filter { $0.account != account }
        forumTopicsByAccount.removeValue(forKey: account)
        forumChatsByAccount.removeValue(forKey: account)
        selectedForumTopicIDsByAccount.removeValue(forKey: account)
        let notificationIDs = AccountNotificationCleanup.remove(
            account: account,
            identifiersByAccount: &notificationIDsByAccount,
            targetsByIdentifier: &notificationTargets
        )
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: Array(notificationIDs))
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: Array(notificationIDs))
        photoPipeline.cancelPreviews(for: account)
        if photoViewerKey?.account == account {
            photoViewerToken = nil
            photoViewerPrivacyEpoch = nil
            photoViewerImageView?.image = nil
            photoViewerWindow?.close()
            photoViewerWindow = nil
            photoViewerImageView = nil
            photoViewerKey = nil
        }
        for key in photoViews.keys.filter({ $0.account == account }) {
            photoViews[key]?.removeFromSuperview()
            photoViews.removeValue(forKey: key)
            photoButtons.removeValue(forKey: key)?.removeFromSuperview()
            photoLocalURLs.removeValue(forKey: key)
            photoOriginalFileIDs.removeValue(forKey: key)
            photoOriginalCanBeDownloaded.removeValue(forKey: key)
            photoOriginalLocalURLs.removeValue(forKey: key)
            photoTokens.removeValue(forKey: key)
        }
        photoOriginalKeysByFileID.removeValue(forKey: account)
        pendingPhotoByExtra = pendingPhotoByExtra.filter { $0.value.account != account }
        pendingOriginalPhotoByExtra = pendingOriginalPhotoByExtra.filter { $0.value.account != account }
        requestedOriginalPhotos = requestedOriginalPhotos.filter { $0.account != account }
        photoDownloadsByConversation = photoDownloadsByConversation.filter { $0.key.account != account }
        _ = pendingHistoryRequests.remove(account: account)
        historyRequestGenerationByConversation = historyRequestGenerationByConversation.filter { $0.key.account != account }
        sponsoredMessagesByKey = sponsoredMessagesByKey.filter { $0.key.account != account }
        sponsoredMessagesBetweenByKey = sponsoredMessagesBetweenByKey.filter { $0.key.account != account }
        sponsoredMessagesFetchedAt = sponsoredMessagesFetchedAt.filter { $0.key.account != account }
        sponsoredEligibleChatKeys = sponsoredEligibleChatKeys.filter { $0.account != account }
        sponsoredChannelKeys = sponsoredChannelKeys.filter { $0.account != account }
        sponsoredBotKeys = sponsoredBotKeys.filter { $0.account != account }
        pendingSponsoredMessagesByExtra = pendingSponsoredMessagesByExtra.filter { $0.value.account != account }
        pendingSponsoredBotUsersByExtra = pendingSponsoredBotUsersByExtra.filter { $0.value.account != account }
        pendingSponsoredReportsByExtra = pendingSponsoredReportsByExtra.filter { $0.value.key.account != account }
        sponsoredActionByControlID = sponsoredActionByControlID.filter { $0.value.key.account != account }
        sponsoredReportActionByControlID = sponsoredReportActionByControlID.filter { $0.value.key.account != account }
        pendingSponsoredPhotoByExtra = pendingSponsoredPhotoByExtra.filter { $0.value.account != account }
        sponsoredPhotoURLs = sponsoredPhotoURLs.filter { $0.key.account != account }
        requestedSponsoredPhotos = Set(requestedSponsoredPhotos.filter { $0.account != account })
        failedSponsoredPhotos = Set(failedSponsoredPhotos.filter { $0.account != account })
        sponsoredPhotoRetryByControlID = sponsoredPhotoRetryByControlID.filter { $0.value.key.account != account }
        pendingForumTopicsByExtra.removeAll()
        _ = pendingSearchRequests.remove(account: account)
        searchResults.removeAll()
        searchResultByControlID.removeAll()
        activeSearchQuery = ""
        deferredSearch = nil
        searchField.stringValue = ""
        refreshChatList()
    }

    @objc private func addAccount() {
        Task { @MainActor in await addAccountProfile() }
    }

    @objc private func addAccountFromMenu() { addAccount() }

    @objc private func logOutSelectedAccount() {
        guard !lockState,
              let selected = runtime,
              let expectedUserID = selected.telegramUserID,
              !selected.isLogoutRequested else {
            setStatus("Выберите разблокированный авторизованный аккаунт для выхода.")
            return
        }

        let account = selected.account
        let generation = selected.generation
        let epoch = privacyDispatchBarrier.currentEpoch()
        let title = safeAccountName(selected) ?? "выбранный аккаунт"
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Выйти из аккаунта «\(title)»?"
        alert.informativeText = "Telegram требует сетевое соединение для выхода. После подтверждения Telegram удалит локальные данные этого профиля; NeTelegram также удалит сохранённые черновики. Остальные аккаунты продолжат работу."
        alert.addButton(withTitle: "Выйти и удалить локальные данные")
        alert.addButton(withTitle: "Отмена")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        guard !lockState,
              runtime === selected,
              selected.account == account,
              selected.telegramUserID == expectedUserID,
              selected.generation == generation else {
            setStatus("Выбранный аккаунт изменился или заблокирован; выход не отправлен.")
            return
        }

        do {
            let accepted = try privacyDispatchBarrier.dispatchBoundUserCommand(
                account: account,
                expectedTelegramUserID: expectedUserID,
                runtimeGeneration: generation,
                privacyEpoch: epoch,
                currentAccount: selected.account,
                currentTelegramUserID: expectedUserID,
                currentGeneration: selected.generation
            ) {
                try selected.requestLogout()
            }
            guard accepted else {
                setStatus("Состояние блокировки или аккаунта изменилось; выход не отправлен.")
                return
            }
            if let client = selected.route?.client.value { pendingClosures.insert(client) }
            setStatus("Запросил выход у Telegram. Этот аккаунт освободится после подтверждённого закрытия; остальные продолжают работу.")
            refreshStatusMenu()
        } catch {
            setStatus("TDLib не принял запрос выхода. Профиль и локальные данные сохранены.")
            refreshStatusMenu()
        }
    }

    private func accountStorageRoot() throws -> URL {
        if let catalogueRoot { return catalogueRoot }
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
#if DEBUG
        let arguments = CommandLine.arguments
        let argumentRoot: String? = arguments.firstIndex(of: "--app-support-root").flatMap { index in
            arguments.indices.contains(index + 1) ? arguments[index + 1] : nil
        }
        let override = (argumentRoot ?? ProcessInfo.processInfo.environment["NETELEGRAM_APP_SUPPORT_ROOT"])
            .flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0, isDirectory: true) }
        let support = AccountStorageRoot.resolve(
            applicationSupportDirectory: applicationSupport,
            bundleIdentifier: Bundle.main.bundleIdentifier,
            isDevelopmentBuild: true,
            override: override
        )
#else
        let support = AccountStorageRoot.resolve(
            applicationSupportDirectory: applicationSupport,
            bundleIdentifier: Bundle.main.bundleIdentifier,
            isDevelopmentBuild: false
        )
#endif
        let root = support.appendingPathComponent("Accounts", isDirectory: true)
        catalogueRoot = root
        return root
    }

    private func accountCatalogue() throws -> AccountCatalogue {
        if let catalogue { return catalogue }
        let value = try AccountCatalogue(rootURL: accountStorageRoot())
        catalogue = value
        return value
    }

    private func prepareAccountStorage() throws -> URL {
        let root = try accountStorageRoot()
        let storageLease: AccountStorageLease
        if let existingLease = accountStorageLease {
            storageLease = existingLease
        } else {
            let newLease = try AccountStorageLease(rootURL: root)
            accountStorageLease = newLease
            storageLease = newLease
        }
#if DEBUG
        let allowDevelopmentZeroBuild = Bundle.main.bundleIdentifier?.hasSuffix(".dev") == true
#else
        let allowDevelopmentZeroBuild = false
#endif
        _ = try storageLease.prepareUpgradeGate(
            bundleBuildNumber: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
            allowDevelopmentZeroBuild: allowDevelopmentZeroBuild
        )
        return root
    }

    private func restoreProfiles(recoveryAfterCancelledTermination: Bool = false) async {
        guard !profileRestoreInProgress || recoveryAfterCancelledTermination else { return }
        let restoreGeneration = profileRestoreGenerationGate.begin()
        profileRestoreInProgress = true
        defer {
            if profileRestoreGenerationGate.isCurrent(restoreGeneration) {
                profileRestoreInProgress = false
            }
        }
        do {
            let storageRoot = try prepareAccountStorage()
            let catalogue = try accountCatalogue()
            var profiles = await catalogue.allProfiles()
            guard profileRestoreGenerationGate.isCurrent(restoreGeneration) else { return }
            let cleanupProfiles = profiles.filter { $0.logoutCleanupPending == true }
            for profile in cleanupProfiles {
                guard let expectedTelegramUserID = profile.telegramUserID else {
                    profileStartupFailures.insert(profile.id)
                    continue
                }
                do {
                    try await completePendingLogoutCleanup(
                        profile.id,
                        expectedTelegramUserID: expectedTelegramUserID
                    )
                } catch {
                    profileStartupFailures.insert(profile.id)
                }
                guard profileRestoreGenerationGate.isCurrent(restoreGeneration) else { return }
            }
            profiles = await catalogue.allProfiles()
            guard profileRestoreGenerationGate.isCurrent(restoreGeneration) else { return }
            rememberProfiles(profiles)
            refreshAccountPicker()
            let apiHash = try await SecretsStore.performKeychainRead {
                try SecretsStore().telegramAPIHash()
            }
            guard profileRestoreGenerationGate.isCurrent(restoreGeneration) else { return }
            let authorized = profiles.filter { $0.telegramUserID != nil && $0.logoutCleanupPending != true }
            let pending = profiles.filter { $0.telegramUserID == nil }.sorted { $0.createdAt < $1.createdAt }
            var pendingWithStoredDatabase = Set<AccountUUID>()
            pendingProfileStorageWarnings = 0
            for profile in pending {
                let databaseURL = storageRoot
                    .appendingPathComponent(profile.id.id.uuidString.lowercased(), isDirectory: true)
                    .appendingPathComponent("database", isDirectory: true)
                var isDirectory = ObjCBool(false)
                guard FileManager.default.fileExists(atPath: databaseURL.path, isDirectory: &isDirectory) else { continue }
                guard isDirectory.boolValue else {
                    pendingProfileStorageWarnings += 1
                    continue
                }
                do {
                    if try !FileManager.default.contentsOfDirectory(atPath: databaseURL.path).isEmpty {
                        pendingWithStoredDatabase.insert(profile.id)
                    }
                } catch {
                    // Do not replace or reset data we could not inspect.
                    pendingProfileStorageWarnings += 1
                }
            }
            let candidates = AccountRestorePlanner.profilesToRestore(
                authorized: authorized,
                pending: pending,
                pendingWithStoredDatabase: pendingWithStoredDatabase
            )
            let toRestore = candidates.filter {
                runtimesByAccount[$0.id] == nil && profileStartupTasks[$0.id] == nil
            }
            if toRestore.isEmpty {
                if profiles.isEmpty {
                    pendingAuthorizationType = "authorizationStateWaitPhoneNumber"
                    showPhoneEntry()
                    setStatus("Введите номер и нажмите «Продолжить», чтобы начать вход.")
                } else if profiles.contains(where: { $0.logoutCleanupPending == true }) {
                    setStatus("Очистка после подтверждённого выхода ожидает. Выберите этот профиль, чтобы безопасно продолжить.")
                }
                refreshOutgoingPhotoRecoveryStatus()
                refreshStatusMenu()
                return
            }
            setStatus(authorized.isEmpty ? "Подключаю вход…" : "Восстанавливаю аккаунты…")
            // Start every authorized profile through the bounded scheduler.
            // openProfile releases its permit after the first TDLib request,
            // before any phone/code/2FA network wait can begin.
            for profile in toRestore {
                _ = scheduleProfileStartup(profile, apiHash: apiHash)
            }
            refreshAccountPicker()
            refreshOutgoingPhotoRecoveryStatus()
            if authorized.isEmpty {
                setStatus(phoneCountries.isEmpty
                    ? "Введите полный номер с + и кодом страны. Список стран загружается."
                    : "Выберите страну и введите номер телефона.")
            }
        } catch let error as AccountStorageLeaseError {
            guard profileRestoreGenerationGate.isCurrent(restoreGeneration) else { return }
            profileStartupFailures.formUnion(profileOrder)
            refreshAccountPicker()
            setStatus(error.localizedDescription)
        } catch let error as AccountStorageUpgradeError {
            guard profileRestoreGenerationGate.isCurrent(restoreGeneration) else { return }
            profileStartupFailures.formUnion(profileOrder)
            refreshAccountPicker()
            setStatus(error.localizedDescription)
        } catch SecretsStoreError.missing {
            guard profileRestoreGenerationGate.isCurrent(restoreGeneration) else { return }
            profileStartupFailures.formUnion(profileOrder)
            refreshAccountPicker()
                setStatus("API hash приложения не задан. Откройте меню Neridian → «Настроить или заменить API hash приложения…». Вход не начат; данные других Telegram-приложений не читались.")
        } catch {
            guard profileRestoreGenerationGate.isCurrent(restoreGeneration) else { return }
            profileStartupFailures.formUnion(profileOrder)
            refreshAccountPicker()
            setStatus("Каталог профилей не удалось безопасно открыть. Данные не сброшены.")
        }
    }

    private func stopReceiverAndReplyWhenExited(_ gateway: TDLibGateway) {
        guard terminationBarrier.beginReceiverDrain() else { return }
        if let pipeline = updatePipeline {
            pipeline.requestInputStop()
        } else {
            gateway.requestWorkerStop()
        }
        Task { @MainActor [weak self, gateway] in
            var polls = 0
            while !gateway.receiveWorkerHasExited {
                try? await Task.sleep(for: .milliseconds(20))
                polls += 1
                if polls == 250 {
                    self?.setStatus("TDLib закрыл аккаунты; ожидаю завершения receive worker…")
                }
            }
            guard let self else { return }
            let pipeline = self.updatePipeline
            await Task.detached {
                pipeline?.finishInputAndDrain()
            }.value
            guard self.terminationBarrier.finishReceiverDrain() else { return }
            self.setStatus("Все runtime закрыты; подтверждаю выход macOS…")
            self.shutdownProgressTask?.cancel()
            self.shutdownProgressTask = nil
            self.terminationReply?(true)
        }
    }

    private func scheduleProfileRecoveryAfterAbortedTermination() {
        guard resumeProfilesAfterAbortedTermination, pendingClosures.isEmpty else { return }
        resumeProfilesAfterAbortedTermination = false
        profileRestoreInProgress = true
        Task { @MainActor [weak self] in
            await self?.restoreProfiles(recoveryAfterCancelledTermination: true)
        }
    }

    private func cancelPendingProfileStartsForTermination() -> Bool {
        let tasks = profileStartupTasks.values.map { $0.task }
        profileStartupTasks.removeAll()
        tasks.forEach { $0.cancel() }
        return !tasks.isEmpty
    }

    private func addAccountProfile() async {
        do {
            guard !closingForTermination else { return }
            _ = try prepareAccountStorage()
            let apiHash = try await SecretsStore.performKeychainRead {
                try SecretsStore().telegramAPIHash()
            }
            let catalogue = try accountCatalogue()
            let profile = try await catalogue.addProfile()
            knownProfilesByAccount[profile.id] = profile
            if !profileOrder.contains(profile.id) { profileOrder.append(profile.id) }
            profileStartupFailures.remove(profile.id)
            refreshAccountPicker(select: profile.id)
            if let startup = scheduleProfileStartup(profile, apiHash: apiHash, select: true) {
                await startup.value
            }
            refreshAccountPicker(select: profile.id)
        } catch SecretsStoreError.missing {
                setStatus("API hash приложения не задан. Откройте меню Neridian → «Настроить или заменить API hash приложения…». Новый аккаунт не добавлен; данные других Telegram-приложений не читались.")
        } catch let error as AccountStorageLeaseError {
            setStatus(error.localizedDescription)
        } catch let error as AccountStorageUpgradeError {
            setStatus(error.localizedDescription)
        } catch {
            setStatus("Не удалось создать профиль. Проверьте хранилище и Keychain.")
        }
    }

    @discardableResult
    private func scheduleProfileStartup(
        _ profile: AccountProfile,
        apiHash: String,
        select: Bool = false
    ) -> Task<Void, Never>? {
        guard !closingForTermination, runtimesByAccount[profile.id] == nil else { return nil }
        if let pending = profileStartupTasks[profile.id] { return pending.task }
        let taskID = UUID()
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if self.profileStartupTasks[profile.id]?.id == taskID {
                    self.profileStartupTasks.removeValue(forKey: profile.id)
                    self.refreshAccountPicker(select: self.runtime?.account == profile.id ? profile.id : nil)
                    self.refreshStatusMenu()
                }
            }
            await self.openProfile(profile, apiHash: apiHash, select: select)
        }
        profileStartupTasks[profile.id] = (taskID, task)
        refreshAccountPicker(select: runtime?.account == profile.id ? profile.id : nil)
        return task
    }

    private func openProfile(_ profile: AccountProfile, apiHash: String, select: Bool = false) async {
        guard !Task.isCancelled, !closingForTermination,
              runtimesByAccount[profile.id] == nil else { return }
        await startupScheduler.withPermit { [weak self] in
            guard let self, !Task.isCancelled else { return }
            await self.openProfileWhileHoldingStartupPermit(profile, apiHash: apiHash, select: select)
        }
    }

    private func openProfileWhileHoldingStartupPermit(_ profile: AccountProfile, apiHash: String, select: Bool) async {
        guard !Task.isCancelled, !closingForTermination,
              runtimesByAccount[profile.id] == nil else { return }
        var startupRuntime: LocalAccountRuntime?
        var didRegisterStartupRoute = false
        do {
            guard let library = tdjsonLibraryURL() else { throw TDLibGatewayError.libraryLoad("Pinned TDLib not found") }
            if gateway == nil { gateway = try TDLibGateway(libraryURL: library) }
            guard let gateway, let catalogue else { throw TDLibGatewayError.clientCreation }
            let root = try accountStorageRoot()
            let prepared = try await SecretsStore.performKeychainRead { () throws -> (AccountStoragePaths, Data, Data) in
                let paths = try AccountStoragePaths(rootURL: root, account: profile.id)
                let hasDatabaseFiles = try !FileManager.default.contentsOfDirectory(atPath: paths.database.path).isEmpty
                let secrets = SecretsStore()
                let databaseKey = try secrets.databaseKey(for: profile.id, createIfMissing: !hasDatabaseFiles)
                let draftsURL = paths.appState.appendingPathComponent("drafts.aesgcm")
                let appStateKey = try secrets.appStateKey(
                    for: profile.id,
                    createIfMissing: !FileManager.default.fileExists(atPath: draftsURL.path)
                )
                return (paths, databaseKey, appStateKey)
            }
            guard !Task.isCancelled, !closingForTermination else { return }
            do {
                let draftStore = try EncryptedDraftStore(account: profile.id, stateDirectory: prepared.0.appState, key: prepared.2)
                draftStoresByAccount[profile.id] = draftStore
                for (conversation, text) in try draftStore.load() { draftsByConversation[conversation] = text }
                unavailableDraftAccounts.remove(profile.id)
            } catch {
                // Keep unreadable ciphertext intact and refuse edits that could overwrite it.
                unavailableDraftAccounts.insert(profile.id)
                setStatus("Черновики этого аккаунта не открыты; сохранённые данные не изменены.")
            }
            let outgoingPhotoStore = OutgoingPhotoManifestStore(
                stateDirectory: prepared.0.appState,
                accountFilesDirectory: prepared.0.files
            )
            outgoingPhotoManifestStoresByAccount[profile.id] = outgoingPhotoStore
            do {
                pendingStagedPhotoPaths[profile.id] = try outgoingPhotoStore.load()
                unavailableOutgoingPhotoManifestAccounts.remove(profile.id)
            } catch {
                // Preserve the manifest and staged files; refuse new staged sends
                // until the user can recover the account storage safely.
                pendingStagedPhotoPaths[profile.id] = []
                unavailableOutgoingPhotoManifestAccounts.insert(profile.id)
                setStatus("Не удалось прочитать очередь фотографий аккаунта. Данные отправки сохранены.")
            }
            let generation = await runtimeCoordinator.nextGeneration(for: profile.id)
            guard !Task.isCancelled, !closingForTermination else { return }
            let runtime = LocalAccountRuntime(account: profile.id, paths: prepared.0, databaseKey: prepared.1, apiHash: apiHash, gateway: gateway, catalogue: catalogue, generation: generation)
            startupRuntime = runtime
            let route = try runtime.registerRoute()
            try await runtimeCoordinator.registerBeforeFirstRequest(route)
            didRegisterStartupRoute = true
            guard !Task.isCancelled, !closingForTermination else {
                _ = await runtimeCoordinator.removeRouteAfterInitializationRequestRejected(route)
                return
            }
            runtimesByClient[route.client.value] = runtime
            runtimesByAccount[profile.id] = runtime
            refreshStatusMenu()
            let presentsThisRuntime = select || self.runtime == nil
            if presentsThisRuntime { self.runtime = runtime }
            if updatePipeline == nil {
                let pipeline = TDLibUpdatePipeline(gateway: gateway, coordinator: runtimeCoordinator)
                updatePipeline = pipeline
                pipeline.start(
                    onEvent: { [weak self] event in
                        // Each client has an ordered async delivery lane. Awaiting
                        // MainActor here preserves that client's order without
                        // holding the shared TDLib reducer behind another account.
                        switch event {
                        case .routed(let update):
                            let document = try? await TDLibJSONDocument.decodeOffMainActor(update.json)
                            await self?.receive(event, decodedDocument: document)
                        case .routingFailure:
                            await self?.receive(event)
                        }
                    },
                    onReceiveFailure: { [weak self] _ in
                        await self?.handleTDLibReceiveFailure()
                    }
                )
            }
            await runtimeCoordinator.setState(.waitingForAuthorization, for: profile.id)
            guard !Task.isCancelled, !closingForTermination else { return }
            try runtime.send(parametersRequest(for: runtime))
            try runtime.applyNetworkType(currentTDLibNetworkType)
            if presentsThisRuntime { try runtime.send(["@type": "getCountries"]) }
            profileStartupFailures.remove(profile.id)
        } catch {
            if didRegisterStartupRoute, let startupRuntime {
                if !startupRuntime.initializationRequestWasQueued, let route = startupRuntime.route {
                    let removed = await runtimeCoordinator.removeRouteAfterInitializationRequestRejected(route)
                    if removed {
                        if runtimesByClient[route.client.value] === startupRuntime {
                            runtimesByClient.removeValue(forKey: route.client.value)
                        }
                        if runtimesByAccount[profile.id] === startupRuntime {
                            runtimesByAccount.removeValue(forKey: profile.id)
                        }
                        if self.runtime === startupRuntime {
                            self.runtime = runtimesByAccount.values.first
                            pendingAuthorizationType = nil
                            pendingInitialAuthorizationAction = nil
                            authRequestInFlight = false
                            emailField.stringValue = ""
                            inputField.stringValue = ""
                            secureInputField.stringValue = ""
                        }
                        setStatus("TDLib не принял первый запрос. Незапущенный route снят; профиль и данные сохранены. Повторный вход не начат автоматически.")
                    } else {
                        await runtimeCoordinator.setState(.failed("Profile startup route ownership changed"), for: profile.id)
                        setStatus("Не удалось подтвердить владение стартовым route; профиль не будет открыт повторно до проверки состояния.")
                    }
                } else if startupRuntime.close() {
                    await runtimeCoordinator.setState(.closing, for: profile.id)
                    if self.runtime === startupRuntime {
                        pendingAuthorizationType = nil
                        pendingInitialAuthorizationAction = nil
                        authRequestInFlight = false
                        emailField.stringValue = ""
                        inputField.stringValue = ""
                        secureInputField.stringValue = ""
                    }
                    setStatus("Не удалось завершить запуск профиля; отправлен запрос TDLib close. Освобождение профиля дождётся подтверждения Closed.")
                } else {
                    await runtimeCoordinator.setState(.failed("Profile startup failed; TDLib close was not accepted"), for: profile.id)
                    setStatus("Не удалось завершить запуск и TDLib не принял close. Профиль останется занятым до подтверждённого закрытия; база не будет открыта повторно.")
                }
            } else {
                await runtimeCoordinator.setState(.failed("Profile startup failed before TDLib initialization"), for: profile.id)
                setStatus("Не удалось подготовить профиль до запуска TDLib. Сохранённые данные не удалены.")
            }
            profileStartupFailures.insert(profile.id)
            refreshAccountPicker(select: profile.id)
            refreshStatusMenu()
        }
    }

    private func receive(_ event: TDLibPipelineEvent, decodedDocument: TDLibJSONDocument? = nil) async {
        switch event {
        case .routingFailure(let error):
            setStatus("TDLib update не маршрутизирован (\(error)); fallback на выбранный профиль запрещён.")
        case .routed(let update):
            guard let target = runtimesByClient[update.route.client.value], target.route == update.route else {
                setStatus("TDLib update пришёл от неизвестного профиля; fallback на выбранный аккаунт запрещён.")
                return
            }
            guard let object = decodedDocument?.object else {
                setStatus("TDLib update после маршрутизации оказался некорректным JSON; профиль не переназначен.")
                return
            }
            let previousAuthorizationState = target.authorizationState
            let previousTelegramUserID = target.telegramUserID
            let previousDisplayName = target.displayName
            let previousError = target.lastTDLibError
            let previousIdentityPersistenceFailure = target.identityPersistenceFailed
            await target.consume(object)
            if let verifiedUserID = target.telegramUserID,
               var profile = knownProfilesByAccount[target.account],
               profile.telegramUserID != verifiedUserID || profile.displayName != target.displayName {
                profile.associateVerifiedIdentity(verifiedUserID, displayName: target.displayName)
                knownProfilesByAccount[target.account] = profile
            }
            if previousAuthorizationState != target.authorizationState
                || previousTelegramUserID != target.telegramUserID
                || previousDisplayName != target.displayName
                || previousError != target.lastTDLibError
                || previousIdentityPersistenceFailure != target.identityPersistenceFailed {
                refreshAccountPicker(select: target === runtime ? target.account : nil)
            }
            if target.takeLogoutFailureNotice() {
                if let client = target.route?.client.value { pendingClosures.remove(client) }
                setStatus("Telegram не подтвердил выход. Локальный профиль и данные сохранены; проверьте сеть и повторите позже.")
                refreshAccountPicker()
                refreshStatusMenu()
            }
            if let authorizationState = target.authorizationState, let route = target.route {
                let accepted = await runtimeCoordinator.applyAuthorizationState(
                    authorizationState,
                    telegramUserID: target.telegramUserID,
                    from: route
                )
                guard accepted else {
                    setStatus("TDLib update пришёл от устаревшего поколения профиля и не изменил его состояние.")
                    return
                }
            }
            if target === runtime, target.takeIdentityPersistenceFailureNotice() {
                if target.identityMismatchDetected {
                    setStatus("Этот профиль связан с другой Telegram identity. Старые данные не переназначены; для новой учётной записи создайте отдельный профиль.")
                } else {
                    setStatus("Аккаунт вошёл, но его серверная identity не сохранена. Повторный запуск не сможет восстановить этот профиль автоматически.")
                }
            }
            if target.takeIdentityReadyTransition() {
                configureNotifications(for: target)
                if target === runtime {
                    target.loadMainChats()
                    setStatus("Аккаунт авторизован.")
                }
            }
            await handle(object, from: target)
            refreshStatusMenu()
        }
    }

    private func handleTDLibReceiveFailure() {
        tdlibReceiveFailed = true
        refreshComposerState()
        setStatus("TDLib остановил приём обновлений после ошибки копирования события. Отправка приостановлена; перезапустите \(ProductIdentity.displayName) после освобождения памяти.")
    }

    private func handle(_ object: [String: Any], from target: LocalAccountRuntime) async {
        let updateType = object["@type"] as? String ?? ""
        if let extra = object["@extra"] as? String, extra.hasPrefix("message-view-") {
            guard updateType == "ok" || updateType == "error" else { return }
            _ = visibleReadReceiptRegistry.resolve(
                extra: extra,
                account: target.account,
                runtimeGeneration: target.generation,
                succeeded: updateType == "ok"
            )
            return
        }
        if target.telegramUserID == nil,
           !["updateAuthorizationState", "countries", "error"].contains(updateType) {
            return
        }
        if let extra = object["@extra"] as? String,
           let refresh = pendingRetryRefreshByExtra.removeValue(forKey: extra) {
            let key = refresh.key
            guard target.account == key.conversation.account,
                  target.generation == refresh.runtimeGeneration else { return }
            let mayPresentRetryRefresh = !lockState
                && refresh.privacyEpoch == privacyDispatchBarrier.currentEpoch()
                && target === runtime
            if updateType == "message", let message = object["message"] as? [String: Any] {
                if mayPresentRetryRefresh {
                    updateCachedMessage(message, for: target.account)
                }
                let state = message["sending_state"] as? [String: Any]
                let retryAfter = (state?["retry_after"] as? NSNumber)?.doubleValue ?? 0
                if mayPresentRetryRefresh {
                    setStatus(retryAfter > 0
                        ? "TDLib обновила ожидание повтора; повтор станет доступен позже."
                        : "TDLib обновила состояние сообщения. Повторите действие, если сообщение всё ещё не отправлено.")
                }
            } else if mayPresentRetryRefresh {
                setStatus("Не удалось обновить состояние неотправленного сообщения; ничего не отправлено.")
            }
            return
        }
        if let extra = object["@extra"] as? String,
           let retry = pendingRetryByExtra.removeValue(forKey: extra) {
            let key = retry.key
            guard target.account == key.account,
                  target.generation == key.generation else { return }
            let mayPresentRetryResponse = !lockState
                && retry.privacyEpoch == privacyDispatchBarrier.currentEpoch()
                && target === runtime
            retryingSendKeys.remove(key)
            if updateType == "error" {
                if let pending = pendingSendLifecycle.resolve(.failed(canRetry: true), for: key, bufferIfUnregistered: false) {
                    retryableFailedSends[MessageKey(
                        conversation: pending.intent.conversation,
                        messageID: key.temporaryMessageID
                    )] = pending
                }
                if mayPresentRetryResponse {
                    setStatus("TDLib не приняла повтор. Черновик и исходное сообщение сохранены.")
                }
                return
            }
            if updateType == "messages",
               let values = object["messages"] as? [Any],
               values.isEmpty || values.first is NSNull {
                if let pending = pendingSendLifecycle.resolve(.failed(canRetry: true), for: key, bufferIfUnregistered: false) {
                    retryableFailedSends[MessageKey(
                        conversation: pending.intent.conversation,
                        messageID: key.temporaryMessageID
                    )] = pending
                }
                if mayPresentRetryResponse {
                    setStatus("TDLib отказала в повторной отправке. Черновик сохранён.")
                }
            } else if updateType == "messages",
                      let values = object["messages"] as? [[String: Any]],
                      let resentMessage = values.first,
                      let newMessageID = (resentMessage["id"] as? NSNumber)?.int64Value {
                let pending = pendingSendLifecycle.take(for: key)
                let nextKey = SendMessageKey(
                    account: key.account,
                    generation: key.generation,
                    chatID: key.chatID,
                    temporaryMessageID: newMessageID
                )
                if let pending {
                    if let sendingState = resentMessage["sending_state"] as? [String: Any] {
                        let earlyOutcome = pendingSendLifecycle.register(pending, for: nextKey)
                        if let earlyOutcome {
                            if case .failed(canRetry: true) = earlyOutcome {
                                retryableFailedSends[MessageKey(
                                    conversation: pending.intent.conversation,
                                    messageID: newMessageID
                                )] = pending
                            }
                            if earlyOutcome == .deleted {
                                finishDeletedOutgoingPhotoIfSafe(pending, account: target.account)
                            }
                            applySendOutcome(earlyOutcome, pending: pending, target: target, mayPresent: mayPresentRetryResponse)
                        } else if sendingState["@type"] as? String == "messageSendingStateFailed" {
                            let canRetry = sendingState["can_retry"] as? Bool == true
                            if canRetry {
                                retryableFailedSends[MessageKey(
                                    conversation: pending.intent.conversation,
                                    messageID: newMessageID
                                )] = pending
                            }
                            if let correlated = pendingSendLifecycle.resolve(
                                .failed(canRetry: canRetry),
                                for: nextKey,
                                bufferIfUnregistered: false
                            ) {
                                applySendOutcome(.failed(canRetry: canRetry), pending: correlated, target: target, mayPresent: mayPresentRetryResponse)
                            }
                        } else if mayPresentRetryResponse {
                            setStatus("Повтор передан TDLib; ожидаю окончательный результат отправки.")
                        }
                    } else {
                        retryableFailedSends.removeValue(forKey: MessageKey(
                            conversation: pending.intent.conversation,
                            messageID: key.temporaryMessageID
                        ))
                        applySendOutcome(.succeeded, pending: pending, target: target, mayPresent: mayPresentRetryResponse)
                    }
                }
                if !lockState, retry.privacyEpoch == privacyDispatchBarrier.currentEpoch() {
                    updateCachedMessage(resentMessage, for: target.account, replacingMessageID: key.temporaryMessageID)
                }
            } else if mayPresentRetryResponse {
                setStatus("TDLib ответила на повтор без нового сообщения ID. Исходная попытка сохранена для сверки.")
            }
            return
        }
        if let extra = object["@extra"] as? String,
           extra.hasPrefix("search-") {
            guard let pending = pendingSearchRequests.take(for: extra) else { return }
            guard pending.acceptsResponse(
                from: target.account,
                runtimeGeneration: target.generation,
                searchGeneration: searchGeneration,
                isLocked: lockState
            ) else {
                startDeferredSearchIfReady()
                return
            }
            switch object["@type"] as? String {
            case "chats":
                let chatIDs = (object["chat_ids"] as? [NSNumber] ?? []).map(\.int64Value)
                for chatID in chatIDs.prefix(10) {
                    let title = chatRowsByAccount[pending.account]?[chatID]?.title ?? "Чат \(chatID)"
                    searchResults.append(AccountSearchResult(
                        account: pending.account,
                        conversation: ConversationKey(account: pending.account, chatID: chatID),
                        messageID: nil,
                        title: title,
                        excerpt: "Переписка"
                    ))
                }
            case "foundMessages":
                let messages = object["messages"] as? [[String: Any]] ?? []
                for message in messages.prefix(10) {
                    guard let chatID = (message["chat_id"] as? NSNumber)?.int64Value,
                          let messageID = (message["id"] as? NSNumber)?.int64Value else { continue }
                    let conversation = conversationKey(for: message, account: pending.account, chatID: chatID)
                    let title = chatRowsByAccount[pending.account]?[chatID]?.title ?? "Чат \(chatID)"
                    searchResults.append(AccountSearchResult(
                        account: pending.account,
                        conversation: conversation,
                        messageID: messageID,
                        title: title,
                        excerpt: messagePreview(message)
                    ))
                }
            default:
                break // Search errors must not replace the auth/chat status.
            }
            refreshChatList()
            startDeferredSearchIfReady()
            return
        }
        if object["@type"] as? String == "messageProperties",
           let extra = object["@extra"] as? String,
           let context = pendingMessagePropertiesByExtra.removeValue(forKey: extra) {
            guard !lockState,
                  privacyDispatchBarrier.currentEpoch() == context.privacyEpoch,
                  let selected = runtimesByAccount[context.key.conversation.account],
                  selected === target, selected.generation == context.runtimeGeneration,
                  selected.telegramUserID == context.expectedTelegramUserID,
                  currentConversationKey() == context.key.conversation else { return }
            showMessageActionMenu(context, permissions: MessageActionPermissions(tdlibObject: object))
            return
        }
        if object["@type"] as? String == "message",
           let extra = object["@extra"] as? String,
           let mutation = pendingMessageMutationsByExtra.removeValue(forKey: extra) {
            messageEditDrafts.removeValue(forKey: mutation.context.key)
            if mutation.kind.isDelete {
                if !lockState, runtimesByAccount[mutation.context.key.conversation.account] === target {
                    setStatus("Запрос удаления принят TDLib; синхронизирую переписку…")
                }
            } else {
                updateCachedMessage(object, for: mutation.context.key.conversation.account)
                if !lockState, currentConversationKey() == mutation.context.key.conversation {
                    setStatus("Изменение сообщения принято TDLib.")
                }
            }
            return
        }
        if object["@type"] as? String == "ok",
           let extra = object["@extra"] as? String,
           let mutation = pendingMessageMutationsByExtra.removeValue(forKey: extra) {
            messageEditDrafts.removeValue(forKey: mutation.context.key)
            if !lockState, mutation.kind.isDelete {
                setStatus("Запрос удаления принят TDLib; синхронизирую переписку…")
            }
            return
        }
        if let type = object["@type"] as? String, type == "updateAuthorizationState",
           let auth = object["authorization_state"] as? [String: Any],
           let authType = auth["@type"] as? String {
            if target === runtime {
                pendingAuthorizationType = authType
                authRequestInFlight = false
            }
            if lockState {
                if let terms = (auth["terms_of_service"] as? [String: Any]) {
                    authPresentationInfoByAccount[target.account] = ["terms_of_service": terms]
                } else {
                    authPresentationInfoByAccount.removeValue(forKey: target.account)
                }
            } else {
                authPresentationInfoByAccount[target.account] = authPresentationInfo(for: auth)
            }
            pendingAuthRequestsByExtra = pendingAuthRequestsByExtra.filter { $0.value.account != target.account }
            if authType == "authorizationStateClosed" {
                let client = target.route?.client.value
                let wasSelected = target === runtime
                let confirmedLogout = target.logoutWasAccepted
                let loggedOutUserID = target.telegramUserID
                var removedLogoutProfile = false
                if !confirmedLogout && !closingForTermination {
                    // Background profiles need the same honest failure status
                    // as the selected profile; keep the verified identity and
                    // let the user reopen that exact local profile explicitly.
                    profileStartupFailures.insert(target.account)
                }
                if confirmedLogout, let client { pendingClosures.insert(client) }
                target.finishClose()
                runtimesByAccount.removeValue(forKey: target.account)
                visibleReadReceiptRegistry.remove(account: target.account)
                if !confirmedLogout {
                    // A closed runtime cannot reconcile its old notification
                    // set. Remove its previews and click routes immediately;
                    // otherwise stale message text can remain in Notification Center.
                    let notificationIDs = AccountNotificationCleanup.remove(
                        account: target.account,
                        identifiersByAccount: &notificationIDsByAccount,
                        targetsByIdentifier: &notificationTargets
                    )
                    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: Array(notificationIDs))
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: Array(notificationIDs))
                }
                authPresentationInfoByAccount.removeValue(forKey: target.account)
                _ = pendingSearchRequests.remove(account: target.account, runtimeGeneration: target.generation)
                _ = pendingHistoryRequests.remove(account: target.account, runtimeGeneration: target.generation)
                historyRequestGenerationByConversation = historyRequestGenerationByConversation.filter { $0.key.account != target.account }
                searchResults.removeAll(for: target.account)
                searchResultByControlID = searchResultByControlID.filter { $0.value.account != target.account }
                startDeferredSearchIfReady()
                // An unexpected close must not silently change the UI to another
                // Telegram identity. A user-requested logout may return to an
                // already-authorized account, as that transition was explicit.
                if wasSelected { runtime = confirmedLogout ? runtimesByAccount.values.first : nil }
                if confirmedLogout, let loggedOutUserID {
                    purgeInMemoryAccountState(target.account)
                    let cleanup = await finishLogoutProfile(target, expectedTelegramUserID: loggedOutUserID)
                    removedLogoutProfile = cleanup
                    setStatus(cleanup
                        ? "Аккаунт вышел из Telegram, локальные данные и профиль удалены."
                        : "Выход в Telegram завершён, но локальная очистка не закончена. Профиль сохранён для безопасного восстановления очистки.")
                } else if target.isLogoutRequested {
                    setStatus("Соединение закрылось до подтверждения выхода Telegram; локальный профиль сохранён.")
                }
                if let client {
                    runtimesByClient.removeValue(forKey: client)
                    if let route = target.route { await runtimeCoordinator.removeRouteAfterClosed(route.client) }
                    pendingClosures.remove(client)
                }
                if wasSelected, confirmedLogout, let next = runtime {
                    refreshAccountPicker(select: next.account)
                    presentRuntime(next)
                } else if wasSelected, !confirmedLogout, !closingForTermination {
                    closedProfileToRetry = target.account
                    profileStartupFailures.insert(target.account)
                    if !lockState { showClosedProfileRecovery(target.account) }
                    refreshAccountPicker()
                } else if wasSelected, confirmedLogout, removedLogoutProfile, runtimesByAccount.isEmpty {
                    Task { @MainActor [weak self] in await self?.addAccountProfile() }
                } else if wasSelected, confirmedLogout, runtimesByAccount.isEmpty {
                    chatPane.isHidden = true
                    setAuthCardVisible(true)
                    loginHeading.stringValue = "Очистка профиля не завершена"
                    loginSubtitle.stringValue = "Telegram подтвердил выход. Локальная запись сохранена из-за ошибки очистки; добавьте другой аккаунт через меню «Аккаунт» после устранения ошибки Keychain или диска."
                    phoneField.isHidden = true
                    inputField.isHidden = true
                    secureInputField.isHidden = true
                    qrImageView.isHidden = true
                    actionButton.isHidden = true
                }
                refreshAccountPicker()
                refreshStatusMenu()
                if closingForTermination && pendingClosures.isEmpty {
                    if let gateway { stopReceiverAndReplyWhenExited(gateway) }
                    else {
                        if terminationBarrier.beginReceiverDrain(), terminationBarrier.finishReceiverDrain() {
                            terminationReply?(true)
                        }
                    }
                } else if !closingForTermination && resumeProfilesAfterAbortedTermination && pendingClosures.isEmpty {
                    scheduleProfileRecoveryAfterAbortedTermination()
                }
                return
            }
            guard target === runtime else { return }
            guard !lockState else { return }
            switch authType {
            case "authorizationStateWaitTdlibParameters":
                // setTdlibParameters is the first request and was already queued
                // before this authorization update reached the UI.
                return
            case "authorizationStateWaitPhoneNumber":
                showingQR = false
                showPhoneEntry()
                if let initialAction = pendingInitialAuthorizationAction {
                    pendingInitialAuthorizationAction = nil
                    switch initialAction {
                    case .phoneNumber(let number):
                        phoneField.stringValue = number
                        primaryAction()
                    case .qrCode:
                        beginQRLogin()
                    }
                }
            case "authorizationStateWaitCode":
                showAuthInput(authCodeDescription(auth), placeholder: "Код", button: "Продолжить")
            case "authorizationStateWaitPassword":
                showAuthInput(passwordPrompt(auth), placeholder: "Пароль двухэтапной проверки", button: "Продолжить")
            case "authorizationStateWaitEmailAddress":
                showEmailEntry()
            case "authorizationStateWaitEmailCode":
                showEmailCode(auth)
            case "authorizationStateWaitRegistration":
                showRegistration(auth)
            case "authorizationStateReady":
                pendingAuthorizationType = nil
                authRequestInFlight = false
                authPresentationInfoByAccount.removeValue(forKey: target.account)
                inputField.isHidden = true
                secureInputField.isHidden = true
                phoneField.isHidden = true
                emailField.isHidden = true
                firstNameField.isHidden = true
                lastNameField.isHidden = true
                registrationConsent.isHidden = true
                registrationTermsScroll.isHidden = true
                phoneField.stringValue = ""
                emailField.stringValue = ""
                inputField.stringValue = ""
                secureInputField.stringValue = ""
                firstNameField.stringValue = ""
                lastNameField.stringValue = ""
                countryPicker.isHidden = true
                qrButton.isHidden = true
                actionButton.isEnabled = false
                setStatus("Проверяю серверную identity профиля…")
            case "authorizationStateWaitOtherDeviceConfirmation":
                showQRConfirmation(auth)
            case "authorizationStateLoggingOut", "authorizationStateClosing":
                pendingAuthorizationType = nil
                presentAuthorizationState(authType, info: auth)
            default:
                presentAuthorizationState(authType, info: auth)
            }
        } else if let type = object["@type"] as? String, type == "countries",
                  let countries = object["countries"] as? [[String: Any]], target === runtime {
            phoneCountries = countries.compactMap(PhoneCountry.init(json:)).filter { !$0.callingCodes.isEmpty }.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            phoneField.placeholderString = phoneCountries.isEmpty ? "+код страны и номер" : "Номер телефона"
            countryPicker.removeAllItems()
            for country in phoneCountries {
                countryPicker.addItem(withTitle: "\(country.flag)  \(country.name)  +\(country.callingCodes[0])")
            }
            let preferredRegion = Locale.current.region?.identifier
            let index = phoneCountries.firstIndex(where: { $0.code == preferredRegion })
                ?? phoneCountries.firstIndex(where: { $0.code == "US" })
                ?? phoneCountries.indices.first
            if let index {
                countryPicker.selectItem(at: index)
                selectedCallingCode = phoneCountries[index].callingCodes[0]
            }
            countryPicker.isHidden = phoneCountries.isEmpty || pendingAuthorizationType != "authorizationStateWaitPhoneNumber"
            if target === runtime && pendingAuthorizationType == "authorizationStateWaitPhoneNumber" {
                statusLabel.stringValue = phoneCountries.isEmpty
                    ? "Введите полный номер с + и кодом страны. Список стран пока недоступен."
                    : "Выберите страну и введите номер телефона."
            }
        } else if let type = object["@type"] as? String, type == "updateNewChat",
                  let chat = object["chat"] as? [String: Any] {
            upsertChat(chat, for: target)
        } else if object["@type"] as? String == "updateActiveNotifications",
                  let groups = object["groups"] as? [[String: Any]] {
            reconcileNotifications(groups, for: target)
        } else if object["@type"] as? String == "updateNotification" {
            updateNotification(object, for: target)
        } else if object["@type"] as? String == "updateNotificationGroup" {
            updateNotificationGroup(object, for: target)
        } else if object["@type"] as? String == "updateDeleteMessages",
                  let chatID = (object["chat_id"] as? NSNumber)?.int64Value,
                  let ids = object["message_ids"] as? [NSNumber] {
            let deletedIDs = Set(ids.map(\.int64Value))
            let deletion = SendMessageDeletionClassification.classify(
                isPermanent: (object["is_permanent"] as? NSNumber)?.boolValue,
                fromCache: (object["from_cache"] as? NSNumber)?.boolValue
            )
            purgeMessagePresentationState(account: target.account, chatID: chatID, messageIDs: deletedIDs)
            let removedNotificationIDs = AccountNotificationCleanup.removeMessages(
                account: target.account,
                chatID: chatID,
                messageIDs: deletedIDs,
                identifiersByAccount: &notificationIDsByAccount,
                targetsByIdentifier: &notificationTargets
            )
            notificationUnlockHandoff.clear(account: target.account, chatID: chatID, messageIDs: deletedIDs)
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: Array(removedNotificationIDs))
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: Array(removedNotificationIDs))
            if deletion == .permanent {
                for messageID in deletedIDs where messageID < 0 {
                    let key = SendMessageKey(account: target.account, generation: target.generation, chatID: chatID, temporaryMessageID: messageID)
                    if !retryingSendKeys.contains(key) {
                        let pending = pendingSendLifecycle.resolve(.deleted, for: key, bufferIfUnregistered: true)
                        if let pending {
                            finishDeletedOutgoingPhotoIfSafe(pending, account: target.account)
                            applySendOutcome(.deleted, pending: pending, target: target)
                        }
                    }
                    retryableFailedSends.removeValue(forKey: MessageKey(
                        conversation: ConversationKey(account: target.account, chatID: chatID),
                        messageID: messageID
                    ))
                }
            }
            messageEditDrafts = messageEditDrafts.filter {
                $0.key.conversation.account != target.account
                    || $0.key.conversation.chatID != chatID
                    || !deletedIDs.contains($0.key.messageID)
            }
            let affected = messagesByConversation.keys.filter { $0.account == target.account && $0.chatID == chatID }
            for conversation in affected {
                let cached = messagesByConversation[conversation] ?? []
                messagesByConversation[conversation] = cached.filter { !deletedIDs.contains(($0["id"] as? NSNumber)?.int64Value ?? 0) }
            }
            if target === runtime, let conversation = currentConversationKey(), conversation.chatID == chatID {
                clearStack(messageList)
                renderMessages(messagesByConversation[conversation] ?? [])
            }
        } else if object["@type"] as? String == "updateMessageContent",
                  let chatID = (object["chat_id"] as? NSNumber)?.int64Value,
                  let messageID = (object["message_id"] as? NSNumber)?.int64Value,
                  let newContent = object["new_content"] as? [String: Any] {
            purgeMessagePresentationState(account: target.account, chatID: chatID, messageIDs: [messageID])
            let removedNotificationIDs = AccountNotificationCleanup.removeMessages(
                account: target.account,
                chatID: chatID,
                messageIDs: [messageID],
                identifiersByAccount: &notificationIDsByAccount,
                targetsByIdentifier: &notificationTargets
            )
            notificationUnlockHandoff.clear(account: target.account, chatID: chatID, messageIDs: [messageID])
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: Array(removedNotificationIDs))
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: Array(removedNotificationIDs))
            let affected = messagesByConversation.keys.filter { $0.account == target.account && $0.chatID == chatID }
            for conversation in affected {
                let cached = messagesByConversation[conversation] ?? []
                messagesByConversation[conversation] = cached.map { message in
                    guard (message["id"] as? NSNumber)?.int64Value == messageID else { return message }
                    var edited = message
                    edited["content"] = newContent
                    return edited
                }
            }
            if target === runtime, let conversation = currentConversationKey(), conversation.chatID == chatID {
                clearStack(messageList)
                renderMessages(messagesByConversation[conversation] ?? [])
            }
        } else if let type = object["@type"] as? String, type == "updateChatLastMessage",
                  let chatID = (object["chat_id"] as? NSNumber)?.int64Value {
            guard !lockState else { return }
            if let message = object["last_message"] as? [String: Any] {
                let rows = chatRowsByAccount[target.account] ?? [:]
                chatRowsByAccount[target.account, default: [:]][chatID] = (rows[chatID]?.title ?? "Чат \(chatID)", messagePreview(message))
            } else if let existing = chatRowsByAccount[target.account]?[chatID] {
                chatRowsByAccount[target.account, default: [:]][chatID] = (existing.title, "Нет новых сообщений")
            }
            if target === runtime { refreshChatList() }
        } else if let type = object["@type"] as? String, type == "updateChatPosition",
                  let chatID = (object["chat_id"] as? NSNumber)?.int64Value,
                  let position = object["position"] as? [String: Any] {
            guard !lockState else { return }
            if (position["list"] as? [String: Any])?["@type"] as? String == "chatListMain",
               let order = (position["order"] as? NSNumber)?.uint64Value {
                chatOrderByAccount[target.account, default: [:]][chatID] = order
            }
            if target === runtime { refreshChatList() }
        } else if let type = object["@type"] as? String, type == "updateNewMessage",
                  let message = object["message"] as? [String: Any],
                  let chatID = (message["chat_id"] as? NSNumber)?.int64Value {
            guard !lockState else { return }
            let conversation = conversationKey(for: message, account: target.account, chatID: chatID)
            if target === runtime, currentConversationKey() == conversation {
                var cached = messagesByConversation[conversation] ?? []
                let messageID = (message["id"] as? NSNumber)?.int64Value
                if let messageID, !cached.contains(where: { ($0["id"] as? NSNumber)?.int64Value == messageID }) {
                    cached.append(message)
                    if cached.count > 50 { cached.removeFirst(cached.count - 50) }
                    messagesByConversation[conversation] = cached
                }
                clearStack(messageList)
                renderMessages(cached)
            }
            if let existing = chatRowsByAccount[target.account]?[chatID] {
                chatRowsByAccount[target.account, default: [:]][chatID] = (existing.title, messagePreview(message))
                if target === runtime { refreshChatList() }
            }
        } else if let type = object["@type"] as? String, type == "chat" {
            upsertChat(object, for: target)
        } else if let type = object["@type"] as? String, type == "message",
                  let extra = object["@extra"] as? String,
                  let pending = pendingSendByExtra.removeValue(forKey: extra) {
            associateOutgoingPhotoUpload(pending: pending, response: object, account: target.account)
            if let chatID = (object["chat_id"] as? NSNumber)?.int64Value,
               let temporaryMessageID = (object["id"] as? NSNumber)?.int64Value {
                let key = SendMessageKey(account: target.account, generation: target.generation, chatID: chatID, temporaryMessageID: temporaryMessageID)
                if let outcome = pendingSendLifecycle.register(pending, for: key) {
                    if case .failed(canRetry: true) = outcome {
                        retryableFailedSends[MessageKey(
                            conversation: pending.intent.conversation,
                            messageID: temporaryMessageID
                        )] = pending
                    }
                    if outcome == .deleted {
                        finishDeletedOutgoingPhotoIfSafe(pending, account: target.account)
                    }
                    applySendOutcome(outcome, pending: pending, target: target)
                } else if !lockState, target === runtime {
                    setStatus("TDLib приняла запрос; ожидаю окончательный результат отправки.")
                    refreshComposerState()
                }
            } else if !lockState, target === runtime {
                setStatus("Запрос передан TDLib, но временный ID не получен. Черновик сохранён; автоматического повтора не будет.")
            }
        } else if object["@type"] as? String == "updateMessageSendSucceeded",
                  let message = object["message"] as? [String: Any],
                  let chatID = (message["chat_id"] as? NSNumber)?.int64Value,
                  let oldMessageID = (object["old_message_id"] as? NSNumber)?.int64Value {
            let key = SendMessageKey(account: target.account, generation: target.generation, chatID: chatID, temporaryMessageID: oldMessageID)
            let pending = pendingSendLifecycle.resolve(.succeeded, for: key, bufferIfUnregistered: oldMessageID < 0)
            if !lockState { updateCachedMessage(message, for: target.account, replacingMessageID: oldMessageID) }
            retryableFailedSends.removeValue(forKey: MessageKey(
                conversation: conversationKey(for: message, account: target.account, chatID: chatID),
                messageID: oldMessageID
            ))
            if let pending { applySendOutcome(.succeeded, pending: pending, target: target) }
        } else if object["@type"] as? String == "updateMessageSendFailed",
                  let message = object["message"] as? [String: Any],
                  let chatID = (message["chat_id"] as? NSNumber)?.int64Value,
                  let oldMessageID = (object["old_message_id"] as? NSNumber)?.int64Value {
            let state = message["sending_state"] as? [String: Any]
            let canRetry = state?["@type"] as? String == "messageSendingStateFailed"
                && state?["can_retry"] as? Bool == true
            let key = SendMessageKey(account: target.account, generation: target.generation, chatID: chatID, temporaryMessageID: oldMessageID)
            let pending = pendingSendLifecycle.resolve(.failed(canRetry: canRetry), for: key, bufferIfUnregistered: oldMessageID < 0)
            if !lockState { updateCachedMessage(message, for: target.account, replacingMessageID: oldMessageID) }
            if let pending {
                if canRetry, let messageID = (message["id"] as? NSNumber)?.int64Value {
                    retryableFailedSends[MessageKey(
                        conversation: conversationKey(for: message, account: target.account, chatID: chatID),
                        messageID: messageID
                    )] = pending
                }
                applySendOutcome(.failed(canRetry: canRetry), pending: pending, target: target)
            }
            else if !lockState, target === runtime {
                setStatus("TDLib сообщила об отказе. Черновик и фото сохранены; повтор не выполняется автоматически.")
            }
        } else if object["@type"] as? String == "sponsoredMessages",
                  let extra = object["@extra"] as? String,
                  let key = pendingSponsoredMessagesByExtra.removeValue(forKey: extra) {
            guard !lockState,
                  let owner = runtimesByAccount[key.account], owner === target,
                  owner.generation == key.generation else { return }
            let cards = (object["messages"] as? [[String: Any]] ?? []).compactMap(SponsoredMessageCard.init(tdlibObject:))
            sponsoredMessagesByKey[key] = cards
            sponsoredMessagesBetweenByKey[key] = (object["messages_between"] as? NSNumber)?.int32Value ?? 0
            sponsoredMessagesFetchedAt[key] = Date()
            if target === runtime, selectedChatByAccount[target.account] == key.chatID,
               currentConversationKey() == currentConversationKey(for: target.account, chatID: key.chatID) {
                let conversation = currentConversationKey(for: target.account, chatID: key.chatID)
                clearStack(messageList)
                renderMessages(messagesByConversation[conversation] ?? [])
            }
        } else if let extra = object["@extra"] as? String,
                  let pending = pendingSponsoredReportsByExtra.removeValue(forKey: extra) {
            guard !lockState,
                  let owner = runtimesByAccount[pending.key.account], owner === target,
                  owner.generation == pending.key.generation,
                  target === runtime,
                  selectedChatByAccount[target.account] == pending.key.chatID else { return }
            switch SponsoredReportResult.type(from: object) {
            case "reportSponsoredResultOptionRequired":
                let options = SponsoredReportResult.options(from: object)
                guard !options.isEmpty else {
                    setStatus("Telegram не вернул варианты жалобы на рекламу.")
                    return
                }
                let picker = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 280, height: 26), pullsDown: false)
                for option in options { picker.addItem(withTitle: option.text) }
                let alert = NSAlert()
                alert.messageText = object["title"] as? String ?? "Пожаловаться на рекламу"
                alert.accessoryView = picker
                alert.addButton(withTitle: "Отправить")
                alert.addButton(withTitle: "Отмена")
                guard alert.runModal() == .alertFirstButtonReturn,
                      options.indices.contains(picker.indexOfSelectedItem) else { return }
                sendSponsoredReport(pending.key, card: pending.card, optionID: options[picker.indexOfSelectedItem].id, target: target)
            case "reportSponsoredResultOk":
                setStatus("Жалоба на рекламное сообщение отправлена.")
            case "reportSponsoredResultAdsHidden":
                sponsoredMessagesByKey.removeAll()
                sponsoredMessagesBetweenByKey.removeAll()
                sponsoredMessagesFetchedAt.removeAll()
                setStatus("Telegram скрыл рекламные сообщения во всех переписках.")
            case "reportSponsoredResultPremiumRequired":
                setStatus("Telegram требует Premium, чтобы скрыть такую рекламу.")
            case "reportSponsoredResultFailed":
                setStatus("Эта реклама уже устарела и не может быть отмечена.")
            default:
                setStatus("Telegram вернул неизвестный результат жалобы на рекламу.")
            }
        } else if let type = object["@type"] as? String, type == "messages",
                  let messages = object["messages"] as? [[String: Any]],
                  let extra = object["@extra"] as? String,
                  let request = pendingHistoryRequests.take(for: extra) {
            let conversation = request.conversation
            guard request.acceptsResponse(
                from: target.account,
                runtimeGeneration: target.generation,
                requestGeneration: historyRequestGenerationByConversation[conversation] ?? 0,
                isLocked: lockState
            ) else { return }
            let ordered = Array(messages.reversed().suffix(50))
            messagesByConversation[conversation] = ordered
            if target === runtime, currentConversationKey() == conversation {
                clearStack(messageList)
                renderMessages(ordered)
            }
        } else if object["@type"] as? String == "forumTopics",
                  let topics = object["topics"] as? [[String: Any]],
                  let extra = object["@extra"] as? String,
                  let chatID = pendingForumTopicsByExtra.removeValue(forKey: extra) {
            guard !lockState else { return }
            let parsed = ForumTopicCatalog.parse(topics)
            forumTopicsByAccount[target.account, default: [:]][chatID] = parsed
            guard target === runtime, selectedChatByAccount[target.account] == chatID else { return }
            guard !parsed.isEmpty else {
                topicPicker.isHidden = true
                setStatus("Список тем форума пуст или пока недоступен; отправка в невыбранную тему заблокирована.")
                refreshComposerState()
                return
            }
            if selectedForumTopicIDsByAccount[target.account]?[chatID] == nil {
                let initial = parsed.first(where: \.isGeneral)?.id ?? parsed.first?.id
                if let initial { selectedForumTopicIDsByAccount[target.account, default: [:]][chatID] = initial }
            }
            refreshForumTopicPicker(for: chatID)
            loadSelectedConversationHistory(in: target, chatID: chatID)
            refreshComposerState()
        } else if object["@type"] as? String == "user",
                  let extra = object["@extra"] as? String,
                  let key = pendingSponsoredBotUsersByExtra.removeValue(forKey: extra) {
            guard !lockState,
                  let owner = runtimesByAccount[key.account], owner === target,
                  owner.generation == key.generation else { return }
            guard (object["type"] as? [String: Any])?["@type"] as? String == "userTypeBot" else {
                sponsoredEligibleChatKeys.remove(key)
                sponsoredBotKeys.remove(key)
                return
            }
            sponsoredEligibleChatKeys.insert(key)
            sponsoredBotKeys.insert(key)
            if target === runtime, selectedChatByAccount[target.account] == key.chatID {
                loadSponsoredMessages(in: target, chatID: key.chatID)
            }
        } else if let type = object["@type"] as? String, type == "user" {
            refreshAccountPicker(select: target === runtime ? target.account : nil)
            if target === runtime {
                showAuthenticatedChatUI()
                setStatus("Аккаунт авторизован. Загружаю список переписок…")
            }
        } else if let type = object["@type"] as? String, type == "error" {
            if let extra = object["@extra"] as? String,
               pendingSponsoredMessagesByExtra.removeValue(forKey: extra) != nil {
                return
            }
            if let extra = object["@extra"] as? String,
               pendingSponsoredBotUsersByExtra.removeValue(forKey: extra) != nil {
                return
            }
            if let extra = object["@extra"] as? String,
               pendingSponsoredReportsByExtra.removeValue(forKey: extra) != nil {
                if target === runtime { setStatus("Не удалось отправить жалобу на рекламу.") }
                return
            }
            if let extra = object["@extra"] as? String,
               let pending = pendingAuthRequestsByExtra.removeValue(forKey: extra) {
                if target === runtime, target.account == pending.account { authRequestInFlight = false }
                guard !lockState, target === runtime, target.account == pending.account else { return }
                actionButton.isEnabled = true
                qrButton.isEnabled = true
                switch pending.step {
                case "authorizationStateWaitPhoneNumber": setStatus("Номер не принят Telegram. Проверьте код страны и номер.")
                case "authorizationStateWaitCode": setStatus("Код не принят. Проверьте последнее сообщение с кодом и попробуйте снова.")
                case "authorizationStateWaitPassword": setStatus("Пароль двухэтапной проверки не принят. Попробуйте снова.")
                case "authorizationStateWaitEmailAddress": setStatus("Адрес почты не принят. Проверьте его и попробуйте снова.")
                case "authorizationStateWaitEmailCode": setStatus("Код из письма не принят. Проверьте последнее письмо и попробуйте снова.")
                case "authorizationStateWaitRegistration": setStatus("Не удалось завершить регистрацию. Проверьте имя и попробуйте снова.")
                default: setStatus("TDLib не принял шаг авторизации. Проверьте данные и попробуйте снова.")
                }
                return
            }
            if let extra = object["@extra"] as? String,
               let context = pendingMessagePropertiesByExtra.removeValue(forKey: extra) {
                if !lockState, target === runtime, currentConversationKey() == context.key.conversation {
                    setStatus("TDLib не вернул разрешения для сообщения; действие недоступно.")
                }
                return
            }
            if let extra = object["@extra"] as? String,
               let mutation = pendingMessageMutationsByExtra.removeValue(forKey: extra) {
                if !lockState, target === runtime, currentConversationKey() == mutation.context.key.conversation {
                    setStatus(mutation.kind == .delete(.forEveryone) || mutation.kind == .delete(.forCurrentUser)
                        ? "TDLib отклонил удаление; сообщение не скрыто локально."
                        : "TDLib отклонил изменение; введённый текст оставлен для повтора.")
                }
                return
            }
            if let extra = object["@extra"] as? String,
               pendingForumTopicsByExtra.removeValue(forKey: extra) != nil {
                if !lockState, target === runtime { setStatus("Не удалось загрузить список тем этого форума.") }
                return
            }
            if let extra = object["@extra"] as? String,
               let request = pendingHistoryRequests.take(for: extra) {
                if request.acceptsResponse(
                    from: target.account,
                    runtimeGeneration: target.generation,
                    requestGeneration: historyRequestGenerationByConversation[request.conversation] ?? 0,
                    isLocked: lockState
                ), target === runtime {
                    setStatus("Не удалось загрузить историю выбранной темы.")
                }
                return
            }
            if let extra = object["@extra"] as? String,
               let key = pendingPhotoByExtra.removeValue(forKey: extra) {
                photoDownloadsByConversation[ConversationKey(account: key.account, chatID: key.chatID)]?.remove(key.fileID)
                if photoOriginalFileIDs[key] == key.fileID, requestedOriginalPhotos.remove(key) != nil,
                   let originalButton = photoButtons[key], !lockState {
                    originalButton.isEnabled = true
                    originalButton.title = "Повторить полный размер"
                    setStatus("Не удалось загрузить фотографию в полном размере.")
                }
                if let button = photoButtons[key], !lockState {
                    button.isEnabled = true
                    button.title = "Повторить загрузку фото"
                }
                return
            }
            if let extra = object["@extra"] as? String,
               let key = pendingSponsoredPhotoByExtra.removeValue(forKey: extra) {
                photoDownloadsByConversation[ConversationKey(account: key.account, chatID: key.chatID)]?.remove(key.fileID)
                requestedSponsoredPhotos.remove(key)
                failedSponsoredPhotos.insert(key)
                if !lockState, target === runtime, selectedChatByAccount[target.account] == key.chatID {
                    setStatus("Не удалось загрузить рекламную фотографию; она не будет показана частично.")
                    let conversation = currentConversationKey(for: target.account, chatID: key.chatID)
                    clearStack(messageList)
                    renderMessages(messagesByConversation[conversation] ?? [])
                }
                return
            }
            if let extra = object["@extra"] as? String,
               let key = pendingOriginalPhotoByExtra.removeValue(forKey: extra) {
                requestedOriginalPhotos.remove(key)
                let fileID = photoOriginalFileIDs[key]
                if let fileID {
                    photoDownloadsByConversation[ConversationKey(account: key.account, chatID: key.chatID)]?.remove(fileID)
                }
                if !lockState, let button = photoButtons[key] {
                    button.isEnabled = true
                    button.title = "Повторить полный размер"
                }
                if !lockState, photoViewerKey == key { setStatus("Не удалось загрузить фотографию в полном размере.") }
                return
            }
            if let extra = object["@extra"] as? String,
               let pending = pendingSendByExtra.removeValue(forKey: extra) {
                for attachment in pending.intent.attachments {
                    releaseStagedOutgoingPhoto(attachment.localFileURL, account: pending.intent.account)
                }
                if !lockState, target === runtime {
                    setStatus("Отправка не принята. Черновик сохранён; проверьте права или тему чата.")
                    refreshComposerState()
                }
                _ = pending
                return
            }
            guard !lockState else { return }
            setStatus("TDLib отклонил запрос (\(object["code"] ?? "?")). Повторите шаг после проверки введённых данных.")
            actionButton.isEnabled = pendingAuthorizationType != nil
        } else if let type = object["@type"] as? String, type == "updateFile",
                  let file = object["file"] as? [String: Any] {
            finishOutgoingPhotoUploadIfReady(file, account: target.account)
            presentDownloadedPhoto(file, from: target)
        } else if object["@type"] as? String == "file" {
            finishOutgoingPhotoUploadIfReady(object, account: target.account)
            presentDownloadedPhoto(object, from: target)
        }
    }

    private func reconcileNotifications(_ groups: [[String: Any]], for target: LocalAccountRuntime) {
        var next = Set<String>()
        var routed: [String: RoutedTDLibNotification] = [:]
        for group in groups {
            guard let groupID = (group["id"] as? NSNumber)?.int32Value,
                  let chatID = (group["chat_id"] as? NSNumber)?.int64Value else { continue }
            for item in group["notifications"] as? [[String: Any]] ?? [] {
                guard let value = TDLibNotificationRouter.route(account: target.account, groupID: groupID, groupChatID: chatID, notification: item) else { continue }
                next.insert(value.systemIdentifier)
                routed[value.systemIdentifier] = value
            }
        }
        let old = notificationIDsByAccount[target.account] ?? []
        let removed = old.subtracting(next)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: Array(removed))
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: Array(removed))
        notificationIDsByAccount[target.account] = next
        notificationTargets = notificationTargets.filter { $0.value.account != target.account }
        notificationTargets.merge(routed) { _, new in new }
    }

    private func configureNotifications(for target: LocalAccountRuntime) {
        // TDLib continues processing each account regardless of the OS
        // permission result; these limits bound only its active notification set.
        try? target.send(["@type": "setOption", "name": "notification_group_count_max", "value": ["@type": "optionValueInteger", "value": 10]])
        try? target.send(["@type": "setOption", "name": "notification_group_size_max", "value": ["@type": "optionValueInteger", "value": 10]])
        guard notificationAuthorizationRequestGate.claimRequest() else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func updateNotificationGroup(_ update: [String: Any], for target: LocalAccountRuntime) {
        guard let groupID = (update["notification_group_id"] as? NSNumber)?.int32Value,
              let chatID = (update["chat_id"] as? NSNumber)?.int64Value else { return }
        var active = notificationIDsByAccount[target.account] ?? []
        let removedIDs = Set((update["removed_notification_ids"] as? [NSNumber] ?? []).map { "netelegram.\(target.account.id.uuidString.lowercased()).\(groupID).\($0.int32Value)" })
        active.subtract(removedIDs)
        for identifier in removedIDs { notificationTargets.removeValue(forKey: identifier) }
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: Array(removedIDs))
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: Array(removedIDs))
        for item in update["added_notifications"] as? [[String: Any]] ?? [] {
            guard let value = TDLibNotificationRouter.route(account: target.account, groupID: groupID, groupChatID: chatID, notification: item) else { continue }
            active.insert(value.systemIdentifier)
            notificationTargets[value.systemIdentifier] = value
            deliverNotification(value, for: target)
        }
        notificationIDsByAccount[target.account] = active
    }

    private func updateNotification(_ update: [String: Any], for target: LocalAccountRuntime) {
        guard let groupID = (update["notification_group_id"] as? NSNumber)?.int32Value,
              let notification = update["notification"] as? [String: Any],
              let notificationID = (notification["id"] as? NSNumber)?.int32Value else { return }
        let identifier = RoutedTDLibNotification.systemIdentifier(
            account: target.account,
            groupID: groupID,
            notificationID: notificationID
        )

        guard let routed = TDLibNotificationRouter.routeUpdate(account: target.account, update: update) else {
            // The content may have changed to an unsupported notification kind
            // (for example a call). Remove any old message preview and route;
            // never leave stale message text visible under the reused ID.
            notificationTargets.removeValue(forKey: identifier)
            var active = notificationIDsByAccount[target.account] ?? []
            active.remove(identifier)
            notificationIDsByAccount[target.account] = active
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
            return
        }

        var active = notificationIDsByAccount[target.account] ?? []
        active.insert(identifier)
        notificationIDsByAccount[target.account] = active
        notificationTargets[identifier] = routed
        // Replacing content is a reconciliation of the same TDLib notification,
        // so refresh its text/route without replaying the notification sound.
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        deliverNotifications([(routed, target)], isReconciliation: true)
    }

    private func deliverNotification(_ value: RoutedTDLibNotification, for target: LocalAccountRuntime) {
        deliverNotifications([(value, target)])
    }

    private func deliverActiveNotifications() {
        let current = notificationTargets.values.compactMap { value -> (RoutedTDLibNotification, LocalAccountRuntime)? in
            guard notificationIDsByAccount[value.account]?.contains(value.systemIdentifier) == true,
                  let target = runtimesByAccount[value.account] else { return nil }
            return (value, target)
        }
        deliverNotifications(current, isReconciliation: true)
    }

    private func deliverNotifications(
        _ values: [(RoutedTDLibNotification, LocalAccountRuntime)],
        isReconciliation: Bool = false
    ) {
        let eligible = values.filter { $0.1.telegramUserID != nil }
        guard !eligible.isEmpty else { return }
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.privacyDispatchBarrier.withState { isLocked, _ in
                    for (value, target) in eligible {
                        guard self.runtimesByAccount[value.account] === target,
                              self.notificationTargets[value.systemIdentifier] == value,
                              self.notificationIDsByAccount[value.account]?.contains(value.systemIdentifier) == true else { continue }
                        let presentation = TDLibNotificationRouter.presentation(
                            for: value,
                            isPrivacyLocked: isLocked,
                            chatTitle: self.chatRowsByAccount[value.account]?[value.conversation.chatID]?.title,
                            isReconciliation: isReconciliation
                        )
                        let content = UNMutableNotificationContent()
                        content.title = presentation.title
                        content.body = presentation.body
                        content.sound = presentation.playsSound ? .default : nil
                        content.userInfo = ["route": value.systemIdentifier]
                        let request = UNNotificationRequest(identifier: value.systemIdentifier, content: content, trigger: nil)
                        // Enqueue under the same barrier used by lock(). This
                        // preserves each route while preventing a late callback
                        // from restoring sensitive text after the lock wins.
                        UNUserNotificationCenter.current().add(request) { _ in }
                    }
                }
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler(lockState ? [] : [.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.notification.request.content.userInfo["route"] as? String
        Task { @MainActor [weak self] in
            defer { completionHandler() }
            guard let self, let identifier, let value = self.notificationTargets[identifier] else { return }
            guard let accountRuntime = self.runtimesByAccount[value.account],
                  let telegramUserID = accountRuntime.telegramUserID,
                  AccountPresentation.restoresAuthenticatedChat(
                    telegramUserID: telegramUserID,
                    authorizationState: accountRuntime.authorizationState
                  ),
                  self.notificationTargets[identifier] == value else { return }
            if self.lockState {
                self.notificationUnlockHandoff.stage(
                    value,
                    runtimeGeneration: accountRuntime.generation,
                    expectedTelegramUserID: telegramUserID
                )
                self.showWindow()
                return
            }
            self.openNotificationRoute(value)
        }
    }

    private func openNotificationRoute(_ value: RoutedTDLibNotification) {
        guard !lockState,
              notificationTargets[value.systemIdentifier] == value,
              let accountRuntime = runtimesByAccount[value.account],
              AccountPresentation.restoresAuthenticatedChat(
                telegramUserID: accountRuntime.telegramUserID,
                authorizationState: accountRuntime.authorizationState
              ) else { return }
        runtime = accountRuntime
        refreshAccountPicker(select: value.account)
        switch value.conversation.topic {
        case .main, .forum:
            selectedConversationTopicsByAccount[value.account]?.removeValue(forKey: value.conversation.chatID)
        default:
            selectedConversationTopicsByAccount[value.account, default: [:]][value.conversation.chatID] = value.conversation.topic
        }
        if case .forum(let topicID) = value.conversation.topic {
            forumChatsByAccount[value.account, default: []].insert(value.conversation.chatID)
            selectedForumTopicIDsByAccount[value.account, default: [:]][value.conversation.chatID] = topicID
        }
        showWindow()
        openChat(chatID: value.conversation.chatID, in: accountRuntime)
    }

    private func upsertChat(_ chat: [String: Any], for target: LocalAccountRuntime) {
        guard !lockState else { return }
        guard let id = (chat["id"] as? NSNumber)?.int64Value else { return }
        let title = (chat["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = chat["last_message"] as? [String: Any]
        chatRowsByAccount[target.account, default: [:]][id] = (title?.isEmpty == false ? title! : "Чат \(id)", last.map(messagePreview) ?? "")
        if let positions = chat["positions"] as? [[String: Any]],
           let main = positions.first(where: { ($0["list"] as? [String: Any])?["@type"] as? String == "chatListMain" }),
           let order = (main["order"] as? NSNumber)?.uint64Value {
            chatOrderByAccount[target.account, default: [:]][id] = order
        }
        let chatType = chat["type"] as? [String: Any]
        let isForum = chatType? ["@type"] as? String == "chatTypeSupergroup"
            && (chatType? ["is_forum"] as? Bool ?? false)
        if isForum {
            forumChatsByAccount[target.account, default: []].insert(id)
        } else {
            forumChatsByAccount[target.account]?.remove(id)
        }
        let isChannel = chatType? ["@type"] as? String == "chatTypeSupergroup"
            && (chatType? ["is_channel"] as? Bool ?? false)
        let sponsoredKey = SponsoredMessagesKey(account: target.account, generation: target.generation, chatID: id)
        if isChannel {
            sponsoredEligibleChatKeys.insert(sponsoredKey)
            sponsoredChannelKeys.insert(sponsoredKey)
            sponsoredBotKeys.remove(sponsoredKey)
            if target === runtime, selectedChatByAccount[target.account] == id {
                loadSponsoredMessages(in: target, chatID: id)
            }
        } else if chatType? ["@type"] as? String == "chatTypePrivate" {
            sponsoredChannelKeys.remove(sponsoredKey)
            if !sponsoredEligibleChatKeys.contains(sponsoredKey),
               !pendingSponsoredBotUsersByExtra.values.contains(sponsoredKey),
               let userID = (chatType?["user_id"] as? NSNumber)?.int64Value,
               target === runtime, selectedChatByAccount[target.account] == id {
                historyRequestCounter &+= 1
                let extra = "sponsored-bot-user-\(historyRequestCounter)"
                pendingSponsoredBotUsersByExtra[extra] = sponsoredKey
                do {
                    try target.send(["@type": "getUser", "user_id": userID, "@extra": extra])
                } catch {
                    pendingSponsoredBotUsersByExtra.removeValue(forKey: extra)
                }
            }
        } else {
            sponsoredEligibleChatKeys.remove(sponsoredKey)
            sponsoredChannelKeys.remove(sponsoredKey)
            sponsoredBotKeys.remove(sponsoredKey)
        }
        let sender = chat["message_sender_id"] as? [String: Any]
        let senderUserID = sender? ["@type"] as? String == "messageSenderUser"
            ? (sender? ["user_id"] as? NSNumber)?.int64Value : nil
        let canSendText = (chat["permissions"] as? [String: Any])?["can_send_basic_messages"] as? Bool ?? false
        sendEligibilityByAccount[target.account, default: [:]][id] = ChatSendPermission(
            canSendBasicMessages: canSendText,
            isChannel: isChannel,
            defaultSenderTelegramUserID: senderUserID
        )
        if target === runtime {
            refreshChatList()
            if selectedChatByAccount[target.account] == id { refreshComposerState() }
        }
    }

    private func loadSponsoredMessages(in target: LocalAccountRuntime, chatID: Int64) {
        let key = SponsoredMessagesKey(account: target.account, generation: target.generation, chatID: chatID)
        guard sponsoredEligibleChatKeys.contains(key),
              SponsoredMessagesPolicy.shouldRequest(lastFetchedAt: sponsoredMessagesFetchedAt[key], now: Date()),
              !pendingSponsoredMessagesByExtra.values.contains(key) else { return }
        historyRequestCounter &+= 1
        let extra = "sponsored-\(historyRequestCounter)"
        pendingSponsoredMessagesByExtra[extra] = key
        do {
            try target.send(SponsoredMessagesPolicy.request(chatID: chatID, extra: extra))
        } catch {
            pendingSponsoredMessagesByExtra.removeValue(forKey: extra)
        }
    }

    private func refreshChatList() {
        guard chatList != nil else { return }
        clearStack(chatList)
        if !activeSearchQuery.isEmpty {
            if searchResults.isEmpty {
                let state = pendingSearchRequests.isEmpty ? "Совпадений пока нет" : "Ищу в подключённых аккаунтах…"
                chatList.addArrangedSubview(NSTextField(wrappingLabelWithString: state))
            }
            for result in searchResults.values.prefix(420) {
                let controlID = "search-result-\(UUID().uuidString)"
                let accountName = runtimesByAccount[result.account].flatMap(safeAccountName) ?? "Аккаунт"
                let button = NSButton(title: "\(result.title)\n\(accountName) · \(result.excerpt)", target: self, action: #selector(openSearchResult(_:)))
                button.identifier = NSUserInterfaceItemIdentifier(controlID)
                button.alignment = .left
                button.isBordered = false
                button.lineBreakMode = .byTruncatingTail
                button.font = .systemFont(ofSize: 12)
                button.frame.size.height = 54
                button.setAccessibilityLabel("Открыть результат: \(result.title). \(accountName). \(result.excerpt)")
                searchResultByControlID[controlID] = result
                chatList.addArrangedSubview(button)
            }
            return
        }
        let account = runtime?.account
        for (id, value) in (runtime.flatMap { chatRowsByAccount[$0.account] } ?? [:]).sorted(by: { lhs, rhs in
            let leftOrder = account.flatMap { chatOrderByAccount[$0]?[lhs.key] } ?? 0
            let rightOrder = account.flatMap { chatOrderByAccount[$0]?[rhs.key] } ?? 0
            return leftOrder == rightOrder ? lhs.key > rhs.key : leftOrder > rightOrder
        }) {
            let button = NSButton(title: "\(value.title)\n\(value.lastText)", target: self, action: #selector(openChatFromButton(_:)))
            button.identifier = NSUserInterfaceItemIdentifier(String(id))
            button.alignment = .left
            button.isBordered = false
            button.lineBreakMode = .byTruncatingTail
            button.font = .systemFont(ofSize: 13)
            button.frame.size.height = 52
            button.setAccessibilityLabel("Открыть переписку: \(value.title). Последнее сообщение: \(value.lastText)")
            chatList.addArrangedSubview(button)
        }
    }

    @objc private func searchFieldChanged() {
        searchDebounceTask?.cancel()
        searchGeneration &+= 1
        let generation = searchGeneration
        activeSearchQuery = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        searchResults.removeAll()
        searchResultByControlID.removeAll()
        refreshChatList()
        guard !lockState, !activeSearchQuery.isEmpty else { return }
        let query = activeSearchQuery
        searchDebounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard let self, !Task.isCancelled, generation == self.searchGeneration,
                  query == self.activeSearchQuery, !self.lockState else { return }
            self.startSearch(query, generation: generation)
        }
    }

    private func startSearch(_ query: String, generation: UInt64) {
        guard pendingSearchRequests.isEmpty else {
            deferredSearch = DeferredSearch(query: query, generation: generation)
            return
        }
        deferredSearch = nil
        let accounts = runtimesByAccount.values
            .filter { $0.telegramUserID != nil && $0.authorizationState == "authorizationStateReady" }
            .sorted { $0.account.id.uuidString < $1.account.id.uuidString }
        for accountRuntime in accounts {
            if safeAccountName(accountRuntime)?.localizedCaseInsensitiveContains(query) == true {
                searchResults.append(AccountSearchResult(
                    account: accountRuntime.account,
                    conversation: nil,
                    messageID: nil,
                    title: safeAccountName(accountRuntime) ?? "Аккаунт",
                    excerpt: "Аккаунт"
                ))
            }
            historyRequestCounter &+= 1
            let chatsExtra = "search-chats-\(generation)-\(historyRequestCounter)"
            let searchContext = AccountSearchRequestContext(
                account: accountRuntime.account,
                runtimeGeneration: accountRuntime.generation,
                searchGeneration: generation
            )
            pendingSearchRequests.register(searchContext, for: chatsExtra)
            do {
                try accountRuntime.send(["@type": "searchChats", "query": query, "type_filter": NSNull(), "limit": 10, "@extra": chatsExtra])
            } catch {
                _ = pendingSearchRequests.take(for: chatsExtra)
            }
            historyRequestCounter &+= 1
            let messagesExtra = "search-messages-\(generation)-\(historyRequestCounter)"
            pendingSearchRequests.register(searchContext, for: messagesExtra)
            do {
                try accountRuntime.send([
                    "@type": "searchMessages", "chat_list": NSNull(), "query": query,
                    "offset": "", "limit": 10,
                    "filter": ["@type": "searchMessagesFilterEmpty"],
                    "chat_type_filter": NSNull(), "min_date": 0, "max_date": 0,
                    "@extra": messagesExtra,
                ])
            } catch {
                _ = pendingSearchRequests.take(for: messagesExtra)
            }
        }
        refreshChatList()
    }

    private func startDeferredSearchIfReady() {
        guard pendingSearchRequests.isEmpty, let deferredSearch else { return }
        self.deferredSearch = nil
        guard deferredSearch.generation == searchGeneration,
              deferredSearch.query == activeSearchQuery, !lockState else { return }
        startSearch(deferredSearch.query, generation: deferredSearch.generation)
    }

    @objc private func openSearchResult(_ sender: NSButton) {
        guard !lockState, let key = sender.identifier?.rawValue,
              let result = searchResultByControlID[key],
              let target = runtimesByAccount[result.account], target.telegramUserID != nil else { return }
        if let conversation = result.conversation {
            switch conversation.topic {
            case .main, .forum: break
            default:
                setStatus("Найдено сообщение в типе темы, который пока не поддерживается интерфейсом.")
                return
            }
        }
        searchDebounceTask?.cancel()
        searchGeneration &+= 1
        deferredSearch = nil
        activeSearchQuery = ""
        searchField.stringValue = ""
        searchResults.removeAll()
        searchResultByControlID.removeAll()
        if runtime !== target {
            if let old = runtime, let oldChat = selectedChatByAccount[old.account] {
                stopTypingAction()
                cancelPhotoDownloads(account: old.account, chatID: oldChat)
                try? old.send(["@type": "closeChat", "chat_id": oldChat])
            }
            runtime = target
            target.loadMainChats()
            refreshAccountPicker(select: target.account)
            showAuthenticatedChatUI()
        }
        guard let conversation = result.conversation else {
            refreshChatList()
            displaySelectedConversation()
            return
        }
        if case .forum(let topicID) = conversation.topic {
            selectedForumTopicIDsByAccount[result.account, default: [:]][conversation.chatID] = topicID
        }
        if let messageID = result.messageID {
            historyAnchorByConversation[conversation] = messageID
        }
        openChat(chatID: conversation.chatID, in: target)
        refreshChatList()
    }

    @objc private func openChatFromButton(_ sender: NSButton) {
        guard let id = sender.identifier.flatMap({ Int64($0.rawValue) }), let runtime else { return }
        openChat(chatID: id, in: runtime)
    }

    private func openChat(chatID id: Int64, in runtime: LocalAccountRuntime) {
        closePhotoViewer()
        if let previous = selectedChatByAccount[runtime.account], previous != id {
            stopTypingAction()
            cancelPhotoDownloads(account: runtime.account, chatID: previous)
            try? runtime.send(["@type": "closeChat", "chat_id": previous])
        }
        selectedChatByAccount[runtime.account] = id
        topicPicker.isHidden = !forumChatsByAccount[runtime.account, default: []].contains(id)
        if forumChatsByAccount[runtime.account, default: []].contains(id),
           selectedForumTopicIDsByAccount[runtime.account]?[id] == nil,
           let cached = forumTopicsByAccount[runtime.account]?[id] {
            let initial = cached.first(where: \.isGeneral)?.id ?? cached.first?.id
            if let initial { selectedForumTopicIDsByAccount[runtime.account, default: [:]][id] = initial }
        }
        refreshForumTopicPicker(for: id)
        clearStack(messageList)
        if let title = chatRowsByAccount[runtime.account]?[id]?.title,
           let label = chatPane.subviews.first(where: { $0.identifier?.rawValue == "conversationTitle" }) as? NSTextField {
            label.stringValue = title
        }
        if let cached = messagesByConversation[currentConversationKey(for: runtime.account, chatID: id)] {
            renderMessages(cached)
        }
        let conversation = currentConversationKey(for: runtime.account, chatID: id)
        setComposerText(draftsByConversation[conversation] ?? "")
        refreshReplyStatus(for: conversation)
        do {
            try runtime.send(["@type": "openChat", "chat_id": id])
            try runtime.send(["@type": "getChat", "chat_id": id])
            if forumChatsByAccount[runtime.account, default: []].contains(id), forumTopicsByAccount[runtime.account]?[id] == nil {
                historyRequestCounter &+= 1
                let extra = "forum-topics-\(historyRequestCounter)"
                pendingForumTopicsByExtra[extra] = id
                try runtime.send(["@type": "getForumTopics", "chat_id": id, "query": "", "offset_date": 0, "offset_message_id": 0, "offset_forum_topic_id": 0, "limit": 100, "@extra": extra])
                setStatus("Загружаю темы форума…")
            } else {
                loadSelectedConversationHistory(in: runtime, chatID: id)
            }
        } catch { setStatus("Не удалось открыть историю этого чата.") }
        refreshComposerState()
    }

    private func currentConversationKey() -> ConversationKey? {
        guard let runtime, let chatID = selectedChatByAccount[runtime.account] else { return nil }
        return currentConversationKey(for: runtime.account, chatID: chatID)
    }

    private func currentConversationKey(for account: AccountUUID, chatID: Int64) -> ConversationKey {
        if let topic = selectedConversationTopicsByAccount[account]?[chatID] {
            return ConversationKey(account: account, chatID: chatID, topic: topic)
        }
        if forumChatsByAccount[account, default: []].contains(chatID),
           let topicID = selectedForumTopicIDsByAccount[account]?[chatID] {
            return ConversationKey(account: account, chatID: chatID, topic: .forum(topicID: topicID))
        }
        return ConversationKey(account: account, chatID: chatID)
    }

    private func updateTypingAction(for text: String, runtime: LocalAccountRuntime, conversation: ConversationKey) {
        guard !lockState, !tdlibReceiveFailed,
              runtime === self.runtime,
              runtime.telegramUserID != nil else { return }
        let commands = typingActionPolicy.update(
            conversation: conversation,
            hasText: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            now: ProcessInfo.processInfo.systemUptime
        )
        for command in commands { dispatchTypingAction(command) }
    }

    private func stopTypingAction() {
        guard let command = typingActionPolicy.stop() else { return }
        dispatchTypingAction(command)
    }

    private func dispatchTypingAction(_ command: TypingActionCommand) {
        let conversation: ConversationKey
        let action: Any
        switch command {
        case .typing(let key):
            conversation = key
            action = ["@type": "chatActionTyping"]
        case .cancel(let key):
            conversation = key
            action = NSNull()
        }
        guard let target = runtimesByAccount[conversation.account],
              let userID = target.telegramUserID else { return }
        let intentEpoch = privacyDispatchBarrier.currentEpoch()
        let request: [String: Any] = [
            "@type": "sendChatAction",
            "chat_id": conversation.chatID,
            "topic_id": tdlibTopicValue(for: conversation.topic),
            "business_connection_id": "",
            "action": action,
        ]
        do {
            let accepted = try privacyDispatchBarrier.dispatchBoundUserCommand(
                account: conversation.account,
                expectedTelegramUserID: userID,
                runtimeGeneration: target.generation,
                privacyEpoch: intentEpoch,
                currentAccount: target.account,
                currentTelegramUserID: userID,
                currentGeneration: target.generation
            ) {
                try target.send(request)
            }
            if !accepted, case .typing(let key) = command {
                typingActionPolicy.retryTypingAction(for: key)
            }
        } catch {
            if case .typing(let key) = command { typingActionPolicy.retryTypingAction(for: key) }
        }
    }

    private func scheduleVisibleReadReceiptEvaluation() {
        guard !lockState else {
            visibleReadReceiptTask?.cancel()
            visibleReadReceiptTask = nil
            return
        }
        visibleReadReceiptTask?.cancel()
        visibleReadReceiptTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled, let self else { return }
            self.visibleReadReceiptTask = nil
            self.dispatchVisibleReadReceiptsForCurrentConversation()
        }
    }

    private func dispatchVisibleReadReceiptsForCurrentConversation() {
        guard !lockState,
              !tdlibReceiveFailed,
              window.isVisible,
              window.isKeyWindow,
              !window.isMiniaturized,
              NSApp.isActive,
              !chatPane.isHidden,
              let selected = runtime,
              selected.authorizationState == "authorizationStateReady",
              let userID = selected.telegramUserID,
              runtimesByAccount[selected.account] === selected,
              let conversation = currentConversationKey(),
              conversation.account == selected.account,
              let messages = messagesByConversation[conversation] else { return }

        window.contentView?.layoutSubtreeIfNeeded()
        messageList.layoutSubtreeIfNeeded()
        let viewport = messageList.convert(messageScroll.contentView.bounds, from: messageScroll.contentView)
        guard !viewport.isEmpty else { return }
        var visibleIDs = Set<Int64>()
        for (id, view) in messageReadViewsByID {
            guard view.window === window, !view.isHidden, !view.bounds.isEmpty else { continue }
            let frame = view.convert(view.bounds, to: messageList)
            if viewport.contains(frame) { visibleIDs.insert(id) }
        }
        guard !visibleIDs.isEmpty else { return }

        let candidates: [VisibleMessageReadCandidate] = messages.compactMap { message in
            guard let id = (message["id"] as? NSNumber)?.int64Value, id > 0 else { return nil }
            let incoming = (message["is_outgoing"] as? Bool) == false
            let selfDestruct = (message["self_destruct_in"] as? NSNumber)?.doubleValue ?? 0
            let paidStars = (message["paid_message_star_count"] as? NSNumber)?.int64Value ?? 0
            let content = message["content"] as? [String: Any] ?? [:]
            let isPhoto = content["@type"] as? String == "messagePhoto"
            let restrictedPhoto = isPhoto && (
                (content["is_secret"] as? Bool ?? false)
                    || (message["can_be_saved"] as? Bool == false)
            )
            return VisibleMessageReadCandidate(
                messageID: id,
                isIncoming: incoming,
                canBeViewed: selfDestruct <= 0 && paidStars == 0 && !restrictedPhoto
            )
        }
        var allCandidates = candidates
        if let chatID = selectedChatByAccount[selected.account] {
            let key = SponsoredMessagesKey(account: selected.account, generation: selected.generation, chatID: chatID)
            let sponsoredIDs = SponsoredMessagesPolicy.viewableMessageIDs(
                cards: sponsoredMessagesByKey[key] ?? [],
                fullyVisibleIDs: visibleIDs
            )
            for id in sponsoredIDs {
                allCandidates.append(VisibleMessageReadCandidate(messageID: id, isIncoming: true))
            }
        }
        let ids = visibleReadReceiptRegistry.candidateIDs(
            messages: allCandidates,
            fullyVisibleMessageIDs: visibleIDs,
            conversation: conversation,
            runtimeGeneration: selected.generation
        )
        guard !ids.isEmpty else { return }

        historyRequestCounter &+= 1
        let extra = "message-view-\(historyRequestCounter)"
        guard let request = visibleReadReceiptRegistry.begin(
            extra: extra,
            conversation: conversation,
            runtimeGeneration: selected.generation,
            messageIDs: ids
        ) else { return }
        let tdRequest: [String: Any] = [
            "@type": "viewMessages",
            "chat_id": conversation.chatID,
            "message_ids": request.messageIDs.map { NSNumber(value: $0) },
            "source": NSNull(),
            "force_read": false,
            "@extra": extra,
        ]
        let epoch = privacyDispatchBarrier.currentEpoch()
        do {
            let didDispatch = try privacyDispatchBarrier.dispatchBoundUserCommand(
                account: selected.account,
                expectedTelegramUserID: userID,
                runtimeGeneration: selected.generation,
                privacyEpoch: epoch,
                currentAccount: runtime?.account ?? AccountUUID(),
                currentTelegramUserID: selected.telegramUserID ?? 0,
                currentGeneration: selected.generation
            ) {
                try selected.send(tdRequest)
            }
            if !didDispatch {
                _ = visibleReadReceiptRegistry.resolve(
                    extra: extra,
                    account: selected.account,
                    runtimeGeneration: selected.generation,
                    succeeded: false
                )
            }
        } catch {
            _ = visibleReadReceiptRegistry.resolve(
                extra: extra,
                account: selected.account,
                runtimeGeneration: selected.generation,
                succeeded: false
            )
        }
    }

    private func canSendInTopic(_ topic: ConversationTopicKey, account: AccountUUID, chatID: Int64) -> Bool {
        guard case .forum(let topicID) = topic else { return true }
        guard let descriptor = forumTopicsByAccount[account]?[chatID]?.first(where: { $0.id == topicID }) else { return false }
        return !descriptor.isClosed
    }

    private func conversationKey(for message: [String: Any], account: AccountUUID, chatID: Int64) -> ConversationKey {
        guard let topic = message["topic_id"] as? [String: Any] else {
            return ConversationKey(account: account, chatID: chatID)
        }
        switch topic["@type"] as? String {
        case "messageTopicForum":
            guard let topicID = (topic["forum_topic_id"] as? NSNumber)?.int32Value, topicID > 0 else { break }
            return ConversationKey(account: account, chatID: chatID, topic: .forum(topicID: topicID))
        case "messageTopicThread":
            guard let messageID = (topic["message_thread_id"] as? NSNumber)?.int64Value, messageID > 0 else { break }
            return ConversationKey(account: account, chatID: chatID, topic: .thread(messageThreadID: messageID))
        case "messageTopicDirectMessages":
            guard let topicID = (topic["direct_messages_chat_topic_id"] as? NSNumber)?.int64Value else { break }
            return ConversationKey(account: account, chatID: chatID, topic: .directMessages(topicID: topicID))
        case "messageTopicSavedMessages":
            guard let topicID = (topic["saved_messages_topic_id"] as? NSNumber)?.int64Value else { break }
            return ConversationKey(account: account, chatID: chatID, topic: .savedMessages(topicID: topicID))
        default: break
        }
        return ConversationKey(account: account, chatID: chatID)
    }

    private func tdlibTopicValue(for topic: ConversationTopicKey) -> Any {
        switch topic {
        case .main: return NSNull()
        case .forum(let topicID): return ["@type": "messageTopicForum", "forum_topic_id": topicID]
        case .thread(let messageID): return ["@type": "messageTopicThread", "message_thread_id": messageID]
        case .directMessages(let topicID): return ["@type": "messageTopicDirectMessages", "direct_messages_chat_topic_id": topicID]
        case .savedMessages(let topicID): return ["@type": "messageTopicSavedMessages", "saved_messages_topic_id": topicID]
        }
    }

    private func tdlibReplyToValue(_ messageID: Int64?) -> Any {
        guard let messageID else { return NSNull() }
        return [
            "@type": "inputMessageReplyToMessage",
            "message_id": messageID,
            "quote": NSNull(),
            "checklist_task_id": 0,
            "poll_option_id": "",
        ]
    }

    @objc private func selectForumTopic() {
        guard let runtime, let chatID = selectedChatByAccount[runtime.account],
              topicPickerIDs.indices.contains(topicPicker.indexOfSelectedItem) else { return }
        let topicID = topicPickerIDs[topicPicker.indexOfSelectedItem]
        stopTypingAction()
        selectedForumTopicIDsByAccount[runtime.account, default: [:]][chatID] = topicID
        selectedConversationTopicsByAccount[runtime.account]?.removeValue(forKey: chatID)
        let conversation = currentConversationKey(for: runtime.account, chatID: chatID)
        clearStack(messageList)
        renderMessages(messagesByConversation[conversation] ?? [])
        setComposerText(draftsByConversation[conversation] ?? "")
        refreshReplyStatus(for: conversation)
        loadSelectedConversationHistory(in: runtime, chatID: chatID)
        refreshComposerState()
    }

    private func refreshForumTopicPicker(for chatID: Int64) {
        guard let runtime, let selectedChat = selectedChatByAccount[runtime.account], selectedChat == chatID else { return }
        let topics = forumTopicsByAccount[runtime.account]?[chatID] ?? []
        topicPicker.removeAllItems()
        topicPickerIDs = topics.map(\.id)
        for topic in topics { topicPicker.addItem(withTitle: topic.isClosed ? "\(topic.title) · закрыта" : topic.title) }
        topicPicker.isHidden = !forumChatsByAccount[runtime.account, default: []].contains(chatID) || topics.isEmpty
        if let selected = selectedForumTopicIDsByAccount[runtime.account]?[chatID],
           let index = topicPickerIDs.firstIndex(of: selected) {
            topicPicker.selectItem(at: index)
        } else if let selected = selectedForumTopicIDsByAccount[runtime.account]?[chatID],
                  forumChatsByAccount[runtime.account, default: []].contains(chatID) {
            // A notification may point at a valid topic beyond the first page.
            // Preserve that exact target; never select a different topic silently.
            topicPicker.addItem(withTitle: "Тема из уведомления")
            topicPickerIDs.insert(selected, at: 0)
            topicPicker.selectItem(at: 0)
        }
    }

    private func loadSelectedConversationHistory(in runtime: LocalAccountRuntime, chatID: Int64) {
        guard runtime === self.runtime, selectedChatByAccount[runtime.account] == chatID else { return }
        let conversation = currentConversationKey(for: runtime.account, chatID: chatID)
        let anchorMessageID = historyAnchorByConversation.removeValue(forKey: conversation) ?? 0
        historyRequestCounter &+= 1
        let extra = "history-\(historyRequestCounter)"
        let requestGeneration = (historyRequestGenerationByConversation[conversation] ?? 0) &+ 1
        historyRequestGenerationByConversation[conversation] = requestGeneration
        pendingHistoryRequests.register(
            ConversationHistoryRequestContext(
                conversation: conversation,
                runtimeGeneration: runtime.generation,
                requestGeneration: requestGeneration
            ),
            for: extra
        )
        messagesByConversation[conversation] = messagesByConversation[conversation] ?? []
        do {
            var request = ConversationHistoryRequest.make(for: conversation, fromMessageID: anchorMessageID)
            request["@extra"] = extra
            try runtime.send(request)
        } catch {
            _ = pendingHistoryRequests.take(for: extra)
            setStatus("Не удалось загрузить историю выбранной темы.")
        }
    }

    private func displaySelectedConversation() {
        clearStack(messageList)
        guard let runtime, let id = selectedChatByAccount[runtime.account] else {
            if let label = chatPane.subviews.first(where: { $0.identifier?.rawValue == "conversationTitle" }) as? NSTextField {
                label.stringValue = "Выберите чат"
            }
            topicPicker.isHidden = true
            refreshReplyStatus(for: nil)
            setComposerText("")
            refreshComposerState()
            return
        }
        if let title = chatRowsByAccount[runtime.account]?[id]?.title,
           let label = chatPane.subviews.first(where: { $0.identifier?.rawValue == "conversationTitle" }) as? NSTextField {
            label.stringValue = title
        }
        let key = currentConversationKey(for: runtime.account, chatID: id)
        refreshForumTopicPicker(for: id)
        renderMessages(messagesByConversation[key] ?? [])
        setComposerText(draftsByConversation[key] ?? "")
        refreshReplyStatus(for: key)
        refreshComposerState()
    }

    func textDidChange(_ notification: Notification) {
        guard !suppressDraftUpdate, !lockState, let runtime,
              let chatID = selectedChatByAccount[runtime.account] else { return }
        let key = currentConversationKey(for: runtime.account, chatID: chatID)
        draftsByConversation[key] = composer.string
        updateTypingAction(for: composer.string, runtime: runtime, conversation: key)
        guard !unavailableDraftAccounts.contains(runtime.account) else {
            dirtyDraftAccounts.insert(runtime.account)
            setStatus("Черновики недоступны из-за ошибки защищённого хранилища.")
            return
        }
        persistDrafts(for: runtime.account)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard commandSelector == #selector(NSResponder.insertNewline(_:)),
              control === phoneField || control === emailField || control === inputField || control === secureInputField
                || control === firstNameField || control === lastNameField else { return false }
        primaryAction()
        return true
    }

    @objc private func sendText() {
        guard !lockState, !tdlibReceiveFailed, let runtime, let userID = runtime.telegramUserID,
              let chatID = selectedChatByAccount[runtime.account] else { return }
        let text = composer.string
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let conversation = currentConversationKey(for: runtime.account, chatID: chatID)
        let entities = TextEntityParser.entities(in: text)
        let replyToMessageID = replyTargetsByConversation[conversation]
        let intent = SendIntent(
            account: runtime.account,
            expectedTelegramUserID: userID,
            runtimeGeneration: runtime.generation,
            conversation: conversation,
            replyToMessageID: replyToMessageID,
            sendAsUserID: userID,
            text: text,
            entities: entities,
            privacyEpoch: privacyDispatchBarrier.currentEpoch()
        )
        guard let eligibility = sendEligibilityByAccount[runtime.account]?[chatID],
              eligibility.permitsTextSend(as: userID, topic: conversation.topic, paidStars: SendIntent.maximumPaidStars),
              canSendInTopic(conversation.topic, account: runtime.account, chatID: chatID) else {
            setStatus("Отправка заблокирована: нет подтверждённых прав, отправителя или допустимого типа чата.")
            return
        }
        stopTypingAction()
        historyRequestCounter &+= 1
        let extra = "send-\(historyRequestCounter)"
        let input: [String: Any] = [
            "@type": "inputMessageText",
            "text": ["@type": "formattedText", "text": text, "entities": tdlibFormattedEntities(entities)],
            "link_preview_options": NSNull(),
            "clear_draft": false,
        ]
        let options: [String: Any] = [
            "@type": "messageSendOptions",
            "suggested_post_info": NSNull(),
            "disable_notification": false,
            "from_background": false,
            "protect_content": false,
            "allow_paid_broadcast": false,
            "paid_message_star_count": SendIntent.maximumPaidStars,
            "update_order_of_installed_sticker_sets": false,
            "scheduling_state": NSNull(),
            "effect_id": 0,
            "sending_id": 0,
            "only_preview": false,
        ]
        let request: [String: Any] = [
            "@type": "sendMessage",
            "chat_id": chatID,
            "topic_id": tdlibTopicValue(for: conversation.topic),
            "reply_to": tdlibReplyToValue(replyToMessageID),
            "options": options,
            "reply_markup": NSNull(),
            "input_message_content": input,
            "@extra": extra,
        ]
        do {
            let didDispatch = try privacyDispatchBarrier.dispatch(
                intent,
                currentAccount: runtime.account,
                currentTelegramUserID: userID,
                currentGeneration: runtime.generation
            ) { try runtime.send(request) }
            guard didDispatch else {
                setStatus("Отправка отменена: аккаунт или состояние блокировки изменились.")
                return
            }
            draftsByConversation[intent.conversation] = text
            pendingSendByExtra[extra] = PendingSend(intent: intent, text: text)
            sendButton.isEnabled = false
            photoSendButton.isEnabled = false
            setStatus("Ожидаю подтверждение TDLib…")
        } catch {
            setStatus("Не удалось передать сообщение TDLib. Текст оставлен в поле.")
        }
    }

    @objc private func selectAndSendPhoto() {
        guard !lockState, !tdlibReceiveFailed, let runtime, let userID = runtime.telegramUserID,
              let chatID = selectedChatByAccount[runtime.account],
              let permission = sendEligibilityByAccount[runtime.account]?[chatID],
              permission.permitsTextSend(as: userID, topic: currentConversationKey(for: runtime.account, chatID: chatID).topic, paidStars: SendIntent.maximumPaidStars),
              canSendInTopic(currentConversationKey(for: runtime.account, chatID: chatID).topic, account: runtime.account, chatID: chatID) else {
            setStatus("Отправка фото недоступна: проверьте права и выбранную переписку.")
            return
        }
        let context = PhotoSendContext(
            account: runtime.account,
            expectedTelegramUserID: userID,
            runtimeGeneration: runtime.generation,
            conversation: currentConversationKey(for: runtime.account, chatID: chatID),
            replyToMessageID: replyTargetsByConversation[currentConversationKey(for: runtime.account, chatID: chatID)],
            caption: composer.string,
            privacyEpoch: privacyDispatchBarrier.currentEpoch()
        )
        stopTypingAction()
        let panel = NSOpenPanel()
        panel.title = "Выберите фотографию"
        panel.message = "Будет отправлено одно фото. Подпись берётся из поля сообщения."
        panel.allowedContentTypes = [.jpeg, .png, .heic, .tiff, .bmp]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor [weak self] in
                guard let self, !self.lockState,
                      self.privacyDispatchBarrier.currentEpoch() == context.privacyEpoch else { return }
                self.stageAndSendPhoto(url, context: context, runtime: runtime)
            }
        }
    }

    private func stageAndSendPhoto(_ sourceURL: URL, context: PhotoSendContext, runtime: LocalAccountRuntime) {
        guard !lockState, privacyDispatchBarrier.currentEpoch() == context.privacyEpoch,
              runtime.account == context.account, runtime.generation == context.runtimeGeneration,
              runtime.telegramUserID == context.expectedTelegramUserID,
              let permission = sendEligibilityByAccount[context.account]?[context.conversation.chatID],
              permission.permitsTextSend(as: context.expectedTelegramUserID, topic: context.conversation.topic, paidStars: SendIntent.maximumPaidStars),
              canSendInTopic(context.conversation.topic, account: context.account, chatID: context.conversation.chatID) else { return }
        let filesDirectory = runtime.paths.files
        setStatus("Проверяю фотографию…")
        Task { @MainActor [weak self] in
            let stagedURL: URL
            let hasScopedAccess = sourceURL.startAccessingSecurityScopedResource()
            defer { if hasScopedAccess { sourceURL.stopAccessingSecurityScopedResource() } }
            do {
                stagedURL = try await Task.detached(priority: .userInitiated) {
                    try OutgoingPhotoStager.stage(sourceURL, accountFilesDirectory: filesDirectory)
                }.value
            } catch {
                guard let self, !self.lockState else { return }
                self.setStatus(self.photoStagingErrorMessage(error))
                return
            }
            guard let self else { try? FileManager.default.removeItem(at: stagedURL); return }
            let intent = SendIntent(
                account: context.account,
                expectedTelegramUserID: context.expectedTelegramUserID,
                runtimeGeneration: context.runtimeGeneration,
                conversation: context.conversation,
                replyToMessageID: context.replyToMessageID,
                sendAsUserID: context.expectedTelegramUserID,
                text: context.caption,
                entities: TextEntityParser.entities(in: context.caption),
                attachments: [SendAttachment(localFileURL: stagedURL)],
                privacyEpoch: context.privacyEpoch
            )
            guard let photoStore = self.outgoingPhotoManifestStoresByAccount[context.account] else {
                try? FileManager.default.removeItem(at: stagedURL)
                self.setStatus("Не удалось безопасно сохранить состояние фото. Отправка не начата.")
                return
            }
            do {
                // Persist ownership before dispatch so a crash cannot turn an
                // in-flight local file into an invisible orphan.
                try photoStore.register(stagedURL)
            } catch {
                try? FileManager.default.removeItem(at: stagedURL)
                self.setStatus("Не удалось сохранить состояние фото. Отправка не начата.")
                return
            }
            let input: [String: Any] = [
                "@type": "inputMessagePhoto",
                "photo": [
                    "@type": "inputPhoto",
                    "photo": ["@type": "inputFileLocal", "path": stagedURL.path],
                    "thumbnail": NSNull(),
                    "video": NSNull(),
                    "added_sticker_file_ids": [],
                    "width": 0,
                    "height": 0,
                ],
                "caption": ["@type": "formattedText", "text": context.caption, "entities": self.tdlibFormattedEntities(intent.entities)],
                "show_caption_above_media": false,
                "self_destruct_type": NSNull(),
                "has_spoiler": false,
            ]
            self.historyRequestCounter &+= 1
            let extra = "send-photo-\(self.historyRequestCounter)"
            let request: [String: Any] = [
                "@type": "sendMessage",
                "chat_id": context.conversation.chatID,
                "topic_id": self.tdlibTopicValue(for: context.conversation.topic),
                "reply_to": self.tdlibReplyToValue(context.replyToMessageID),
                "options": self.defaultMessageSendOptions(),
                "reply_markup": NSNull(),
                "input_message_content": input,
                "@extra": extra,
            ]
            self.pendingStagedPhotoPaths[context.account, default: []].insert(stagedURL.standardizedFileURL)
            do {
                let accepted = try self.privacyDispatchBarrier.dispatch(
                    intent,
                    currentAccount: context.account,
                    currentTelegramUserID: context.expectedTelegramUserID,
                    currentGeneration: context.runtimeGeneration
                ) { try runtime.send(request) }
                guard accepted else {
                    self.releaseStagedOutgoingPhoto(stagedURL, account: context.account)
                    self.setStatus("Отправка фото отменена: блокировка или профиль изменились.")
                    return
                }
                self.pendingSendByExtra[extra] = PendingSend(intent: intent, text: context.caption)
                self.photoSendButton.isEnabled = false
                self.sendButton.isEnabled = false
                self.setStatus("Фото передано TDLib; ожидаю подтверждение.")
            } catch {
                self.releaseStagedOutgoingPhoto(stagedURL, account: context.account)
                self.setStatus("Не удалось передать фото TDLib. Подпись оставлена в черновике.")
            }
        }
    }

    private func defaultMessageSendOptions() -> [String: Any] {
        [
            "@type": "messageSendOptions",
            "suggested_post_info": NSNull(),
            "disable_notification": false,
            "from_background": false,
            "protect_content": false,
            "allow_paid_broadcast": false,
            "paid_message_star_count": SendIntent.maximumPaidStars,
            "update_order_of_installed_sticker_sets": false,
            "scheduling_state": NSNull(),
            "effect_id": 0,
            "sending_id": 0,
            "only_preview": false,
        ]
    }

    private func tdlibFormattedEntities(_ entities: [TextEntitySpan]) -> [[String: Any]] {
        entities.map { entity in
            [
                "@type": "textEntity",
                "offset": entity.offsetUTF16,
                "length": entity.lengthUTF16,
                "type": ["@type": entity.type],
            ]
        }
    }

    private func photoStagingErrorMessage(_ error: Error) -> String {
        switch error as? OutgoingPhotoStagerError {
        case .tooLarge: "Фото превышает лимит Telegram в 10 МБ."
        case .unsupportedOrAnimated: "Выберите неподвижное фото в JPEG, PNG, HEIC, TIFF или BMP."
        case .invalidDimensions: "Размеры фото не подходят для отправки в Telegram."
        default: "Не удалось прочитать выбранное фото."
        }
    }

    private func applySendOutcome(
        _ outcome: SendMessageOutcome,
        pending: PendingSend,
        target: LocalAccountRuntime,
        mayPresent: Bool = true
    ) {
        switch outcome {
        case .succeeded:
            if draftsByConversation[pending.intent.conversation] == pending.text {
                draftsByConversation.removeValue(forKey: pending.intent.conversation)
                persistDrafts(for: pending.intent.account)
                if mayPresent, !lockState, currentConversationKey() == pending.intent.conversation {
                    setComposerText("")
                }
            } else if let store = draftStoresByAccount[pending.intent.account],
                      !unavailableDraftAccounts.contains(pending.intent.account) {
                // Privacy Lock may have purged the presentation cache after
                // TDLib accepted this send. Reconcile the encrypted durable
                // draft by value, so a newer draft is never removed and no
                // unrelated drafts are overwritten from an empty cache.
                do {
                    _ = try store.removeDraftIfMatching(pending.intent.conversation, text: pending.text)
                } catch {
                    unavailableDraftAccounts.insert(pending.intent.account)
                    setStatus("Отправка подтверждена, но черновик не удалось сверить с хранилищем.")
                }
            }
            if let replyID = pending.intent.replyToMessageID,
               replyTargetsByConversation[pending.intent.conversation] == replyID {
                replyTargetsByConversation.removeValue(forKey: pending.intent.conversation)
                if mayPresent, !lockState, currentConversationKey() == pending.intent.conversation {
                    refreshReplyStatus(for: pending.intent.conversation)
                }
            }
            if mayPresent, !lockState, target === runtime {
                setStatus("TDLib подтвердил отправку сообщения.")
                refreshComposerState()
            }
        case .failed(let canRetry):
            if mayPresent, !lockState, target === runtime {
                setStatus(canRetry
                    ? "TDLib не отправила сообщение и разрешает повтор. Черновик сохранён; повтор не запускается автоматически."
                    : "TDLib не отправила сообщение. Черновик сохранён; повтор не запускается автоматически.")
                refreshComposerState()
            }
        case .deleted:
            if mayPresent, !lockState, target === runtime {
                setStatus("TDLib удалила неотправленное сообщение. Черновик и исходное фото сохранены; повтор не выполняется автоматически.")
                refreshComposerState()
            }
        }
    }

    private func associateOutgoingPhotoUpload(pending: PendingSend, response: [String: Any], account: AccountUUID) {
        guard let stagedURL = pending.intent.attachments.first?.localFileURL,
              let content = response["content"] as? [String: Any],
              content["@type"] as? String == "messagePhoto",
              let photo = content["photo"] as? [String: Any],
              let sizes = photo["sizes"] as? [[String: Any]] else { return }
        let fileIDs = sizes.compactMap { size -> Int32? in
            guard let file = size["photo"] as? [String: Any],
                  let local = file["local"] as? [String: Any],
                  URL(fileURLWithPath: local["path"] as? String ?? "").standardizedFileURL == stagedURL.standardizedFileURL else { return nil }
            return (file["id"] as? NSNumber)?.int32Value
        }
        for fileID in fileIDs {
            if completedOutgoingPhotoFileIDs[account]?.remove(fileID) != nil {
                releaseStagedOutgoingPhoto(stagedURL, account: account)
                return
            } else {
                stagedOutgoingPhotosByFileID[account, default: [:]][fileID] = stagedURL
            }
        }
    }

    private func finishOutgoingPhotoUploadIfReady(_ file: [String: Any], account: AccountUUID) {
        guard let fileID = (file["id"] as? NSNumber)?.int32Value,
              let remote = file["remote"] as? [String: Any] else { return }
        let isCompleted = remote["is_uploading_completed"] as? Bool == true
        if let isActive = remote["is_uploading_active"] as? Bool {
            outgoingPhotoUploadActiveByFileID[account, default: [:]][fileID] = isActive
        }
        if !isCompleted,
           remote["is_uploading_active"] as? Bool == false,
           let stagedURL = stagedOutgoingPhotosByFileID[account]?[fileID],
           terminallyDeletedOutgoingPhotoURLs[account]?.contains(stagedURL.standardizedFileURL) == true {
            finishTerminallyDeletedOutgoingPhoto(stagedURL, fileIDs: [fileID], account: account)
            return
        }
        guard isCompleted else { return }
        if let stagedURL = stagedOutgoingPhotosByFileID[account]?[fileID] {
            if releaseStagedOutgoingPhoto(stagedURL, account: account) {
                stagedOutgoingPhotosByFileID[account]?.removeValue(forKey: fileID)
                terminallyDeletedOutgoingPhotoURLs[account]?.remove(stagedURL.standardizedFileURL)
            }
        } else if let local = file["local"] as? [String: Any],
                  let path = local["path"] as? String,
                  let stagedURL = pendingStagedPhotoPaths[account]?.first(where: { $0 == URL(fileURLWithPath: path).standardizedFileURL }) {
            completedOutgoingPhotoFileIDs[account, default: []].insert(fileID)
            if releaseStagedOutgoingPhoto(stagedURL, account: account) {
                terminallyDeletedOutgoingPhotoURLs[account]?.remove(stagedURL.standardizedFileURL)
            }
        } else if stagedOutgoingPhotosByFileID[account]?.isEmpty == true {
            return
        } else {
            return
        }
        if completedOutgoingPhotoFileIDs[account]?.count ?? 0 > 256,
           let oldest = completedOutgoingPhotoFileIDs[account]?.first {
            completedOutgoingPhotoFileIDs[account]?.remove(oldest)
        }
    }

    private func finishDeletedOutgoingPhotoIfSafe(_ pending: PendingSend, account: AccountUUID) {
        guard let url = pending.intent.attachments.first?.localFileURL.standardizedFileURL else { return }
        terminallyDeletedOutgoingPhotoURLs[account, default: []].insert(url)
        guard let files = stagedOutgoingPhotosByFileID[account] else { return }
        let matchingIDs = files.compactMap { fileID, stagedURL in
            stagedURL.standardizedFileURL == url ? fileID : nil
        }
        guard !matchingIDs.isEmpty,
              matchingIDs.allSatisfy({
                  StagedPhotoDeletionPolicy.mayReleaseSource(
                      isTerminalDelete: true,
                      uploadIsActive: outgoingPhotoUploadActiveByFileID[account]?[$0]
                  )
              }) else { return }
        finishTerminallyDeletedOutgoingPhoto(url, fileIDs: matchingIDs, account: account)
    }

    private func finishTerminallyDeletedOutgoingPhoto(_ url: URL, fileIDs: [Int32], account: AccountUUID) {
        guard terminallyDeletedOutgoingPhotoURLs[account]?.contains(url.standardizedFileURL) == true,
              fileIDs.allSatisfy({
                  StagedPhotoDeletionPolicy.mayReleaseSource(
                      isTerminalDelete: true,
                      uploadIsActive: outgoingPhotoUploadActiveByFileID[account]?[$0]
                  )
              }),
              releaseStagedOutgoingPhoto(url, account: account) else { return }
        stagedOutgoingPhotosByFileID[account] = stagedOutgoingPhotosByFileID[account]?.filter {
            $0.value.standardizedFileURL != url.standardizedFileURL
        }
        fileIDs.forEach { outgoingPhotoUploadActiveByFileID[account]?.removeValue(forKey: $0) }
        terminallyDeletedOutgoingPhotoURLs[account]?.remove(url.standardizedFileURL)
    }

    @discardableResult
    private func releaseStagedOutgoingPhoto(_ url: URL, account: AccountUUID) -> Bool {
        guard let store = outgoingPhotoManifestStoresByAccount[account] else { return false }
        do {
            // The durable owner record is removed first. If the disk write
            // fails, retain the image so TDLib/recovery still has its source.
            try store.remove(url)
            pendingStagedPhotoPaths[account]?.remove(url.standardizedFileURL)
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            if !lockState { setStatus("Не удалось очистить временное фото; файл сохранён для восстановления.") }
            return false
        }
    }

    private func refreshOutgoingPhotoRecoveryStatus() {
        let pendingCount = pendingStagedPhotoPaths.values.reduce(0) { $0 + $1.count }
        if pendingCount > 0 {
            setStatus("Для \(pendingCount) фото сохранён исходный файл; ожидаю подтверждения TDLib. Повторная отправка не выполняется автоматически.")
        } else if !unavailableOutgoingPhotoManifestAccounts.isEmpty {
            setStatus("Не удалось проверить состояние фото в \(unavailableOutgoingPhotoManifestAccounts.count) аккаунте(ах). Данные сохранены; новая отправка фото недоступна.")
        }
    }

    private func setComposerText(_ value: String) {
        guard composer != nil else { return }
        suppressDraftUpdate = true
        composer.string = value
        suppressDraftUpdate = false
    }

    private func refreshComposerState() {
        guard sendButton != nil else { return }
        let topicIsReady = runtime.flatMap { selectedRuntime -> Bool? in
            guard let chatID = selectedChatByAccount[selectedRuntime.account],
                  forumChatsByAccount[selectedRuntime.account, default: []].contains(chatID) else { return true }
            return selectedForumTopicIDsByAccount[selectedRuntime.account]?[chatID] != nil
        } ?? false
        composer.isEditable = !lockState && !tdlibReceiveFailed && topicIsReady && runtime.map { !unavailableDraftAccounts.contains($0.account) } == true
        guard !lockState, !tdlibReceiveFailed, let runtime, let userID = runtime.telegramUserID,
              let chatID = selectedChatByAccount[runtime.account],
              let eligibility = sendEligibilityByAccount[runtime.account]?[chatID] else {
            sendButton.isEnabled = false
            photoSendButton?.isEnabled = false
            return
        }
        let conversation = currentConversationKey(for: runtime.account, chatID: chatID)
        if forumChatsByAccount[runtime.account, default: []].contains(chatID),
           selectedForumTopicIDsByAccount[runtime.account]?[chatID] == nil {
            sendButton.isEnabled = false
            photoSendButton?.isEnabled = false
            return
        }
        sendButton.isEnabled = eligibility.permitsTextSend(as: userID, topic: conversation.topic, paidStars: SendIntent.maximumPaidStars)
            && canSendInTopic(conversation.topic, account: runtime.account, chatID: chatID)
        photoSendButton?.isEnabled = sendButton.isEnabled
    }

    private func persistDrafts(for account: AccountUUID) {
        guard !unavailableDraftAccounts.contains(account), let store = draftStoresByAccount[account] else {
            dirtyDraftAccounts.insert(account)
            return
        }
        do {
            try store.save(draftsByConversation.filter { $0.key.account == account })
            dirtyDraftAccounts.remove(account)
        } catch {
            dirtyDraftAccounts.insert(account)
            setStatus("Черновик пока хранится только в памяти. Не закрывайте приложение, пока хранилище не станет доступно.")
        }
    }

    private func flushDirtyDraftsBeforeQuit() -> Bool {
        for account in dirtyDraftAccounts {
            guard !unavailableDraftAccounts.contains(account), let store = draftStoresByAccount[account] else {
                setStatus("Выход остановлен: не удалось подтвердить сохранность черновика.")
                return false
            }
            do {
                let durableSnapshot = DraftPrivacyCache.draftsForPersistence(
                    account: account,
                    presentationDrafts: draftsByConversation,
                    lockedDirtyDrafts: lockedDirtyDraftRecovery
                )
                try store.save(durableSnapshot)
                dirtyDraftAccounts.remove(account)
            } catch {
                setStatus("Выход остановлен: черновик не удалось сохранить на диск.")
                return false
            }
        }
        return true
    }

    private func reloadPersistedDrafts(for account: AccountUUID) {
        guard !dirtyDraftAccounts.contains(account), let store = draftStoresByAccount[account] else { return }
        do {
            draftsByConversation = draftsByConversation.filter { $0.key.account != account }
            for (conversation, text) in try store.load() { draftsByConversation[conversation] = text }
        } catch {
            unavailableDraftAccounts.insert(account)
            setStatus("Черновики этого аккаунта не открыты; исходный файл сохранён без изменений.")
        }
    }

    private func renderMessages<S: Sequence>(_ messages: S) where S.Element == [String: Any] {
        messageReadViewsByID.removeAll()
        defer { scheduleVisibleReadReceiptEvaluation() }
        let ordered = Array(messages)
        let selected = runtime
        let chatID = selected.flatMap { selectedChatByAccount[$0.account] }
        let key = selected.flatMap { target in chatID.map { SponsoredMessagesKey(account: target.account, generation: target.generation, chatID: $0) } }
        sponsoredActionByControlID.removeAll()
        sponsoredReportActionByControlID.removeAll()
        sponsoredPhotoRetryByControlID.removeAll()
        if let selected, let chatID, let key,
           sponsoredEligibleChatKeys.contains(key), sponsoredBotKeys.contains(key) {
            loadSponsoredMessages(in: selected, chatID: chatID)
            for card in (sponsoredMessagesByKey[key] ?? []).prefix(1) { appendSponsoredMessage(card, key: key) }
        }
        let ids = ordered.map { ($0["media_album_id"] as? NSNumber)?.int64Value ?? 0 }
        let runs = MediaAlbumGrouping.runs(albumIDs: ids)
        let channelCards: [SponsoredMessageCard]
        let channelPlacements: [SponsoredMessagePlacement]
        if !lockState, let selected, let chatID, let key, sponsoredEligibleChatKeys.contains(key), sponsoredChannelKeys.contains(key) {
            loadSponsoredMessages(in: selected, chatID: chatID)
            channelCards = sponsoredMessagesByKey[key] ?? []
            channelPlacements = SponsoredMessagesPolicy.placements(
                cardCount: channelCards.count,
                ordinaryMessageCount: ordered.count,
                albumEndMessageCounts: runs.map { $0.messageIndices.last.map { $0 + 1 } ?? 0 },
                messagesBetween: sponsoredMessagesBetweenByKey[key] ?? 0
            )
        } else {
            channelCards = []
            channelPlacements = []
        }
        for run in runs {
            let items = run.messageIndices.map { ordered[$0] }
            if run.albumID == nil {
                for message in items {
                    let body = appendMessage(message)
                    if let id = (message["id"] as? NSNumber)?.int64Value, let body {
                        messageReadViewsByID[id] = body
                    }
                }
            } else {
                appendPhotoAlbum(items)
            }
            let boundary = (run.messageIndices.last ?? -1) + 1
            if let key {
                for placement in channelPlacements where placement.afterMessageCount == boundary {
                    guard channelCards.indices.contains(placement.cardIndex) else { continue }
                    appendSponsoredMessage(channelCards[placement.cardIndex], key: key)
                }
            }
        }
        guard !lockState, let selected, let chatID, let key,
              sponsoredEligibleChatKeys.contains(key) else { return }
        loadSponsoredMessages(in: selected, chatID: chatID)
        if sponsoredChannelKeys.contains(key) {
            for placement in channelPlacements where placement.afterMessageCount == ordered.count {
                guard channelCards.indices.contains(placement.cardIndex) else { continue }
                appendSponsoredMessage(channelCards[placement.cardIndex], key: key)
            }
        }
    }

    private func appendSponsoredMessage(_ card: SponsoredMessageCard, key: SponsoredMessagesKey) {
        let cardView = NSStackView()
        cardView.orientation = .vertical
        cardView.alignment = .leading
        cardView.spacing = 7
        cardView.edgeInsets = NSEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        cardView.wantsLayer = true
        cardView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        cardView.layer?.cornerRadius = 10
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.widthAnchor.constraint(lessThanOrEqualToConstant: 620).isActive = true

        var sponsoredPhotoPresentation: PhotoPresentationKey?
        var sponsoredPhotoURL: URL?
        if card.contentType == "messagePhoto" {
            guard let photo = card.photo else {
                messageList.addArrangedSubview(NSTextField(wrappingLabelWithString: "Рекламное фото пока недоступно; карточка не показана частично."))
                return
            }
            let photoKey = SponsoredPhotoKey(account: key.account, generation: key.generation, chatID: key.chatID, messageID: card.messageID, fileID: photo.fileID)
            let presentationKey = PhotoPresentationKey(account: key.account, chatID: key.chatID, messageID: card.messageID, fileID: photo.fileID)
            sponsoredPhotoPresentation = presentationKey
            sponsoredPhotoURL = sponsoredPhotoURLs[photoKey]
            if sponsoredPhotoURL == nil, photo.isDownloaded, let path = photo.localPath, !path.isEmpty {
                sponsoredPhotoURL = URL(fileURLWithPath: path)
                sponsoredPhotoURLs[photoKey] = sponsoredPhotoURL
            }
            if sponsoredPhotoURL == nil {
                if !photo.canBeDownloaded {
                    let unavailable = NSTextField(wrappingLabelWithString: "Рекламное фото сейчас недоступно; карточка не показана частично.")
                    unavailable.font = .systemFont(ofSize: 13)
                    unavailable.textColor = .secondaryLabelColor
                    messageList.addArrangedSubview(unavailable)
                    return
                }
                if failedSponsoredPhotos.contains(photoKey) {
                    let retry = NSButton(title: "Повторить загрузку рекламного фото", target: self, action: #selector(retrySponsoredPhoto(_:)))
                    let controlID = UUID().uuidString
                    retry.identifier = NSUserInterfaceItemIdentifier(controlID)
                    sponsoredPhotoRetryByControlID[controlID] = (key, card)
                    messageList.addArrangedSubview(retry)
                    return
                }
                requestSponsoredPhoto(photo, key: photoKey)
                let label = NSTextField(wrappingLabelWithString: "Загружаю рекламную фотографию. Карточка появится после полной загрузки.")
                label.font = .systemFont(ofSize: 13)
                label.textColor = .secondaryLabelColor
                messageList.addArrangedSubview(label)
                return
            }
        }

        let trackedText = NSStackView()
        trackedText.orientation = .vertical
        trackedText.alignment = .leading
        trackedText.spacing = 7
        trackedText.translatesAutoresizingMaskIntoConstraints = false

        let badge = NSTextField(labelWithString: card.recommended ? "Рекомендовано" : "Реклама")
        badge.font = .systemFont(ofSize: 11, weight: .semibold)
        badge.textColor = .controlAccentColor
        badge.setAccessibilityLabel(card.recommended ? "Рекомендованная публикация" : "Спонсируемая публикация")
        trackedText.addArrangedSubview(badge)

        let title = NSTextField(wrappingLabelWithString: card.title)
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.maximumNumberOfLines = 0
        trackedText.addArrangedSubview(title)

        if !card.text.isEmpty {
            let body = NSTextField(wrappingLabelWithString: card.text)
            body.font = .systemFont(ofSize: 14)
            body.maximumNumberOfLines = 0
            trackedText.addArrangedSubview(body)
        }
        if let photoKey = sponsoredPhotoPresentation, let fileURL = sponsoredPhotoURL {
            let imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: 320, height: 240))
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.setAccessibilityLabel("Фотография спонсируемого сообщения")
            imageView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                imageView.widthAnchor.constraint(equalToConstant: 320),
                imageView.heightAnchor.constraint(equalToConstant: 240),
            ])
            photoViews[photoKey] = imageView
            photoLocalURLs[photoKey] = fileURL
            cardView.addArrangedSubview(imageView)
        }
        let mediaDescription = sponsoredMediaDescription(card.contentType)
        if !mediaDescription.isEmpty {
            let media = NSTextField(wrappingLabelWithString: mediaDescription)
            media.font = .systemFont(ofSize: 12)
            media.textColor = .secondaryLabelColor
            media.maximumNumberOfLines = 0
            cardView.addArrangedSubview(media)
        }

        if !card.sponsorInfo.isEmpty || !card.additionalInfo.isEmpty {
            let info = NSTextField(wrappingLabelWithString: [card.sponsorInfo, card.additionalInfo].filter { !$0.isEmpty }.joined(separator: "\n"))
            info.font = .systemFont(ofSize: 11)
            info.textColor = .secondaryLabelColor
            info.maximumNumberOfLines = 0
            trackedText.addArrangedSubview(info)
        }

        cardView.addArrangedSubview(trackedText)
        if card.contentType == "messageText" || card.contentType == "messagePhoto" {
            messageReadViewsByID[card.messageID] = trackedText
        }

        let button = NSButton(title: card.buttonText.isEmpty ? "Подробнее" : card.buttonText, target: self, action: #selector(openSponsoredLink(_:)))
        button.bezelStyle = .rounded
        button.isEnabled = !card.sponsorURL.isEmpty
        button.setAccessibilityLabel("Реклама: \(button.title) — \(card.title)")
        let controlID = UUID().uuidString
        button.identifier = NSUserInterfaceItemIdentifier(controlID)
        sponsoredActionByControlID[controlID] = (key, card)
        cardView.addArrangedSubview(button)
        if card.reportable {
            let reportButton = NSButton(title: "Пожаловаться", target: self, action: #selector(reportSponsoredMessage(_:)))
            reportButton.bezelStyle = .inline
            reportButton.setAccessibilityLabel("Пожаловаться на рекламу: \(card.title)")
            let reportControlID = UUID().uuidString
            reportButton.identifier = NSUserInterfaceItemIdentifier(reportControlID)
            sponsoredReportActionByControlID[reportControlID] = (key, card)
            cardView.addArrangedSubview(reportButton)
        }
        messageList.addArrangedSubview(cardView)
        if let photoKey = sponsoredPhotoPresentation, let fileURL = sponsoredPhotoURL {
            requestPhotoPreview(photoKey, fileURL: fileURL)
        }
    }

    private func requestSponsoredPhoto(_ photo: PhotoFileVariant, key: SponsoredPhotoKey) {
        guard !lockState, let target = runtimesByAccount[key.account], target === runtime,
              target.generation == key.generation, selectedChatByAccount[key.account] == key.chatID,
              photo.canBeDownloaded else { return }
        let conversation = ConversationKey(account: key.account, chatID: key.chatID)
        guard !requestedSponsoredPhotos.contains(key) else { return }
        let activeFiles = photoDownloadsByConversation.values.reduce(0) { $0 + $1.count }
        if !photoDownloadsByConversation[conversation, default: []].contains(photo.fileID), activeFiles >= 4 {
            setStatus("Уже загружаются четыре фотографии. Рекламное фото подождёт.")
            return
        }
        requestedSponsoredPhotos.insert(key)
        photoDownloadsByConversation[conversation, default: []].insert(photo.fileID)
        historyRequestCounter &+= 1
        let extra = "sponsored-photo-\(historyRequestCounter)"
        pendingSponsoredPhotoByExtra[extra] = key
        do {
            try target.send(["@type": "downloadFile", "file_id": photo.fileID, "priority": 16, "offset": 0, "limit": 0, "synchronous": false, "@extra": extra])
        } catch {
            pendingSponsoredPhotoByExtra.removeValue(forKey: extra)
            photoDownloadsByConversation[conversation]?.remove(photo.fileID)
            requestedSponsoredPhotos.remove(key)
            setStatus("Не удалось начать загрузку рекламной фотографии.")
        }
    }

    @objc private func retrySponsoredPhoto(_ sender: NSButton) {
        guard !lockState,
              let identifier = sender.identifier?.rawValue,
              let action = sponsoredPhotoRetryByControlID[identifier],
              let target = runtimesByAccount[action.key.account], target === runtime,
              target.generation == action.key.generation,
              selectedChatByAccount[target.account] == action.key.chatID,
              let photo = action.card.photo else { return }
        let key = SponsoredPhotoKey(account: action.key.account, generation: action.key.generation, chatID: action.key.chatID, messageID: action.card.messageID, fileID: photo.fileID)
        failedSponsoredPhotos.remove(key)
        requestedSponsoredPhotos.remove(key)
        requestSponsoredPhoto(photo, key: key)
        let conversation = currentConversationKey(for: target.account, chatID: action.key.chatID)
        clearStack(messageList)
        renderMessages(messagesByConversation[conversation] ?? [])
    }

    private func sponsoredMediaDescription(_ type: String) -> String {
        switch type {
        case "messagePhoto": return ""
        case "messageAnimation": return "В этой рекламе есть анимация. Просмотр медиа пока не подключён."
        case "messageVideo": return "В этой рекламе есть видео. Специальный рекламный просмотр ещё не подключён."
        default: return "Содержимое рекламы пока не распознано; публикация не скрыта."
        }
    }

    @objc private func openSponsoredLink(_ sender: NSButton) {
        guard !lockState else { return }
        guard let identifier = sender.identifier?.rawValue,
              let action = sponsoredActionByControlID[identifier],
              let target = runtimesByAccount[action.key.account], target === runtime,
              target.generation == action.key.generation,
              selectedChatByAccount[target.account] == action.key.chatID,
              let components = URLComponents(string: action.card.sponsorURL),
              let scheme = components.scheme?.lowercased(), ["https", "http"].contains(scheme),
              components.user == nil, components.password == nil,
              let host = components.host?.lowercased(), !host.isEmpty,
              let url = components.url else {
            setStatus("Ссылка этой рекламы пуста или пока не поддерживается.")
            return
        }
        if !isTrustedTelegramLinkHost(host) {
            let alert = NSAlert()
            alert.messageText = "Открыть ссылку из рекламы?"
            alert.informativeText = host
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Открыть")
            alert.addButton(withTitle: "Отмена")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        do {
            try target.send(SponsoredMessagesPolicy.click(chatID: action.key.chatID, messageID: action.card.messageID))
            _ = NSWorkspace.shared.open(url)
        } catch {
            setStatus("Не удалось открыть рекламную ссылку; аккаунт продолжает работать.")
        }
    }

    @objc private func reportSponsoredMessage(_ sender: NSButton) {
        guard !lockState,
              let identifier = sender.identifier?.rawValue,
              let action = sponsoredReportActionByControlID[identifier],
              let target = runtimesByAccount[action.key.account], target === runtime,
              target.generation == action.key.generation,
              selectedChatByAccount[target.account] == action.key.chatID else {
            setStatus("Жалобу можно отправить только для рекламы в открытой переписке.")
            return
        }
        sendSponsoredReport(action.key, card: action.card, optionID: "", target: target)
    }

    private func sendSponsoredReport(_ key: SponsoredMessagesKey, card: SponsoredMessageCard, optionID: String, target: LocalAccountRuntime) {
        guard !lockState, target === runtime, target.generation == key.generation,
              selectedChatByAccount[target.account] == key.chatID else { return }
        historyRequestCounter &+= 1
        let extra = "sponsored-report-\(historyRequestCounter)"
        pendingSponsoredReportsByExtra[extra] = (key, card)
        do {
            try target.send(SponsoredMessagesPolicy.report(chatID: key.chatID, messageID: card.messageID, optionID: optionID, extra: extra))
        } catch {
            pendingSponsoredReportsByExtra.removeValue(forKey: extra)
            setStatus("Не удалось отправить жалобу на рекламу.")
        }
    }

    private func isTrustedTelegramLinkHost(_ host: String) -> Bool {
        ["telegram.org", "telegram.me", "telegram.dog", "t.me", "telegra.ph", "graph.org", "fragment.com", "telesco.pe"].contains { host == $0 || host.hasSuffix(".\($0)") }
    }

    private func appendPhotoAlbum(_ messages: [[String: Any]]) {
        let title = NSTextField(labelWithString: "Фотоальбом · \(messages.count)")
        title.font = .systemFont(ofSize: 12, weight: .medium)
        title.textColor = .secondaryLabelColor
        messageList.addArrangedSubview(title)
        var offset = 0
        while offset < messages.count {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .top
            row.spacing = 8
            row.distribution = .fill
            row.translatesAutoresizingMaskIntoConstraints = false
            row.widthAnchor.constraint(equalTo: messageList.widthAnchor).isActive = true
            for message in messages[offset..<min(offset + 3, messages.count)] {
                let tile = NSStackView()
                tile.orientation = .vertical
                tile.alignment = .leading
                tile.spacing = 5
                tile.translatesAutoresizingMaskIntoConstraints = false
                tile.widthAnchor.constraint(equalToConstant: 188).isActive = true
                _ = appendMessage(message, into: tile, photoWidth: 180)
                if let id = (message["id"] as? NSNumber)?.int64Value {
                    messageReadViewsByID[id] = tile
                }
                row.addArrangedSubview(tile)
            }
            messageList.addArrangedSubview(row)
            offset += 3
        }
    }

    @discardableResult
    private func appendMessage(_ message: [String: Any], into stack: NSStackView? = nil, photoWidth: CGFloat = 320) -> NSView? {
        var destination: NSStackView = stack ?? messageList!
        guard let content = message["content"] as? [String: Any] else { return nil }
        let type = content["@type"] as? String ?? ""
        if type == "messagePhoto" {
            if stack == nil {
                let photoTile = NSStackView()
                photoTile.orientation = .vertical
                photoTile.alignment = .leading
                photoTile.spacing = 5
                photoTile.translatesAutoresizingMaskIntoConstraints = false
                photoTile.widthAnchor.constraint(equalToConstant: photoWidth + 8).isActive = true
                messageList.addArrangedSubview(photoTile)
                destination = photoTile
            }
            appendPhotoMessage(message, content: content, into: destination, width: photoWidth)
            appendReplyAction(message, into: destination)
            appendMessageActions(message, into: destination)
            return destination
        }
        let sender = message["sender_id"] as? [String: Any]
        let who = sender? ["@type"] as? String == "messageSenderUser" ? "Пользователь" : "Сообщение"
        let body: NSView
        if type == "messageText",
           let formattedText = content["text"] as? [String: Any],
           let textView = incomingMessageTextView(
            formattedText: formattedText,
            prefix: "\(who): ",
            maximumWidth: messageTextWidth(for: destination, albumPhotoWidth: photoWidth)
           ) {
            destination.addArrangedSubview(textView)
            body = textView
        } else {
            let textValue = IncomingMessagePresentation.cardText(for: type)
            let label = NSTextField(wrappingLabelWithString: "\(who): \(textValue)")
            label.font = .systemFont(ofSize: 14)
            label.maximumNumberOfLines = 0
            label.setAccessibilityLabel("\(who). \(textValue)")
            destination.addArrangedSubview(label)
            body = label
        }
        appendReplyAction(message, into: destination)
        appendMessageActions(message, into: destination)
        return body
    }

    private func messageTextWidth(for destination: NSStackView, albumPhotoWidth: CGFloat) -> CGFloat {
        if destination !== messageList { return max(120, albumPhotoWidth + 8) }
        let available = messageScroll?.contentView.bounds.width ?? 0
        return max(240, available - 32)
    }

    private func incomingMessageTextView(
        formattedText: [String: Any],
        prefix: String,
        maximumWidth: CGFloat
    ) -> NSTextView? {
        guard let text = formattedText["text"] as? String else { return nil }
        let spans = IncomingTextEntityPresentation.spans(in: formattedText)
        let baseFont = NSFont.systemFont(ofSize: 14)
        let prefixLength = (prefix as NSString).length
        let attributed = NSMutableAttributedString(
            string: prefix + text,
            attributes: [.font: baseFont, .foregroundColor: NSColor.labelColor]
        )
        for span in spans {
            let range = NSRange(location: prefixLength + span.offsetUTF16, length: span.lengthUTF16)
            guard NSMaxRange(range) <= attributed.length else { continue }
            switch span.type {
            case "textEntityTypeUrl", "textEntityTypeTextUrl", "textEntityTypeEmailAddress":
                if let url = IncomingTextEntityPresentation.destination(for: span, in: text) {
                    attributed.addAttributes(
                        [.link: url, .foregroundColor: NSColor.linkColor, .underlineStyle: NSUnderlineStyle.single.rawValue],
                        range: range
                    )
                }
            case "textEntityTypeBold":
                let currentFont = attributed.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont ?? baseFont
                attributed.addAttribute(.font, value: NSFontManager.shared.convert(currentFont, toHaveTrait: .boldFontMask), range: range)
            case "textEntityTypeItalic":
                let currentFont = attributed.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont ?? baseFont
                attributed.addAttribute(.font, value: NSFontManager.shared.convert(currentFont, toHaveTrait: .italicFontMask), range: range)
            case "textEntityTypeUnderline":
                attributed.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            case "textEntityTypeStrikethrough":
                attributed.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            case "textEntityTypeCode", "textEntityTypePre":
                attributed.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular), range: range)
            default:
                break
            }
        }

        let width = max(120, maximumWidth)
        let textContainer = NSTextContainer(containerSize: NSSize(width: width, height: .greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: 1), textContainer: textContainer)
        textView.textContainerInset = .zero
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = false
        textView.minSize = .zero
        textView.maxSize = NSSize(width: width, height: .greatestFiniteMagnitude)
        textView.textStorage?.setAttributedString(attributed)
        guard let layoutManager = textView.layoutManager else { return nil }
        layoutManager.ensureLayout(for: textContainer)
        let contentHeight = max(20, ceil(layoutManager.usedRect(for: textContainer).height))
        textView.frame = NSRect(x: 0, y: 0, width: width, height: contentHeight)
        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.widthAnchor.constraint(equalToConstant: width),
            textView.heightAnchor.constraint(equalToConstant: contentHeight),
        ])
        textView.setAccessibilityHelp("Текст и ссылки из сообщения Telegram")
        return textView
    }

    private func appendMessageActions(_ message: [String: Any], into destination: NSStackView) {
        guard let runtime,
              let chatID = (message["chat_id"] as? NSNumber)?.int64Value,
              let messageID = (message["id"] as? NSNumber)?.int64Value,
              let chatPermission = sendEligibilityByAccount[runtime.account]?[chatID],
              !chatPermission.isChannel else { return }
        let conversation = conversationKey(for: message, account: runtime.account, chatID: chatID)
        let controlID = "message-actions-\(UUID().uuidString)"
        let button = NSButton(title: "Действия…", target: self, action: #selector(requestMessageActions(_:)))
        button.bezelStyle = .inline
        button.setAccessibilityLabel("Действия с сообщением: \(messagePreview(message))")
        button.identifier = NSUserInterfaceItemIdentifier(controlID)
        messageActionTargetsByControlID[controlID] = MessageActionTarget(
            key: MessageKey(conversation: conversation, messageID: messageID),
            message: message
        )
        messageActionButtonsByControlID[controlID] = button
        destination.addArrangedSubview(button)
    }

    @objc private func requestMessageActions(_ sender: NSButton) {
        guard !lockState,
              let controlID = sender.identifier?.rawValue,
              let target = messageActionTargetsByControlID[controlID],
              target.key.conversation == currentConversationKey(),
              let runtime, runtime.account == target.key.conversation.account,
              let userID = runtime.telegramUserID,
              let chatPermission = sendEligibilityByAccount[runtime.account]?[target.key.conversation.chatID],
              !chatPermission.isChannel else { return }
        let context = MessageActionContext(
            expectedTelegramUserID: userID,
            runtimeGeneration: runtime.generation,
            key: target.key,
            privacyEpoch: privacyDispatchBarrier.currentEpoch(),
            message: target.message
        )
        historyRequestCounter &+= 1
        let extra = "message-properties-\(historyRequestCounter)"
        pendingMessagePropertiesByExtra[extra] = context
        do {
            try runtime.send([
                "@type": "getMessageProperties",
                "chat_id": target.key.conversation.chatID,
                "message_id": target.key.messageID,
                "@extra": extra,
            ])
            setStatus("Проверяю разрешённые действия…")
        } catch {
            pendingMessagePropertiesByExtra.removeValue(forKey: extra)
            setStatus("Не удалось получить разрешения для этого сообщения.")
        }
    }

    private func showMessageActionMenu(_ context: MessageActionContext, permissions: MessageActionPermissions) {
        guard let content = context.message["content"] as? [String: Any],
              let contentType = content["@type"] as? String else { return }
        let menu = NSMenu()
        let editKind: MessageMutationKind?
        switch contentType {
        case "messageText": editKind = .editText
        case "messagePhoto": editKind = .editCaption
        default: editKind = nil
        }
        if let sendingState = context.message["sending_state"] as? [String: Any],
           sendingState["@type"] as? String == "messageSendingStateFailed",
           sendingState["can_retry"] as? Bool == true {
            let retry = NSMenuItem(title: "Повторить отправку через Telegram", action: #selector(retryFailedMessage(_:)), keyEquivalent: "")
            retry.target = self
            retry.representedObject = context
            let blocked = ((sendingState["required_paid_message_star_count"] as? NSNumber)?.int64Value ?? 0) > 0
                || sendingState["need_another_sender"] as? Bool == true
                || sendingState["need_another_reply_quote"] as? Bool == true
                || sendingState["need_drop_reply"] as? Bool == true
            retry.isEnabled = !blocked && !lockState && runtime?.account == context.key.conversation.account
            menu.addItem(retry)
        }
        if permissions.canEdit, let editKind {
            addMessageMenuItem("Изменить…", kind: editKind, context: context, to: menu)
        }
        if permissions.canDeleteForAllUsers {
            addMessageMenuItem("Удалить у всех…", kind: .delete(.forEveryone), context: context, to: menu)
        }
        if permissions.canDeleteOnlyForSelf {
            addMessageMenuItem("Удалить у меня…", kind: .delete(.forCurrentUser), context: context, to: menu)
        }
        guard !menu.items.isEmpty else {
            setStatus("TDLib не разрешает редактировать или удалять это сообщение.")
            return
        }
        let anchor = messageActionButton(for: context.key)
        guard let anchor else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: anchor.bounds.height), in: anchor)
    }

    @objc private func retryFailedMessage(_ sender: NSMenuItem) {
        guard let context = sender.representedObject as? MessageActionContext,
              !lockState,
              context.privacyEpoch == privacyDispatchBarrier.currentEpoch(),
              currentConversationKey() == context.key.conversation,
              let runtime,
              runtime.account == context.key.conversation.account,
              runtime.generation == context.runtimeGeneration,
              let telegramUserID = runtime.telegramUserID,
              telegramUserID == context.expectedTelegramUserID,
              let sendingState = context.message["sending_state"] as? [String: Any],
              sendingState["@type"] as? String == "messageSendingStateFailed",
              sendingState["can_retry"] as? Bool == true else { return }

        let requiredStars = (sendingState["required_paid_message_star_count"] as? NSNumber)?.int64Value ?? 0
        let needsAnotherSender = sendingState["need_another_sender"] as? Bool == true
        let needsAnotherQuote = sendingState["need_another_reply_quote"] as? Bool == true
        let needsDropReply = sendingState["need_drop_reply"] as? Bool == true
        let retryAfter = (sendingState["retry_after"] as? NSNumber)?.doubleValue ?? 0
        guard requiredStars == SendIntent.maximumPaidStars,
              !needsAnotherSender, !needsAnotherQuote, !needsDropReply else {
            setStatus("Повтор требует изменения отправителя/ответа или платных Stars. Ничего не отправлено.")
            return
        }
        if retryAfter > 0 {
            historyRequestCounter &+= 1
            let extra = "retry-refresh-\(historyRequestCounter)"
            do {
                try runtime.send([
                    "@type": "getMessage",
                    "chat_id": context.key.conversation.chatID,
                    "message_id": context.key.messageID,
                    "@extra": extra,
                ])
                pendingRetryRefreshByExtra[extra] = PendingRetryRefresh(
                    key: context.key,
                    runtimeGeneration: context.runtimeGeneration,
                    privacyEpoch: context.privacyEpoch
                )
                setStatus("Сверяю с TDLib, истекло ли время ожидания. Автоповтора не будет.")
            } catch {
                setStatus("Не удалось проверить время ожидания в TDLib; ничего не отправлено.")
            }
            return
        }

        let original = retryableFailedSends[context.key]
        let originalIntent = original?.intent
        let intent = SendIntent(
            account: runtime.account,
            expectedTelegramUserID: telegramUserID,
            runtimeGeneration: runtime.generation,
            conversation: context.key.conversation,
            replyToMessageID: originalIntent?.replyToMessageID,
            sendAsUserID: originalIntent?.sendAsUserID ?? telegramUserID,
            text: originalIntent?.text ?? messageTextForRetry(context.message),
            entities: originalIntent?.entities ?? [],
            attachments: originalIntent?.attachments ?? [],
            privacyEpoch: privacyDispatchBarrier.currentEpoch()
        )
        let pending = PendingSend(intent: intent, text: intent.text)
        let sendKey = SendMessageKey(
            account: runtime.account,
            generation: runtime.generation,
            chatID: context.key.conversation.chatID,
            temporaryMessageID: context.key.messageID
        )
        guard pendingSendLifecycle.register(pending, for: sendKey) == nil else {
            setStatus("У результата предыдущей попытки ещё нет однозначной сверки. Повтор не отправлен.")
            return
        }
        retryingSendKeys.insert(sendKey)
        historyRequestCounter &+= 1
        let extra = "resend-\(historyRequestCounter)"
        let request: [String: Any] = [
            "@type": "resendMessages",
            "chat_id": context.key.conversation.chatID,
            "message_ids": [context.key.messageID],
            "quote": NSNull(),
            "paid_message_star_count": SendIntent.maximumPaidStars,
            "@extra": extra,
        ]
        do {
            let accepted = try privacyDispatchBarrier.dispatch(
                intent,
                currentAccount: runtime.account,
                currentTelegramUserID: telegramUserID,
                currentGeneration: runtime.generation
            ) { try runtime.send(request) }
            guard accepted else {
                retryingSendKeys.remove(sendKey)
                _ = pendingSendLifecycle.resolve(.failed(canRetry: true), for: sendKey, bufferIfUnregistered: false)
                setStatus("Повтор отменён: блокировка или профиль изменились.")
                return
            }
            retryableFailedSends.removeValue(forKey: context.key)
            pendingRetryByExtra[extra] = PendingRetryRequest(
                key: sendKey,
                privacyEpoch: intent.privacyEpoch
            )
            setStatus("Запрос безопасного повтора передан TDLib; новой копии сообщения не создаю.")
        } catch {
            retryingSendKeys.remove(sendKey)
            _ = pendingSendLifecycle.resolve(.failed(canRetry: true), for: sendKey, bufferIfUnregistered: false)
            retryableFailedSends[context.key] = pending
            setStatus("TDLib не приняла запрос повтора. Исходное сообщение и черновик сохранены.")
        }
    }

    private func messageTextForRetry(_ message: [String: Any]) -> String {
        guard let content = message["content"] as? [String: Any] else { return "" }
        let field = content["@type"] as? String == "messagePhoto" ? "caption" : "text"
        return ((content[field] as? [String: Any])?["text"] as? String) ?? messagePreview(message)
    }

    private func addMessageMenuItem(_ title: String, kind: MessageMutationKind, context: MessageActionContext, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: #selector(performMessageMutation(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = MessageActionInvocation(context: context, kind: kind)
        menu.addItem(item)
    }

    private func messageActionButton(for key: MessageKey) -> NSButton? {
        guard let controlID = messageActionTargetsByControlID.first(where: { $0.value.key == key })?.key else { return nil }
        return messageActionButtonsByControlID[controlID]
    }

    @objc private func performMessageMutation(_ sender: NSMenuItem) {
        guard let invocation = sender.representedObject as? MessageActionInvocation,
              !lockState,
              currentConversationKey() == invocation.context.key.conversation else { return }
        switch invocation.kind {
        case .editText, .editCaption:
            presentMessageEditor(invocation)
        case .delete(let mode):
            confirmMessageDeletion(invocation.context, mode: mode)
        }
    }

    private func presentMessageEditor(_ invocation: MessageActionInvocation) {
        let context = invocation.context
        let key = context.key
        let startingText = messageEditDrafts[key] ?? editableMessageText(context.message, kind: invocation.kind) ?? ""
        let editor = NSTextView(frame: NSRect(x: 0, y: 0, width: 380, height: 108))
        editor.string = startingText
        editor.isRichText = false
        editor.font = .systemFont(ofSize: 13)
        editor.setAccessibilityLabel("Новый текст сообщения")
        let editorScroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 380, height: 108))
        editorScroll.borderType = .bezelBorder
        editorScroll.hasVerticalScroller = true
        editorScroll.documentView = editor
        let alert = NSAlert()
        alert.messageText = invocation.kind == .editCaption ? "Изменить подпись" : "Изменить сообщение"
        alert.informativeText = "TDLib повторно проверит действие при отправке."
        alert.accessoryView = editorScroll
        alert.addButton(withTitle: "Сохранить")
        alert.addButton(withTitle: "Отмена")
        activeMessageActionAlert = alert
        activeMessageEditor = editor
        alert.beginSheetModal(for: window) { [weak self] response in
            self?.finishMessageActionAlert(alert)
            guard response == .alertFirstButtonReturn else { return }
            let newText = editor.string
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    self.messageEditDrafts[key] = newText
                    self.setStatus("Пустой текст не отправлен; изменение оставлено для повтора.")
                    return
                }
                self.messageEditDrafts[key] = newText
                self.dispatchMessageMutation(context, kind: invocation.kind, editedText: newText)
            }
        }
    }

    private func confirmMessageDeletion(_ context: MessageActionContext, mode: MessageDeleteMode) {
        let alert = NSAlert()
        alert.messageText = mode == .forEveryone ? "Удалить у всех?" : "Удалить у меня?"
        alert.informativeText = mode == .forEveryone
            ? "Сообщение будет удалено для всех участников, если Telegram подтвердит действие."
            : "Сообщение будет скрыто только в этом аккаунте."
        alert.addButton(withTitle: "Удалить")
        alert.addButton(withTitle: "Отмена")
        activeMessageActionAlert = alert
        alert.beginSheetModal(for: window) { [weak self] response in
            self?.finishMessageActionAlert(alert)
            guard response == .alertFirstButtonReturn else { return }
            Task { @MainActor [weak self] in
                self?.dispatchMessageMutation(context, kind: .delete(mode), editedText: nil)
            }
        }
    }

    private func dispatchMessageMutation(_ context: MessageActionContext, kind: MessageMutationKind, editedText: String?) {
        guard !lockState,
              let runtime = runtimesByAccount[context.key.conversation.account],
              runtime.telegramUserID == context.expectedTelegramUserID,
              runtime.generation == context.runtimeGeneration,
              let chatPermission = sendEligibilityByAccount[runtime.account]?[context.key.conversation.chatID],
              !chatPermission.isChannel else {
            setStatus("Действие отменено: аккаунт изменился или приложение заблокировано.")
            return
        }
        let text = editedText ?? messagePreview(context.message)
        let intent = SendIntent(
            account: runtime.account,
            expectedTelegramUserID: context.expectedTelegramUserID,
            runtimeGeneration: context.runtimeGeneration,
            conversation: context.key.conversation,
            sendAsUserID: context.expectedTelegramUserID,
            text: text,
            entities: TextEntityParser.entities(in: text),
            privacyEpoch: context.privacyEpoch
        )
        historyRequestCounter &+= 1
        let extra = "message-mutation-\(historyRequestCounter)"
        let request: [String: Any]
        switch kind {
        case .editText:
            request = [
                "@type": "editMessageText",
                "chat_id": context.key.conversation.chatID,
                "message_id": context.key.messageID,
                "reply_markup": NSNull(),
                "input_message_content": [
                    "@type": "inputMessageText",
                    "text": ["@type": "formattedText", "text": text, "entities": tdlibFormattedEntities(intent.entities)],
                    "link_preview_options": NSNull(), "clear_draft": false,
                ],
                "@extra": extra,
            ]
        case .editCaption:
            let content = context.message["content"] as? [String: Any]
            request = [
                "@type": "editMessageCaption",
                "chat_id": context.key.conversation.chatID,
                "message_id": context.key.messageID,
                "reply_markup": NSNull(),
                "caption": ["@type": "formattedText", "text": text, "entities": tdlibFormattedEntities(intent.entities)],
                "show_caption_above_media": content?["show_caption_above_media"] as? Bool ?? false,
                "@extra": extra,
            ]
        case .delete(let mode):
            request = [
                "@type": "deleteMessages",
                "chat_id": context.key.conversation.chatID,
                "message_ids": [context.key.messageID],
                "revoke": mode.revoke,
                "@extra": extra,
            ]
        }
        do {
            let dispatched = try privacyDispatchBarrier.dispatch(
                intent,
                currentAccount: runtime.account,
                currentTelegramUserID: context.expectedTelegramUserID,
                currentGeneration: context.runtimeGeneration
            ) { try runtime.send(request) }
            guard dispatched else {
                setStatus("Действие отменено блокировкой или сменой runtime; текст изменения сохранён.")
                return
            }
            pendingMessageMutationsByExtra[extra] = PendingMessageMutation(context: context, kind: kind)
            setStatus(kind == .delete(.forEveryone) || kind == .delete(.forCurrentUser)
                ? "Ожидаю подтверждение удаления…" : "Ожидаю подтверждение изменения…")
        } catch {
            setStatus("TDLib не принял действие. Если редактировалось сообщение, текст сохранён для повтора.")
        }
    }

    private func editableMessageText(_ message: [String: Any], kind: MessageMutationKind) -> String? {
        guard let content = message["content"] as? [String: Any] else { return nil }
        switch kind {
        case .editText:
            guard let formatted = content["text"] as? [String: Any] else { return nil }
            return formatted["text"] as? String
        case .editCaption:
            guard let formatted = content["caption"] as? [String: Any] else { return nil }
            return formatted["text"] as? String
        case .delete: return nil
        }
    }

    private func updateCachedMessage(_ message: [String: Any], for account: AccountUUID, replacingMessageID: Int64? = nil) {
        guard let chatID = (message["chat_id"] as? NSNumber)?.int64Value,
              let messageID = (message["id"] as? NSNumber)?.int64Value else { return }
        let key = conversationKey(for: message, account: account, chatID: chatID)
        if var cache = messagesByConversation[key],
           let index = cache.firstIndex(where: {
               ($0["id"] as? NSNumber)?.int64Value == (replacingMessageID ?? messageID)
           }) {
            cache[index] = message
            messagesByConversation[key] = cache
        }
        if !lockState, currentConversationKey() == key {
            clearStack(messageList)
            renderMessages(messagesByConversation[key] ?? [])
        }
    }

    private func finishMessageActionAlert(_ alert: NSAlert) {
        guard activeMessageActionAlert === alert else { return }
        activeMessageActionAlert = nil
        activeMessageEditor = nil
    }

    private func appendReplyAction(_ message: [String: Any], into destination: NSStackView) {
        guard let runtime,
              let chatID = (message["chat_id"] as? NSNumber)?.int64Value,
              let messageID = (message["id"] as? NSNumber)?.int64Value,
              let permission = sendEligibilityByAccount[runtime.account]?[chatID],
              permission.canSendBasicMessages, !permission.isChannel else { return }
        let conversation = conversationKey(for: message, account: runtime.account, chatID: chatID)
        guard canSendInTopic(conversation.topic, account: runtime.account, chatID: chatID) else { return }
        let button = NSButton(title: "Ответить", target: self, action: #selector(selectReplyTarget(_:)))
        button.bezelStyle = .inline
        button.setAccessibilityLabel("Ответить на сообщение: \(messagePreview(message))")
        let key = MessageKey(conversation: conversation, messageID: messageID)
        let controlID = "reply-\(UUID().uuidString)"
        button.identifier = NSUserInterfaceItemIdentifier(controlID)
        replyCandidatesByControlID[controlID] = key
        destination.addArrangedSubview(button)
    }

    @objc private func selectReplyTarget(_ sender: NSButton) {
        guard !lockState, let controlID = sender.identifier?.rawValue,
              let target = replyCandidatesByControlID[controlID],
              target.conversation == currentConversationKey() else { return }
        replyTargetsByConversation[target.conversation] = target.messageID
        refreshReplyStatus(for: target.conversation)
        composer.window?.makeFirstResponder(composer)
    }

    @objc private func clearReplyTarget() {
        guard let conversation = currentConversationKey() else { return }
        replyTargetsByConversation.removeValue(forKey: conversation)
        refreshReplyStatus(for: conversation)
    }

    private func refreshReplyStatus(for conversation: ConversationKey?) {
        guard let conversation, let messageID = replyTargetsByConversation[conversation] else {
            replyStatusLabel?.isHidden = true
            clearReplyButton?.isHidden = true
            return
        }
        let message = messagesByConversation[conversation]?.first(where: { ($0["id"] as? NSNumber)?.int64Value == messageID })
        let preview = message.map(messagePreview) ?? "Сообщение"
        replyStatusLabel.stringValue = "Ответ: \(preview)"
        replyStatusLabel.isHidden = false
        clearReplyButton.isHidden = false
    }

    private func messagePreview(_ message: [String: Any]) -> String {
        guard let content = message["content"] as? [String: Any] else { return "Сообщение" }
        if content["@type"] as? String == "messageText",
           let text = content["text"] as? [String: Any] { return text["text"] as? String ?? "Текстовое сообщение" }
        return IncomingMessagePresentation.chatPreview(for: content["@type"] as? String ?? "")
    }

    private func clearStack(_ stack: NSStackView) {
        if stack === chatList { searchResultByControlID.removeAll() }
        if stack === messageList {
            visibleReadReceiptTask?.cancel()
            visibleReadReceiptTask = nil
            messageReadViewsByID.removeAll()
            messageActionTargetsByControlID.removeAll()
            messageActionButtonsByControlID.removeAll()
            photoPresentationGeneration &+= 1
            photoTokens.values.forEach(photoPipeline.cancelPreview)
            photoTokens.removeAll()
            photoViews.removeAll()
            photoButtons.removeAll()
            photoActionKeysByControlID.removeAll()
            photoLocalURLs.removeAll()
            photoOriginalFileIDs.removeAll()
            photoOriginalCanBeDownloaded.removeAll()
            photoOriginalLocalURLs.removeAll()
            photoOriginalKeysByFileID.removeAll()
            replyCandidatesByControlID.removeAll()
            if let account = runtime?.account, let chatID = selectedChatByAccount[account] {
                pendingPhotoByExtra = pendingPhotoByExtra.filter { $0.value.account == account && $0.value.chatID == chatID }
            } else {
                pendingPhotoByExtra.removeAll()
            }
            if let account = runtime?.account, let chatID = selectedChatByAccount[account] {
                pendingOriginalPhotoByExtra = pendingOriginalPhotoByExtra.filter { $0.value.account == account && $0.value.chatID == chatID }
                requestedOriginalPhotos = Set(requestedOriginalPhotos.filter { $0.account == account && $0.chatID == chatID })
            } else {
                pendingOriginalPhotoByExtra.removeAll()
                requestedOriginalPhotos.removeAll()
            }
        }
        for view in stack.arrangedSubviews {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }

    /// Drops app-owned previews and notification routes when TDLib reports a
    /// message deletion/expiry or replaces its content. TDLib remains the sole
    /// owner of its own database and downloaded-file lifecycle.
    private func purgeMessagePresentationState(account: AccountUUID, chatID: Int64, messageIDs: Set<Int64>) {
        guard !messageIDs.isEmpty else { return }
        let matches: (PhotoPresentationKey) -> Bool = {
            $0.account == account && $0.chatID == chatID && messageIDs.contains($0.messageID)
        }
        let keys = Set(photoViews.keys.filter(matches))
        let fileIDs = Set(keys.compactMap { photoOriginalFileIDs[$0] })
            .union(photoOriginalKeysByFileID[account]?.compactMap { fileID, keys in
                keys.contains(where: matches) ? fileID : nil
            } ?? [])

        photoPipeline.removeCachedPreviews(for: account, chatID: chatID, messageIDs: messageIDs)
        if let key = photoViewerKey, matches(key) { closePhotoViewer() }
        for key in keys {
            photoTokens.removeValue(forKey: key).map(photoPipeline.cancelPreview)
            if let imageView = photoViews.removeValue(forKey: key) {
                imageView.image = nil
                imageView.removeFromSuperview()
            }
            photoButtons.removeValue(forKey: key)?.removeFromSuperview()
            photoLocalURLs.removeValue(forKey: key)
            photoOriginalFileIDs.removeValue(forKey: key)
            photoOriginalCanBeDownloaded.removeValue(forKey: key)
            photoOriginalLocalURLs.removeValue(forKey: key)
        }
        photoActionKeysByControlID = photoActionKeysByControlID.filter { !matches($0.value) }
        if var originalKeys = photoOriginalKeysByFileID[account] {
            for fileID in Array(originalKeys.keys) {
                originalKeys[fileID] = originalKeys[fileID]?.filter { !matches($0) }
                if originalKeys[fileID]?.isEmpty == true {
                    originalKeys.removeValue(forKey: fileID)
                }
            }
            if originalKeys.isEmpty { photoOriginalKeysByFileID.removeValue(forKey: account) }
            else { photoOriginalKeysByFileID[account] = originalKeys }
        }
        pendingPhotoByExtra = pendingPhotoByExtra.filter { !matches($0.value) }
        pendingOriginalPhotoByExtra = pendingOriginalPhotoByExtra.filter { !matches($0.value) }
        requestedOriginalPhotos = requestedOriginalPhotos.filter { !matches($0) }
        photoDownloadsByConversation[ConversationKey(account: account, chatID: chatID)]?.subtract(fileIDs)
        pendingSponsoredPhotoByExtra = pendingSponsoredPhotoByExtra.filter {
            $0.value.account != account || $0.value.chatID != chatID || !messageIDs.contains($0.value.messageID)
        }
        sponsoredPhotoURLs = sponsoredPhotoURLs.filter {
            $0.key.account != account || $0.key.chatID != chatID || !messageIDs.contains($0.key.messageID)
        }
    }

    private func appendPhotoMessage(_ message: [String: Any], content: [String: Any], into destination: NSStackView, width: CGFloat) {
        guard let runtime, let chatID = (message["chat_id"] as? NSNumber)?.int64Value,
              let messageID = (message["id"] as? NSNumber)?.int64Value,
              let photo = content["photo"] as? [String: Any],
              let sizes = photo["sizes"] as? [[String: Any]],
              let variant = PhotoSizeCatalog.preview(from: sizes),
              let original = PhotoSizeCatalog.original(from: sizes) else {
            appendUnsupportedPhotoContext(message, reason: "Фото недоступно", into: destination)
            return
        }
        let canBeSaved = message["can_be_saved"] as? Bool
        let isSecret = content["is_secret"] as? Bool ?? false
        let expires = (message["self_destruct_in"] as? NSNumber)?.doubleValue ?? 0
        let isPaid = ((message["paid_message_star_count"] as? NSNumber)?.int64Value ?? 0) > 0
        if canBeSaved == false || isSecret || expires > 0 || isPaid {
            appendUnsupportedPhotoContext(message, reason: "Фото скрыто ограничением Telegram для этого сообщения", into: destination)
            return
        }
        let key = PhotoPresentationKey(account: runtime.account, chatID: chatID, messageID: messageID, fileID: variant.fileID)
        photoOriginalFileIDs[key] = original.fileID
        photoOriginalCanBeDownloaded[key] = original.canBeDownloaded
        photoOriginalKeysByFileID[runtime.account, default: [:]][original.fileID, default: []].insert(key)
        let imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: width, height: width * 0.75))
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.setAccessibilityLabel("Фотография из сообщения")
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: width),
            imageView.heightAnchor.constraint(equalToConstant: width * 0.75),
        ])
        photoViews[key] = imageView
        destination.addArrangedSubview(imageView)

        if let caption = content["caption"] as? [String: Any],
           let text = caption["text"] as? String,
           !text.isEmpty,
           let textView = incomingMessageTextView(
            formattedText: caption,
            prefix: "",
            maximumWidth: width
           ) {
            destination.addArrangedSubview(textView)
        }

        if variant.isDownloaded, let path = variant.localPath, !path.isEmpty {
            photoLocalURLs[key] = URL(fileURLWithPath: path)
        }
        if original.isDownloaded, let path = original.localPath, !path.isEmpty {
            photoOriginalLocalURLs[key] = URL(fileURLWithPath: path)
        }
        let alreadyDownloaded = photoLocalURLs[key] != nil
        let button = NSButton(title: alreadyDownloaded ? "Показать фото" : "Загрузить фото", target: self, action: #selector(downloadPhoto(_:)))
        button.tag = Int(variant.fileID)
        let controlID = "photo-\(chatID)-\(messageID)-\(variant.fileID)"
        button.identifier = NSUserInterfaceItemIdentifier(controlID)
        button.setAccessibilityLabel(alreadyDownloaded ? "Показать фотографию" : "Загрузить фотографию")
        photoButtons[key] = button
        photoActionKeysByControlID[controlID] = key
        destination.addArrangedSubview(button)
        if !alreadyDownloaded, !variant.canBeDownloaded {
            button.isEnabled = false
            button.title = "Фото сейчас недоступно"
        }
    }

    @objc private func downloadPhoto(_ sender: NSButton) {
        guard !lockState, let runtime,
              let chatID = selectedChatByAccount[runtime.account],
              let fileID = Int32(exactly: sender.tag),
              photoViews.keys.contains(where: { $0.account == runtime.account && $0.chatID == chatID && $0.fileID == fileID }) else { return }
        do {
            guard let key = photoViews.keys.first(where: { $0.account == runtime.account && $0.chatID == chatID && $0.fileID == fileID }) else { return }
            if let localURL = photoLocalURLs[key] {
                requestPhotoPreview(key, fileURL: localURL)
                sender.isEnabled = false
                sender.title = "Обрабатываю фото…"
                return
            }
            let conversation = ConversationKey(account: key.account, chatID: key.chatID)
            let activeFiles = photoDownloadsByConversation.values.reduce(0) { $0 + $1.count }
            if !photoDownloadsByConversation[conversation, default: []].contains(fileID), activeFiles >= 4 {
                setStatus("Уже загружаются четыре фотографии. Повторите позже.")
                return
            }
            historyRequestCounter &+= 1
            let extra = "photo-\(historyRequestCounter)"
            pendingPhotoByExtra[extra] = key
            photoDownloadsByConversation[conversation, default: []].insert(fileID)
            try runtime.send(["@type": "downloadFile", "file_id": fileID, "priority": 16, "offset": 0, "limit": 0, "synchronous": false, "@extra": extra])
            sender.isEnabled = false
            sender.title = "Загружаю фото…"
        } catch {
            let conversation = ConversationKey(account: runtime.account, chatID: chatID)
            photoDownloadsByConversation[conversation]?.remove(fileID)
            pendingPhotoByExtra = pendingPhotoByExtra.filter {
                $0.value.account != runtime.account || $0.value.chatID != chatID || $0.value.fileID != fileID
            }
            sender.isEnabled = true
            sender.title = "Повторить загрузку фото"
            setStatus("Не удалось начать загрузку фотографии.")
        }
    }

    @objc private func openPhotoOriginal(_ sender: NSButton) {
        guard !lockState,
              let controlID = sender.identifier?.rawValue,
              let key = photoActionKeysByControlID[controlID],
              let accountRuntime = runtimesByAccount[key.account],
              runtime === accountRuntime,
              selectedChatByAccount[key.account] == key.chatID,
              photoViews[key] != nil,
              let originalFileID = photoOriginalFileIDs[key] else { return }

        if let localURL = photoOriginalLocalURLs[key] ?? (originalFileID == key.fileID ? photoLocalURLs[key] : nil) {
            openPhotoViewer(key, fileURL: localURL)
            return
        }
        guard photoOriginalCanBeDownloaded[key] == true else {
            setStatus("Полный размер этого фото сейчас недоступен.")
            return
        }
        if requestedOriginalPhotos.contains(key) {
            setStatus("Загружаю полный размер фотографии…")
            return
        }
        let conversation = ConversationKey(account: key.account, chatID: key.chatID)
        let activeFiles = photoDownloadsByConversation.values.reduce(0) { $0 + $1.count }
        let alreadyDownloading = photoDownloadsByConversation[conversation, default: []].contains(originalFileID)
        if !alreadyDownloading, activeFiles >= 4 {
            setStatus("Уже загружаются четыре фотографии. Повторите позже.")
            return
        }

        requestedOriginalPhotos.insert(key)
        sender.isEnabled = false
        sender.title = "Загружаю полный размер…"
        photoDownloadsByConversation[conversation, default: []].insert(originalFileID)
        if alreadyDownloading { return }
        historyRequestCounter &+= 1
        let extra = "photo-original-\(historyRequestCounter)"
        pendingOriginalPhotoByExtra[extra] = key
        do {
            try accountRuntime.send([
                "@type": "downloadFile", "file_id": originalFileID, "priority": 16,
                "offset": 0, "limit": 0, "synchronous": false, "@extra": extra,
            ])
        } catch {
            pendingOriginalPhotoByExtra.removeValue(forKey: extra)
            requestedOriginalPhotos.remove(key)
            photoDownloadsByConversation[conversation]?.remove(originalFileID)
            sender.isEnabled = true
            sender.title = "Повторить полный размер"
            setStatus("Не удалось начать загрузку полного размера.")
        }
    }

    private func openPhotoViewer(_ key: PhotoPresentationKey, fileURL: URL) {
        guard !lockState, runtime?.account == key.account,
              selectedChatByAccount[key.account] == key.chatID,
              photoViews[key] != nil else { return }
        closePhotoViewer()
        let viewGeneration = photoPresentationGeneration
        let privacyEpoch = privacyDispatchBarrier.currentEpoch()
        photoViewerKey = key
        photoViewerPrivacyEpoch = privacyEpoch
        photoButtons[key]?.isEnabled = false
        photoButtons[key]?.title = "Открываю фотографию…"
        let token = photoPipeline.requestPreview(
            account: key.account,
            chatID: key.chatID,
            messageID: key.messageID,
            fileID: photoOriginalFileIDs[key] ?? key.fileID,
            fileURL: fileURL,
            maxPixelSize: 4096
        ) { [weak self] _, data in
            Task { @MainActor [weak self] in
                guard let self, !self.lockState,
                      self.photoPresentationGeneration == viewGeneration,
                      self.privacyDispatchBarrier.currentEpoch() == privacyEpoch,
                      self.runtime?.account == key.account,
                      self.selectedChatByAccount[key.account] == key.chatID,
                      self.photoViewerKey == key else { return }
                guard let data, let image = NSImage(data: data) else {
                    self.photoViewerKey = nil
                    self.photoViewerPrivacyEpoch = nil
                    self.photoButtons[key]?.isEnabled = true
                    self.photoButtons[key]?.title = "Повторить полный размер"
                    self.setStatus("Не удалось подготовить фотографию для просмотра.")
                    return
                }
                self.presentPhotoViewer(image)
                self.photoViewerToken = nil
                self.photoButtons[key]?.isEnabled = true
                self.photoButtons[key]?.title = "Полный размер"
            }
        }
        photoViewerToken = token
    }

    private func presentPhotoViewer(_ image: NSImage) {
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 680))
        content.autoresizingMask = [.width, .height]
        let imageView = NSImageView(frame: content.bounds)
        imageView.autoresizingMask = [.width, .height]
        imageView.imageScaling = .scaleProportionallyDown
        imageView.image = image
        imageView.setAccessibilityLabel("Фотография в полном размере")
        content.addSubview(imageView)
        let viewer = NSWindow(contentRect: content.frame, styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        viewer.title = "Фотография"
        viewer.contentView = content
        viewer.minSize = NSSize(width: 480, height: 360)
        viewer.delegate = self
        photoViewerImageView = imageView
        photoViewerWindow = viewer
        viewer.center()
        viewer.makeKeyAndOrderFront(nil)
    }

    private func closePhotoViewer() {
        let viewer = photoViewerWindow
        let imageView = photoViewerImageView
        let token = photoViewerToken
        if let key = photoViewerKey { requestedOriginalPhotos.remove(key) }
        photoViewerWindow = nil
        photoViewerImageView = nil
        photoViewerKey = nil
        photoViewerPrivacyEpoch = nil
        photoViewerToken = nil
        imageView?.image = nil
        if let token { photoPipeline.cancelPreview(token) }
        viewer?.close()
    }

    private func presentDownloadedPhoto(_ file: [String: Any], from target: LocalAccountRuntime) {
        guard !lockState,
              let fileID = (file["id"] as? NSNumber)?.int32Value,
              let local = file["local"] as? [String: Any],
              local["is_downloading_completed"] as? Bool == true,
              let path = local["path"] as? String, !path.isEmpty,
              let chatID = selectedChatByAccount[target.account] else { return }
        let url = URL(fileURLWithPath: path)
        photoDownloadsByConversation[ConversationKey(account: target.account, chatID: chatID)]?.remove(fileID)
        var completedSponsoredPhoto = false
        var sponsoredPresentationKeys: Set<PhotoPresentationKey> = []
        for (extra, key) in pendingSponsoredPhotoByExtra.filter({ $0.value.account == target.account && $0.value.chatID == chatID && $0.value.fileID == fileID }) {
            pendingSponsoredPhotoByExtra.removeValue(forKey: extra)
            sponsoredPhotoURLs[key] = url
            sponsoredPresentationKeys.insert(PhotoPresentationKey(account: key.account, chatID: key.chatID, messageID: key.messageID, fileID: key.fileID))
            completedSponsoredPhoto = true
        }
        if completedSponsoredPhoto, target === runtime,
           selectedChatByAccount[target.account] == chatID,
           currentConversationKey() == currentConversationKey(for: target.account, chatID: chatID) {
            let conversation = currentConversationKey(for: target.account, chatID: chatID)
            clearStack(messageList)
            renderMessages(messagesByConversation[conversation] ?? [])
        }
        pendingPhotoByExtra = pendingPhotoByExtra.filter {
            $0.value.account != target.account || $0.value.chatID != chatID || $0.value.fileID != fileID
        }
        for key in photoViews.keys where key.account == target.account && key.chatID == chatID && key.fileID == fileID && !sponsoredPresentationKeys.contains(key) {
            photoLocalURLs[key] = url
            photoButtons[key]?.title = "Показать фото"
            photoButtons[key]?.isEnabled = true
            if local["is_downloading_active"] as? Bool == true, let button = photoButtons[key] {
                button.title = "Загружаю фото…"
            }
            requestPhotoPreview(key, fileURL: url)
        }
        let originalKeys = photoOriginalKeysByFileID[target.account]?[fileID] ?? []
        for key in originalKeys where key.chatID == chatID {
            photoOriginalLocalURLs[key] = url
            pendingOriginalPhotoByExtra = pendingOriginalPhotoByExtra.filter { $0.value != key }
            photoDownloadsByConversation[ConversationKey(account: key.account, chatID: key.chatID)]?.remove(fileID)
            guard requestedOriginalPhotos.contains(key),
                  let button = photoButtons[key], !lockState else { continue }
            button.isEnabled = true
            button.title = "Открываю полный размер…"
            openPhotoViewer(key, fileURL: url)
        }
    }

    private func requestPhotoPreview(_ key: PhotoPresentationKey, fileURL: URL) {
        guard let runtime, runtime.account == key.account,
              selectedChatByAccount[key.account] == key.chatID,
              photoViews[key] != nil, !lockState else { return }
        let viewGeneration = photoPresentationGeneration
        let privacyEpoch = privacyDispatchBarrier.currentEpoch()
        let token = photoPipeline.requestPreview(
            account: key.account,
            chatID: key.chatID,
            messageID: key.messageID,
            fileID: key.fileID,
            fileURL: fileURL,
            maxPixelSize: 960
        ) { [weak self] _, data in
            Task { @MainActor [weak self] in
                guard let self, !self.lockState,
                      self.photoPresentationGeneration == viewGeneration,
                      self.privacyDispatchBarrier.currentEpoch() == privacyEpoch,
                      self.runtime?.account == key.account,
                      self.selectedChatByAccount[key.account] == key.chatID,
                      let imageView = self.photoViews[key] else { return }
                guard let data, let image = NSImage(data: data) else {
                    self.photoButtons[key]?.isEnabled = true
                    self.photoButtons[key]?.title = "Повторить показ фото"
                    self.photoTokens.removeValue(forKey: key)
                    return
                }
                imageView.image = image
                self.photoTokens.removeValue(forKey: key)
                if self.photoOriginalFileIDs[key] != nil,
                   self.photoOriginalCanBeDownloaded[key] == true || self.photoOriginalLocalURLs[key] != nil {
                    self.photoButtons[key]?.action = #selector(self.openPhotoOriginal(_:))
                    self.photoButtons[key]?.title = "Полный размер"
                    self.photoButtons[key]?.setAccessibilityLabel("Открыть фотографию в полном размере")
                    self.photoButtons[key]?.isEnabled = true
                    self.photoButtons[key]?.isHidden = false
                } else {
                    self.photoButtons[key]?.isHidden = true
                }
            }
        }
        photoTokens[key] = token
    }

    private func appendUnsupportedPhotoContext(_ message: [String: Any], reason: String, into destination: NSStackView? = nil) {
        let from = (message["sender_id"] as? [String: Any])?["@type"] as? String == "messageSenderUser" ? "Фото от пользователя" : "Фото в переписке"
        let label = NSTextField(wrappingLabelWithString: "\(from): \(reason)")
        label.font = .systemFont(ofSize: 13)
        label.maximumNumberOfLines = 0
        (destination ?? messageList).addArrangedSubview(label)
    }

    private func cancelPhotoDownloads(account: AccountUUID, chatID: Int64) {
        let conversation = ConversationKey(account: account, chatID: chatID)
        guard let fileIDs = photoDownloadsByConversation.removeValue(forKey: conversation),
              let accountRuntime = runtimesByAccount[account] else { return }
        for fileID in fileIDs {
            try? accountRuntime.send(["@type": "cancelDownloadFile", "file_id": fileID, "only_if_pending": false])
        }
        pendingPhotoByExtra = pendingPhotoByExtra.filter { $0.value.account != account || $0.value.chatID != chatID }
        pendingOriginalPhotoByExtra = pendingOriginalPhotoByExtra.filter { $0.value.account != account || $0.value.chatID != chatID }
        pendingSponsoredPhotoByExtra = pendingSponsoredPhotoByExtra.filter { $0.value.account != account || $0.value.chatID != chatID }
        requestedSponsoredPhotos = Set(requestedSponsoredPhotos.filter { $0.account != account || $0.chatID != chatID })
        requestedOriginalPhotos = Set(requestedOriginalPhotos.filter { $0.account != account || $0.chatID != chatID })
    }

    private func cancelAllPhotoDownloads() {
        for conversation in Array(photoDownloadsByConversation.keys) {
            cancelPhotoDownloads(account: conversation.account, chatID: conversation.chatID)
        }
        pendingOriginalPhotoByExtra.removeAll()
        requestedOriginalPhotos.removeAll()
    }

    private func showAuthenticatedChatUI() {
        guard targetIsAuthorizedSelected() else { return }
        setAuthCardVisible(false)
        chatPane.isHidden = false
        window.title = identifiedWindowTitle(runtime.flatMap(safeAccountName).map { "\($0) — \(ProductIdentity.displayName)" } ?? ProductIdentity.displayName)
    }

    private func targetIsAuthorizedSelected() -> Bool { runtime?.telegramUserID != nil }

    private func safeAccountName(_ runtime: LocalAccountRuntime) -> String? {
        AccountPresentation.verifiedDisplayName(
            telegramUserID: runtime.telegramUserID,
            candidate: runtime.displayName
        )
    }

    private func identifiedWindowTitle(_ title: String) -> String {
        DevelopmentBuildIdentity.windowTitle(
            title,
            bundleIdentifier: Bundle.main.bundleIdentifier,
            sourceCommit: Bundle.main.object(forInfoDictionaryKey: "NeTelegramDevelopmentCommit") as? String,
            hasUncommittedChanges: (Bundle.main.object(forInfoDictionaryKey: "NeTelegramDevelopmentDirty") as? NSNumber)?.boolValue ?? false
        )
    }

    private func parametersRequest(for runtime: LocalAccountRuntime) -> [String: Any] {
        return [
            "@type": "setTdlibParameters",
            "database_directory": runtime.paths.database.path,
            "files_directory": runtime.paths.files.path,
            "database_encryption_key": runtime.databaseKey.base64EncodedString(),
            "use_message_database": true,
            "use_chat_info_database": true,
            "use_file_database": true,
            "use_secret_chats": false,
            "api_id": TelegramApplicationIdentity.apiID,
            "api_hash": runtime.apiHash,
            "system_language_code": Locale.current.language.languageCode?.identifier ?? "en",
            "device_model": "Mac",
            "system_version": ProcessInfo.processInfo.operatingSystemVersionString,
            "application_version": "0.1-development",
            "enable_storage_optimizer": true,
        ]
    }

    private func showAuthInput(_ message: String, placeholder: String, button: String) {
        setAuthCardVisible(true)
        phoneField.stringValue = ""
        setStatus(message)
        loginHeading.stringValue = pendingAuthorizationType == "authorizationStateWaitCode" ? "Введите код" : "Подтверждение входа"
        loginSubtitle.stringValue = message
        registrationTermsScroll.isHidden = true
        countryPicker.isHidden = true
        phoneField.isHidden = true
        emailField.isHidden = true
        firstNameField.isHidden = true
        lastNameField.isHidden = true
        registrationConsent.isHidden = true
        qrImageView.isHidden = true
        if pendingAuthorizationType != "authorizationStateWaitCode" && pendingAuthorizationType != "authorizationStateWaitEmailCode" {
            inputField.stringValue = ""
        }
        inputField.placeholderString = placeholder
        let secure = pendingAuthorizationType == "authorizationStateWaitPassword"
        secureInputField.stringValue = ""
        inputField.isHidden = secure
        secureInputField.placeholderString = placeholder
        secureInputField.isHidden = !secure
        qrButton.isHidden = true
        actionButton.isHidden = false
        actionButton.title = button
        actionButton.isEnabled = !authRequestInFlight
        if secure { secureInputField.becomeFirstResponder() } else { inputField.becomeFirstResponder() }
    }

    private func showQRConfirmation(_ auth: [String: Any]) {
        showingQR = true
        setAuthCardVisible(true)
        loginHeading.stringValue = "Вход по QR-коду"
        loginSubtitle.stringValue = "Откройте Telegram на телефоне → Настройки → Устройства → Подключить устройство и отсканируйте код."
        registrationTermsScroll.isHidden = true
        countryPicker.isHidden = true
        phoneField.isHidden = true
        phoneField.stringValue = ""
        emailField.isHidden = true
        emailField.stringValue = ""
        inputField.isHidden = true
        inputField.stringValue = ""
        secureInputField.isHidden = true
        secureInputField.stringValue = ""
        firstNameField.isHidden = true
        lastNameField.isHidden = true
        registrationConsent.isHidden = true
        if let link = auth["link"] as? String {
            if let image = qrImage(for: link) {
                qrImageView.image = image
                qrImageView.isHidden = false
                setStatus("Подтвердите вход на своём телефоне.")
            } else {
                qrImageView.image = nil
                qrImageView.isHidden = true
                setStatus("Не удалось сформировать QR-код. Попробуйте позже.")
            }
        } else {
            qrImageView.image = nil
            qrImageView.isHidden = true
            setStatus("Ожидаю обновлённую ссылку для входа по QR-коду.")
        }
        actionButton.isHidden = true
        actionButton.isEnabled = false
        qrButton.isHidden = true
    }

    private func presentAuthorizationState(_ authorizationType: String?, info: [String: Any]) {
        setAuthCardVisible(true)
        chatPane.isHidden = true
        if authorizationType != nil,
           authorizationType != "authorizationStateWaitTdlibParameters",
           authorizationType != "authorizationStateWaitPhoneNumber" {
            pendingInitialAuthorizationAction = nil
        }
        if authorizationType != "authorizationStateWaitOtherDeviceConfirmation" {
            qrImageView.image = nil
            qrImageView.isHidden = true
        }
        switch authorizationType {
        case nil:
            showAuthorizationProgress(title: "Подключаем профиль", subtitle: "Ожидаю состояние авторизации от TDLib…")
        case "authorizationStateWaitTdlibParameters":
            showAuthorizationProgress(title: "Подготавливаем вход", subtitle: "Настраиваю локальную базу аккаунта…")
        case "authorizationStateWaitPhoneNumber": showPhoneEntry()
        case "authorizationStateWaitCode": showAuthInput("Введите код, полученный для этого входа.", placeholder: "Код", button: "Продолжить")
        case "authorizationStateWaitPassword": showAuthInput("Введите пароль двухэтапной проверки. Он не сохраняется.", placeholder: "Пароль двухэтапной проверки", button: "Продолжить")
        case "authorizationStateWaitEmailAddress": showEmailEntry()
        case "authorizationStateWaitEmailCode": showEmailCode(info)
        case "authorizationStateWaitRegistration": showRegistration(info)
        case "authorizationStateWaitOtherDeviceConfirmation": showQRConfirmation(info)
        case "authorizationStateWaitPremiumPurchase": showUnsupportedAuthorization(authorizationType)
        case "authorizationStateReady":
            showAuthorizationProgress(title: "Проверяем аккаунт", subtitle: "Проверяю серверную identity профиля…")
        case "authorizationStateLoggingOut": showLogoutProgress()
        case "authorizationStateClosing":
            let subtitle = closingForTermination
                ? "Завершаю работу: TDLib закрывает аккаунты и сохраняет базы…"
                : "Закрываю профиль и сохраняю локальную базу…"
            showAuthorizationProgress(title: "Закрываем профиль", subtitle: subtitle)
        case "authorizationStateClosed":
            showAuthorizationProgress(title: "Профиль закрыт", subtitle: "Состояние профиля сохранено.")
        default: showUnsupportedAuthorization(authorizationType)
        }
    }

    private func showAuthorizationProgress(title: String, subtitle: String) {
        showingQR = false
        setAuthCardVisible(true)
        chatPane.isHidden = true
        loginHeading.stringValue = title
        loginSubtitle.stringValue = subtitle
        phoneField.stringValue = ""
        phoneField.isHidden = true
        countryPicker.isHidden = true
        emailField.stringValue = ""
        emailField.isHidden = true
        inputField.stringValue = ""
        inputField.isHidden = true
        secureInputField.stringValue = ""
        secureInputField.isHidden = true
        firstNameField.stringValue = ""
        firstNameField.isHidden = true
        lastNameField.stringValue = ""
        lastNameField.isHidden = true
        registrationConsent.state = .off
        registrationConsent.isHidden = true
        registrationTermsAvailable = false
        registrationTermsScroll.isHidden = true
        qrImageView.image = nil
        qrImageView.isHidden = true
        actionButton.isEnabled = false
        actionButton.isHidden = true
        qrButton.isEnabled = true
        qrButton.isHidden = true
        setStatus(subtitle)
    }

    private func showUnsupportedAuthorization(_ authorizationType: String?) {
        let availability = AuthorizationStep(tdlibType: authorizationType).uiAvailability
        let purchaseRequired = availability == .purchaseNotAvailable
        showAuthorizationProgress(
            title: purchaseRequired ? "Для входа требуется покупка" : "Шаг входа не поддерживается",
            subtitle: purchaseRequired
                ? "Telegram запрашивает покупку Premium. \(ProductIdentity.displayName) не проводит покупки; для этого профиля вход остановлен."
                : "Telegram сообщил неизвестный шаг авторизации. Ввод временно выключен, сохранённые данные профиля не изменены."
        )
    }

    private func showEmailEntry() {
        setAuthCardVisible(true)
        registrationTermsScroll.isHidden = true
        phoneField.stringValue = ""
        inputField.stringValue = ""
        secureInputField.stringValue = ""
        firstNameField.stringValue = ""
        lastNameField.stringValue = ""
        loginHeading.stringValue = "Вход по электронной почте"
        loginSubtitle.stringValue = "Введите адрес, привязанный к аккаунту. Мы отправим на него код."
        countryPicker.isHidden = true
        phoneField.isHidden = true
        emailField.isHidden = false
        inputField.isHidden = true
        secureInputField.isHidden = true
        firstNameField.isHidden = true
        lastNameField.isHidden = true
        registrationConsent.isHidden = true
        qrImageView.isHidden = true
        qrButton.isHidden = true
        actionButton.isHidden = false
        actionButton.title = "Продолжить"
        actionButton.isEnabled = !authRequestInFlight
        emailField.becomeFirstResponder()
        setStatus(loginSubtitle.stringValue)
    }

    private func showEmailCode(_ auth: [String: Any]) {
        let codeInfo = auth["code_info"] as? [String: Any] ?? [:]
        let pattern = codeInfo["email_address_pattern"] as? String
        let message = pattern.map { "Введите код из письма на адрес \($0)." } ?? "Введите код, отправленный на вашу электронную почту."
        emailField.stringValue = ""
        showAuthInput(message, placeholder: "Код из письма", button: "Продолжить")
        loginHeading.stringValue = "Проверьте почту"
    }

    private func showRegistration(_ auth: [String: Any]) {
        setAuthCardVisible(true)
        phoneField.stringValue = ""
        emailField.stringValue = ""
        inputField.stringValue = ""
        secureInputField.stringValue = ""
        loginHeading.stringValue = "Создание аккаунта"
        let terms = ((auth["terms_of_service"] as? [String: Any])?["text"] as? [String: Any])?["text"] as? String
        if let terms, !terms.isEmpty {
            loginSubtitle.stringValue = "Этот номер ещё не зарегистрирован. Укажите имя и прочитайте условия, чтобы продолжить."
            registrationTermsTextView.string = terms
            registrationTermsAvailable = true
        } else {
            loginSubtitle.stringValue = "TDLib не передал текст условий регистрации. Завершение создания аккаунта временно недоступно."
            registrationTermsTextView.string = "Условия регистрации не получены. Проверьте соединение и повторите попытку."
            registrationTermsAvailable = false
        }
        registrationTermsScroll.isHidden = false
        countryPicker.isHidden = true
        phoneField.isHidden = true
        emailField.isHidden = true
        inputField.isHidden = true
        secureInputField.isHidden = true
        firstNameField.isHidden = false
        lastNameField.isHidden = false
        registrationConsent.isHidden = false
        registrationConsent.state = .off
        registrationConsent.isEnabled = registrationTermsAvailable
        qrImageView.isHidden = true
        qrButton.isHidden = true
        actionButton.isHidden = false
        actionButton.title = "Продолжить"
        actionButton.isEnabled = !authRequestInFlight && registrationTermsAvailable && registrationConsent.state == .on
        firstNameField.stringValue = ""
        lastNameField.stringValue = ""
        firstNameField.becomeFirstResponder()
        setStatus("Telegram запрашивает данные для создания нового аккаунта.")
    }

    private func passwordPrompt(_ auth: [String: Any]) -> String {
        let hint = (auth["password_hint"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return hint.isEmpty
            ? "Введите пароль двухэтапной проверки. Он не сохраняется."
            : "Подсказка пароля: \(hint). Введите пароль двухэтапной проверки."
    }

    private func authPresentationInfo(for auth: [String: Any]) -> [String: Any] {
        switch auth["@type"] as? String {
        case "authorizationStateWaitCode":
            let type = ((auth["code_info"] as? [String: Any])?["type"] as? [String: Any])?["@type"] as? String
            return type.map { ["code_info": ["type": ["@type": $0]]] } ?? [:]
        case "authorizationStateWaitPassword":
            return (auth["password_hint"] as? String).map { ["password_hint": $0] } ?? [:]
        case "authorizationStateWaitEmailCode":
            let pattern = (auth["code_info"] as? [String: Any])?["email_address_pattern"] as? String
            return pattern.map { ["code_info": ["email_address_pattern": $0]] } ?? [:]
        case "authorizationStateWaitRegistration":
            return (auth["terms_of_service"] as? [String: Any]).map { ["terms_of_service": $0] } ?? [:]
        case "authorizationStateWaitOtherDeviceConfirmation":
            return (auth["link"] as? String).map { ["link": $0] } ?? [:]
        default:
            return [:]
        }
    }

    @objc private func toggleRegistrationConsent() {
        guard pendingAuthorizationType == "authorizationStateWaitRegistration", !authRequestInFlight else { return }
        actionButton.isEnabled = registrationTermsAvailable && registrationConsent.state == .on
    }

    private func authCodeDescription(_ auth: [String: Any]) -> String {
        let codeInfo = auth["code_info"] as? [String: Any] ?? [:]
        let kind = (codeInfo["type"] as? [String: Any])?["@type"] as? String
        let phoneNumber = codeInfo["phone_number"] as? String
        return AuthenticationCodePrompt.message(codeType: kind, phoneNumber: phoneNumber)
    }

    private func showPhoneEntry() {
        setAuthCardVisible(true)
        registrationTermsScroll.isHidden = true
        emailField.stringValue = ""
        emailField.isHidden = true
        firstNameField.isHidden = true
        lastNameField.isHidden = true
        registrationConsent.isHidden = true
        inputField.stringValue = ""
        secureInputField.stringValue = ""
        loginHeading.stringValue = "Добро пожаловать"
        loginSubtitle.stringValue = "Введите номер телефона, чтобы войти в свой аккаунт."
        countryPicker.isHidden = phoneCountries.isEmpty
        emailField.isHidden = true
        firstNameField.isHidden = true
        lastNameField.isHidden = true
        phoneField.placeholderString = phoneCountries.isEmpty ? "+код страны и номер" : "Номер телефона"
        phoneField.isHidden = false
        inputField.isHidden = true
        secureInputField.isHidden = true
        qrImageView.isHidden = true
        qrButton.isHidden = false
        qrButton.isEnabled = !authRequestInFlight
        actionButton.isHidden = false
        actionButton.title = "Продолжить"
        actionButton.isEnabled = !authRequestInFlight
        setStatus(phoneCountries.isEmpty
            ? "Введите полный номер с + и кодом страны. Загружаю список стран…"
            : "Выберите страну и введите номер телефона.")
        phoneField.becomeFirstResponder()
    }

    private func showLogoutProgress() {
        showAuthorizationProgress(
            title: "Выходим из аккаунта",
            subtitle: "Ожидаю подтверждения Telegram. Остальные аккаунты продолжают работать."
        )
        window.title = identifiedWindowTitle("Выход из аккаунта — \(ProductIdentity.displayName)")
        setStatus("Telegram завершает сеанс и удаляет локальные данные аккаунта…")
    }

    @objc private func selectCountry() {
        let index = countryPicker.indexOfSelectedItem
        guard phoneCountries.indices.contains(index) else { return }
        selectedCallingCode = phoneCountries[index].callingCodes[0]
    }

    @objc private func beginQRLogin() {
        guard !lockState else { return }
        guard pendingAuthorizationType == "authorizationStateWaitPhoneNumber" else {
            setStatus("Подождите, пока Telegram подготовит экран входа.")
            return
        }
        guard let runtime else {
            pendingInitialAuthorizationAction = .qrCode
            beginFirstAccount()
            return
        }
        do {
            historyRequestCounter &+= 1
            let extra = "auth-\(historyRequestCounter)"
            let account = runtime.account
            let generation = runtime.generation
            let privacyEpoch = privacyDispatchBarrier.currentEpoch()
            let dispatched = try privacyDispatchBarrier.dispatchAuthenticationCommand(
                account: account,
                runtimeGeneration: generation,
                privacyEpoch: privacyEpoch,
                currentAccount: runtime.account,
                currentGeneration: runtime.generation
            ) {
                try runtime.send(["@type": "requestQrCodeAuthentication", "other_user_ids": [], "@extra": extra])
            }
            guard dispatched else {
                setStatus("Вход по QR отменён: приложение заблокировано или профиль изменился.")
                return
            }
            authRequestInFlight = true
            qrButton.isEnabled = false
            pendingAuthRequestsByExtra[extra] = (runtime.account, "authorizationStateWaitPhoneNumber")
            setStatus("Запрашиваю QR-код…")
        } catch {
            authRequestInFlight = false
            qrButton.isEnabled = true
            setStatus("Не удалось запросить QR-код. Попробуйте вход по номеру телефона.")
        }
    }

    private func qrImage(for value: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage,
              let cgImage = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: 180, height: 180))
    }

    private func setStatus(_ value: String) {
        statusLabel?.stringValue = value
        chatStatusLabel?.stringValue = value
    }

    private func tdjsonLibraryURL() -> URL? {
        let candidates = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/tdlib-build/libtdjson.dylib"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Frameworks/libtdjson.dylib"),
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func showWindow() {
        window.makeKeyAndOrderFront(nil)
        if lockState { unlock() }
    }
    @objc private func openWindow() { showWindow() }
    @objc private func closeWindow() { window.performClose(nil) }
    @objc private func lock() {
        guard !lockState else { return }
        // Establish the lock transition before any presentation cleanup or
        // draft I/O. dispatch* holds the same barrier through td_send, so a
        // queued user command is either already accepted before this point or
        // rejected after it; it cannot slip through while drafts are flushed.
        privacyDispatchBarrier.setLocked(true)
        lockState = true
        stopTypingAction()
        visibleReadReceiptTask?.cancel()
        visibleReadReceiptTask = nil
        visibleReadReceiptRegistry.removeAll()
        messageReadViewsByID.removeAll()
        searchDebounceTask?.cancel()
        searchDebounceTask = nil
        searchGeneration &+= 1
        deferredSearch = nil
        activeSearchQuery = ""
        searchField.stringValue = ""
        searchResults.removeAll()
        searchResultByControlID.removeAll()
        pendingSearchRequests.removeAll()
        historyAnchorByConversation.removeAll()
        pendingMessagePropertiesByExtra.removeAll()
        pendingMessageMutationsByExtra.removeAll()
        messageEditDrafts.removeAll()
        messageActionTargetsByControlID.removeAll()
        messageActionButtonsByControlID.removeAll()
        if let alert = activeMessageActionAlert, let parent = alert.window.sheetParent {
            activeMessageEditor?.string = ""
            parent.endSheet(alert.window, returnCode: .cancel)
        }
        activeMessageActionAlert = nil
        activeMessageEditor = nil
        registrationTermsScroll.isHidden = true
        phoneField.stringValue = ""
        emailField.stringValue = ""
        inputField.stringValue = ""
        secureInputField.stringValue = ""
        firstNameField.stringValue = ""
        lastNameField.stringValue = ""
        pendingInitialAuthorizationAction = nil
        qrImageView.image = nil
        qrImageView.isHidden = true
        registrationConsent.state = .off
        for (account, info) in Array(authPresentationInfoByAccount) {
            if let terms = info["terms_of_service"] {
                authPresentationInfoByAccount[account] = ["terms_of_service": terms]
            } else {
                authPresentationInfoByAccount.removeValue(forKey: account)
            }
        }
        cancelAllPhotoDownloads()
        _ = flushDirtyDraftsBeforeQuit()
        lockedDirtyDraftRecovery = DraftPrivacyCache.lock(
            presentationDrafts: &draftsByConversation,
            dirtyAccounts: dirtyDraftAccounts
        )
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        // The lock clears any already-published preview. Reconcile the active
        // TDLib snapshot immediately with generic content so notifications do
        // not disappear until another update arrives.
        deliverActiveNotifications()
        inputField.stringValue = ""
        secureInputField.stringValue = ""
        inputField.isHidden = true
        secureInputField.isHidden = true
        actionButton.isEnabled = false
        chatPane.isHidden = true
        chatRowsByAccount.removeAll()
        chatOrderByAccount.removeAll()
        messagesByConversation.removeAll()
        replyTargetsByConversation.removeAll()
        replyStatusLabel.stringValue = ""
        replyStatusLabel.isHidden = true
        clearReplyButton.isHidden = true
        forumTopicsByAccount.removeAll()
        forumChatsByAccount.removeAll()
        selectedForumTopicIDsByAccount.removeAll()
        topicPicker.removeAllItems()
        topicPickerIDs.removeAll()
        topicPicker.isHidden = true
        sendEligibilityByAccount.removeAll()
        for accountRuntime in runtimesByAccount.values {
            accountRuntime.invalidateMainChatSnapshot()
        }
        pendingHistoryRequests.removeAll()
        sponsoredMessagesByKey.removeAll()
        sponsoredMessagesBetweenByKey.removeAll()
        sponsoredMessagesFetchedAt.removeAll()
        pendingSponsoredMessagesByExtra.removeAll()
        pendingSponsoredBotUsersByExtra.removeAll()
        pendingSponsoredReportsByExtra.removeAll()
        pendingSponsoredPhotoByExtra.removeAll()
        sponsoredPhotoURLs.removeAll()
        requestedSponsoredPhotos.removeAll()
        sponsoredActionByControlID.removeAll()
        sponsoredReportActionByControlID.removeAll()
        sponsoredPhotoRetryByControlID.removeAll()
        failedSponsoredPhotos.removeAll()
        pendingForumTopicsByExtra.removeAll()
        selectedChatByAccount.removeAll()
        clearStack(chatList)
        photoPipeline.cancelAllPreviews()
        closePhotoViewer()
        for account in runtimesByAccount.keys { photoPipeline.removeCachedPreviews(for: account) }
        clearStack(messageList)
        setComposerText("")
        refreshComposerState()
        lockedView.isHidden = false
        window.title = identifiedWindowTitle("Заблокировано — \(ProductIdentity.displayName)")
        // Reject queued or late UI intent before requesting system authentication.
        unlock()
    }

    @objc private func unlock() {
        guard lockState, !unlockInProgress else { return }
        let context = LAContext()
        context.localizedCancelTitle = "Остаться заблокированным"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            setLockedStatus("На этом Mac недоступна системная проверка владельца. Переписки остаются скрыты.")
            return
        }
        unlockInProgress = true
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Разблокировать \(ProductIdentity.displayName)") { [weak self] success, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.unlockInProgress = false
                guard self.lockState else {
                    self.notificationUnlockHandoff.clear()
                    return
                }
                guard success else {
                    self.notificationUnlockHandoff.clear()
                    return
                }
                DraftPrivacyCache.unlock(
                    presentationDrafts: &self.draftsByConversation,
                    lockedDirtyDrafts: &self.lockedDirtyDraftRecovery
                )
                self.lockState = false
                self.privacyDispatchBarrier.setLocked(false)
                self.lockedView.isHidden = true
                let pendingNotification = self.notificationUnlockHandoff.pending
                let pendingRuntime = pendingNotification.flatMap { self.runtimesByAccount[$0.notification.account] }
                if let route = self.notificationUnlockHandoff.resolve(
                    unlockSucceeded: true,
                    account: pendingRuntime?.account,
                    runtimeGeneration: pendingRuntime?.generation,
                    telegramUserID: pendingRuntime?.telegramUserID,
                    authorizationState: pendingRuntime?.authorizationState,
                    notificationIsCurrent: pendingNotification.map {
                        self.notificationTargets[$0.notification.systemIdentifier] == $0.notification
                    } ?? false
                ) {
                    self.openNotificationRoute(route)
                    return
                }
                if let selected = self.runtime,
                   AccountPresentation.restoresAuthenticatedChat(
                    telegramUserID: selected.telegramUserID,
                    authorizationState: self.pendingAuthorizationType
                   ) {
                    self.reloadPersistedDrafts(for: selected.account)
                    selected.loadMainChats(reload: true)
                    self.showAuthenticatedChatUI()
                    self.refreshChatList()
                    self.displaySelectedConversation()
                    self.window.title = self.identifiedWindowTitle(self.safeAccountName(selected).map { "\($0) — \(ProductIdentity.displayName)" } ?? ProductIdentity.displayName)
                } else if let selected = self.runtime {
                    self.presentAuthorizationState(self.pendingAuthorizationType, info: self.authPresentationInfoByAccount[selected.account] ?? [:])
                } else if let closedProfile = self.closedProfileToRetry {
                    self.showClosedProfileRecovery(closedProfile)
                }
            }
        }
    }

    private func setLockedStatus(_ value: String) {
        (lockedView.subviews.first(where: { $0.identifier?.rawValue == "lockedStatus" }) as? NSTextField)?.stringValue = value
    }
    @objc private func quit() { NSApp.terminate(nil) }
}

private struct PhoneCountry {
    let code: String
    let name: String
    let flag: String
    let callingCodes: [String]

    init?(json: [String: Any]) {
        guard let code = json["country_code"] as? String,
              let name = (json["name"] as? String) ?? (json["english_name"] as? String),
              let callingCodes = json["calling_codes"] as? [String] else { return nil }
        self.code = code
        self.name = name
        self.flag = json["flag_emoji"] as? String ?? "🌐"
        self.callingCodes = callingCodes
    }
}

private struct PhotoPresentationKey: Hashable, Sendable {
    let account: AccountUUID
    let chatID: Int64
    let messageID: Int64
    let fileID: Int32
}

private struct SponsoredPhotoKey: Hashable, Sendable {
    let account: AccountUUID
    let generation: RuntimeGeneration
    let chatID: Int64
    let messageID: Int64
    let fileID: Int32
}

private struct PendingSend: Sendable {
    let intent: SendIntent
    let text: String
}

private enum InitialAuthorizationAction {
    case phoneNumber(String)
    case qrCode
}

private struct DeferredSearch {
    let query: String
    let generation: UInt64
}

private struct MessageActionTarget {
    let key: MessageKey
    let message: [String: Any]
}

private struct MessageActionContext {
    let expectedTelegramUserID: Int64
    let runtimeGeneration: RuntimeGeneration
    let key: MessageKey
    let privacyEpoch: UInt64
    let message: [String: Any]
}

private struct PendingRetryRequest {
    let key: SendMessageKey
    let privacyEpoch: UInt64
}

private struct PendingRetryRefresh {
    let key: MessageKey
    let runtimeGeneration: RuntimeGeneration
    let privacyEpoch: UInt64
}

private enum MessageMutationKind: Equatable {
    case editText
    case editCaption
    case delete(MessageDeleteMode)

    var isDelete: Bool {
        if case .delete = self { return true }
        return false
    }
}

@MainActor
private final class MessageActionInvocation: NSObject {
    let context: MessageActionContext
    let kind: MessageMutationKind

    init(context: MessageActionContext, kind: MessageMutationKind) {
        self.context = context
        self.kind = kind
    }
}

private struct PendingMessageMutation {
    let context: MessageActionContext
    let kind: MessageMutationKind
}

private struct PhotoSendContext: Sendable {
    let account: AccountUUID
    let expectedTelegramUserID: Int64
    let runtimeGeneration: RuntimeGeneration
    let conversation: ConversationKey
    let replyToMessageID: Int64?
    let caption: String
    let privacyEpoch: UInt64
}

@MainActor
private final class LocalAccountRuntime {
    let account: AccountUUID
    let paths: AccountStoragePaths
    let databaseKey: Data
    let apiHash: String
    private let gateway: TDLibGateway
    private let catalogue: AccountCatalogue
    private let commandGate = RuntimeCommandGate()
    fileprivate var route: RuntimeRoute?
    fileprivate let generation: RuntimeGeneration
    private var logoutExtra: String?
    private(set) var isLogoutRequested = false
    private(set) var logoutWasAccepted = false
    private var logoutFailureNotice = false
    private var didRequestCurrentUser = false
    private var mainChatLoadState = ChatListLoadState()
    private var didSendTDLibParameters = false
    fileprivate var initializationRequestWasQueued: Bool { didSendTDLibParameters }
    private(set) var authorizationState: String?
    private(set) var lastTDLibError: String?
    private(set) var identityPersistenceFailed = false
    private(set) var identityMismatchDetected = false
    private var identityPersistenceFailureNoticeShown = false
    private var identityReadyTransitionConsumed = false
    private(set) var telegramUserID: Int64?
    private(set) var displayName: String?

    init(account: AccountUUID, paths: AccountStoragePaths, databaseKey: Data, apiHash: String, gateway: TDLibGateway, catalogue: AccountCatalogue, generation: RuntimeGeneration) {
        self.account = account
        self.paths = paths
        self.databaseKey = databaseKey
        self.apiHash = apiHash
        self.gateway = gateway
        self.catalogue = catalogue
        self.generation = generation
    }

    func registerRoute() throws -> RuntimeRoute {
        let route = RuntimeRoute(account: account, generation: generation, client: try gateway.createClientID())
        self.route = route
        return route
    }

    func send(_ request: [String: Any]) throws {
        guard let route else { return }
        let type = request["@type"] as? String
        guard !isLogoutRequested || type == "close" || type == "logOut" else {
            throw CocoaError(.userCancelled)
        }
        let accepted = try commandGate.dispatch {
            try sendRaw(request, type: type, route: route)
        }
        guard accepted else { throw CocoaError(.userCancelled) }
    }

    private func sendRaw(_ request: [String: Any], type: String?, route: RuntimeRoute) throws {
        let bytes = try JSONSerialization.data(withJSONObject: request, options: [.sortedKeys])
        try gateway.send(String(decoding: bytes, as: UTF8.self), to: route.client)
        if type == "setTdlibParameters" { didSendTDLibParameters = true }
    }

    func requestLogout() throws {
        guard !isLogoutRequested,
              route != nil,
              telegramUserID != nil,
              authorizationState == "authorizationStateReady" else {
            throw CocoaError(.userCancelled)
        }
        let extra = "netetelegram-logout-\(account.id.uuidString.lowercased())-\(generation.value)-\(UUID().uuidString.lowercased())"
        try send(["@type": "logOut", "@extra": extra])
        logoutExtra = extra
        isLogoutRequested = true
    }

    func takeLogoutFailureNotice() -> Bool {
        defer { logoutFailureNotice = false }
        return logoutFailureNotice
    }

    func applyNetworkType(_ type: String) throws {
        guard didSendTDLibParameters,
              authorizationState != "authorizationStateClosed",
              authorizationState != "authorizationStateClosing" else { return }
        try send(["@type": "setNetworkType", "type": ["@type": type]])
    }

    func loadMainChats(reload: Bool = false) {
        guard authorizationState == "authorizationStateReady", telegramUserID != nil else { return }
        guard mainChatLoadState.beginLoad(reload: reload) else { return }
        do {
            try send(["@type": "loadChats", "chat_list": NSNull(), "limit": 100])
            mainChatLoadState.completeLoad()
        } catch {
            mainChatLoadState.failLoad()
        }
    }

    func invalidateMainChatSnapshot() {
        mainChatLoadState.invalidate()
    }

    func consume(_ object: [String: Any]) async {
        if object["@type"] as? String == "updateAuthorizationState",
           let authorization = object["authorization_state"] as? [String: Any],
           let state = authorization["@type"] as? String {
            authorizationState = state
            if state == "authorizationStateLoggingOut", isLogoutRequested {
                logoutWasAccepted = true
            }
            if state == "authorizationStateReady", !didRequestCurrentUser {
                didRequestCurrentUser = true
                try? send(["@type": "getMe"])
            }
        } else if object["@type"] as? String == "ok",
                  object["@extra"] as? String == logoutExtra {
            logoutWasAccepted = true
        } else if object["@type"] as? String == "error" {
            if object["@extra"] as? String == logoutExtra {
                isLogoutRequested = false
                logoutWasAccepted = false
                logoutExtra = nil
                logoutFailureNotice = true
            }
            lastTDLibError = "TDLib error \(object["code"] ?? "unknown")"
        } else if object["@type"] as? String == "user" {
            let names = [object["first_name"] as? String, object["last_name"] as? String]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard let telegramUserID = (object["id"] as? NSNumber)?.int64Value, telegramUserID > 0 else {
                lastTDLibError = "Telegram returned a user without a positive numeric identity"
                identityPersistenceFailed = true
                return
            }
            do {
                // Preserve reducer order and expose the profile as restorable
                // only after its verified server identity is atomically saved.
                try await catalogue.associateVerifiedIdentity(
                    telegramUserID,
                    displayName: names.isEmpty ? nil : names.joined(separator: " "),
                    with: account
                )
                self.telegramUserID = telegramUserID
                displayName = names.joined(separator: " ")
                identityPersistenceFailed = false
                identityMismatchDetected = false
                identityPersistenceFailureNoticeShown = false
            } catch AccountCatalogueError.identityMismatch {
                lastTDLibError = "Telegram identity mismatch for this local profile"
                identityPersistenceFailed = true
                identityMismatchDetected = true
            } catch {
                lastTDLibError = "Verified Telegram identity could not be saved"
                identityPersistenceFailed = true
            }
        }
    }

    func takeIdentityPersistenceFailureNotice() -> Bool {
        guard identityPersistenceFailed, !identityPersistenceFailureNoticeShown else { return false }
        identityPersistenceFailureNoticeShown = true
        return true
    }

    func takeIdentityReadyTransition() -> Bool {
        guard authorizationState == "authorizationStateReady",
              telegramUserID != nil,
              !identityReadyTransitionConsumed else { return false }
        identityReadyTransitionConsumed = true
        return true
    }

    @discardableResult
    func close() -> Bool {
        guard let route else { return false }
        do {
            return try commandGate.beginClosing {
                try sendRaw(["@type": "close"], type: "close", route: route)
            }
        } catch {
            // Keep the receive worker alive. Without a close acknowledgement,
            // the app must not claim a clean TDLib shutdown.
            lastTDLibError = "TDLib close request failed"
            return false
        }
    }

    func finishClose() {}
}

private final class AuthenticationCardView: NSView {
    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        super.updateLayer()
        guard let layer else { return }
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer.backgroundColor = NSColor.controlBackgroundColor.cgColor
            layer.borderColor = NSColor.separatorColor.cgColor
        }
        layer.borderWidth = 1 / max(window?.backingScaleFactor ?? 2, 1)
        layer.cornerRadius = 18
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateLayer()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
