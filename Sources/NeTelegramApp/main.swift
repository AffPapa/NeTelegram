import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import LocalAuthentication
import Network
import UniformTypeIdentifiers
import UserNotifications
import NeTelegramCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, @preconcurrency UNUserNotificationCenterDelegate, NSTextViewDelegate, NSTextFieldDelegate, NSControlTextEditingDelegate, @unchecked Sendable {
    private var window: NSWindow!
    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var statusLabel: NSTextField!
    private var inputField: NSTextField!
    private var secureInputField: NSSecureTextField!
    private var actionButton: NSButton!
    private var addAccountButton: NSButton!
    private var accountPicker: NSPopUpButton!
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
    private var authStack: NSStackView!
    private var runtime: LocalAccountRuntime?
    private var gateway: TDLibGateway?
    private var updatePipeline: TDLibUpdatePipeline?
    private let runtimeCoordinator = RuntimeCoordinator(startupParallelism: 2)
    private let startupScheduler = RuntimeStartupScheduler(parallelism: 2)
    private var catalogue: AccountCatalogue?
    private var catalogueRoot: URL?
    private var runtimesByClient: [Int32: LocalAccountRuntime] = [:]
    private var runtimesByAccount: [AccountUUID: LocalAccountRuntime] = [:]
    private var pendingAuthorizationType: String?
    private var pendingInitialAuthorizationAction: InitialAuthorizationAction?
    private var initialAccountCreationInProgress = false
    private var lockState = false
    private var terminationBarrierFinished = false
    private var terminationReply: ((Bool) -> Void)?
    private var pendingClosures: Set<Int32> = []
    private var closingForTermination = false
    private var shutdownProgressTask: Task<Void, Never>?
    private var resumeProfilesAfterAbortedTermination = false
    private var profileRestoreInProgress = false
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
    private var pendingSearchByExtra: [String: PendingSearchRequest] = [:]
    private var deferredSearch: DeferredSearch?
    private var historyAnchorByConversation: [ConversationKey: Int64] = [:]
    private var messageList: NSStackView!
    private var messageScroll: NSScrollView!
    private var composerScroll: NSScrollView!
    private var composer: NSTextView!
    private var replyStatusLabel: NSTextField!
    private var clearReplyButton: NSButton!
    private var replyTargetsByConversation: [ConversationKey: Int64] = [:]
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
    private var sendEligibilityByAccount: [AccountUUID: [Int64: ChatSendPermission]] = [:]
    private var pendingSendByExtra: [String: PendingSend] = [:]
    private var stagedOutgoingPhotosByFileID: [AccountUUID: [Int32: URL]] = [:]
    private var pendingStagedPhotoPaths: [AccountUUID: Set<URL>] = [:]
    private var completedOutgoingPhotoFileIDs: [AccountUUID: Set<Int32>] = [:]
    private let networkMonitor = NWPathMonitor()
    private let networkMonitorQueue = DispatchQueue(label: "org.affpapa.netelegram.network-monitor", qos: .utility)
    private var networkTypeUpdateTask: Task<Void, Never>?
    private var currentTDLibNetworkType = "networkTypeNone"
    private var pendingProfileStorageWarnings = 0
    private var suppressDraftUpdate = false
    private var chatRowsByAccount: [AccountUUID: [Int64: (title: String, lastText: String)]] = [:]
    private var chatOrderByAccount: [AccountUUID: [Int64: UInt64]] = [:]
    private var selectedChatByAccount: [AccountUUID: Int64] = [:]
    private var messagesByConversation: [ConversationKey: [[String: Any]]] = [:]
    private var pendingHistoryByExtra: [String: ConversationKey] = [:]
    private var pendingForumTopicsByExtra: [String: Int64] = [:]
    private var forumTopicsByAccount: [AccountUUID: [Int64: [ForumTopicDescriptor]]] = [:]
    private var forumChatsByAccount: [AccountUUID: Set<Int64>] = [:]
    private var selectedForumTopicIDsByAccount: [AccountUUID: [Int64: Int32]] = [:]
    private var topicPickerIDs: [Int32] = []
    private var historyRequestCounter: UInt64 = 0
    private var notificationIDsByAccount: [AccountUUID: Set<String>] = [:]
    private var notificationTargets: [String: RoutedTDLibNotification] = [:]

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
        if terminationBarrierFinished { return .terminateNow }
        guard flushDirtyDraftsBeforeQuit() else { return .terminateCancel }
        guard !profileRestoreInProgress else {
            setStatus("Восстанавливаю профили. Повторите выход после завершения запуска.")
            return .terminateCancel
        }
        if runtimesByClient.isEmpty {
            guard let gateway, !gateway.receiveWorkerHasExited else { return .terminateNow }
            terminationReply = { [weak self] allow in
                NSApp.reply(toApplicationShouldTerminate: allow)
                self?.terminationReply = nil
            }
            stopReceiverAndReplyWhenExited(gateway)
            return .terminateLater
        }
        guard !resumeProfilesAfterAbortedTermination, pendingClosures.isEmpty else {
            setStatus("Ожидаю подтверждения TDLib перед повторной попыткой выхода.")
            return .terminateCancel
        }
        closingForTermination = true
        pendingClosures = Set(runtimesByClient.keys)
        let rejected = runtimesByClient.compactMap { client, target in
            target.close() ? nil : client
        }
        if !rejected.isEmpty {
            // Do not strand already-accepted close requests. Cancel this quit
            // attempt, wait for their Closed updates, then reopen only profiles
            // whose previous TDLib clients have fully closed.
            closingForTermination = false
            pendingClosures.subtract(rejected)
            resumeProfilesAfterAbortedTermination = !pendingClosures.isEmpty
            setStatus("TDLib не принял закрытие одного или нескольких аккаунтов. Приложение осталось открытым; повторный выход будет доступен после восстановления runtime.")
            if pendingClosures.isEmpty { resumeProfilesAfterAbortedTermination = false }
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
        // The window can be restored at a size larger than the original frame.
        // Keep the constraint container in sync with the live window bounds so
        // centerX/centerY based auth layout remains centered after restoration.
        content.autoresizingMask = [.width, .height]
        content.autoresizesSubviews = true
        // Auth content follows the live bounds; the stack owns vertical spacing
        // so changing auth states never depends on independently tuned offsets.
        func centered(_ width: CGFloat, y: CGFloat, height: CGFloat) -> NSRect {
            NSRect(x: (content.bounds.midX) - width / 2, y: y, width: width, height: height)
        }
        content.identifier = NSUserInterfaceItemIdentifier("rootContent")
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let mark = NSView(frame: centered(64, y: 520, height: 64))
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
        accountPicker.setAccessibilityLabel("Авторизованный аккаунт")

        countryPicker = NSPopUpButton(frame: centered(300, y: 365, height: 34), pullsDown: false)
        countryPicker.isHidden = true
        countryPicker.target = self
        countryPicker.action = #selector(selectCountry)
        countryPicker.setAccessibilityLabel("Страна и телефонный код")
        phoneField = NSTextField(string: "")
        phoneField.placeholderString = "+код страны и номер"
        phoneField.font = .systemFont(ofSize: 17)
        phoneField.frame = centered(360, y: 315, height: 38)
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
        inputField.frame = phoneField.frame
        inputField.alignment = .center
        inputField.setAccessibilityLabel("Код подтверждения входа")
        inputField.isHidden = true
        inputField.delegate = self
        secureInputField = NSSecureTextField(string: "")
        secureInputField.placeholderString = "Пароль двухэтапной проверки"
        secureInputField.font = .systemFont(ofSize: 17)
        secureInputField.frame = phoneField.frame
        secureInputField.alignment = .center
        secureInputField.setAccessibilityLabel("Пароль двухэтапной проверки")
        secureInputField.isHidden = true
        secureInputField.delegate = self

        statusLabel = NSTextField(wrappingLabelWithString: "Подключаю экран входа…")
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center
        statusLabel.setAccessibilityLabel("Статус авторизации")

        qrImageView = NSImageView(frame: centered(180, y: 290, height: 180))
        qrImageView.imageScaling = .scaleProportionallyUpOrDown
        qrImageView.isHidden = true

        actionButton = NSButton(title: "Продолжить", target: self, action: #selector(primaryAction))
        actionButton.bezelStyle = .rounded
        actionButton.frame = centered(360, y: 210, height: 38)
        actionButton.setAccessibilityLabel("Продолжить вход")
        qrButton = NSButton(title: "Войти по QR-коду", target: self, action: #selector(beginQRLogin))
        qrButton.isBordered = false
        qrButton.contentTintColor = .systemBlue
        qrButton.frame = centered(280, y: 165, height: 28)
        qrButton.setAccessibilityLabel("Войти по QR-коду")
        addAccountButton = NSButton(title: "Добавить ещё аккаунт", target: self, action: #selector(addAccount))
        addAccountButton.isBordered = false
        addAccountButton.contentTintColor = .systemBlue
        addAccountButton.frame = centered(280, y: 125, height: 28)
        addAccountButton.isHidden = true
        addAccountButton.setAccessibilityLabel("Добавить ещё один Telegram аккаунт")
        authStack = NSStackView(views: [mark, loginHeading, loginSubtitle, registrationTermsScroll, countryPicker, phoneField, emailField, inputField, secureInputField, firstNameField, lastNameField, registrationConsent, qrImageView, statusLabel, actionButton, qrButton])
        authStack.orientation = .vertical
        authStack.alignment = .centerX
        authStack.distribution = .fill
        authStack.spacing = 14
        authStack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(authStack)
        NSLayoutConstraint.activate([
            authStack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            authStack.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            mark.widthAnchor.constraint(equalToConstant: 64), mark.heightAnchor.constraint(equalToConstant: 64),
            loginHeading.widthAnchor.constraint(equalToConstant: 500),
            loginSubtitle.widthAnchor.constraint(equalToConstant: 500),
            registrationTermsScroll.widthAnchor.constraint(equalToConstant: 500), registrationTermsScroll.heightAnchor.constraint(equalToConstant: 144),
            countryPicker.widthAnchor.constraint(equalToConstant: 300), countryPicker.heightAnchor.constraint(equalToConstant: 34),
            phoneField.widthAnchor.constraint(equalToConstant: 360), phoneField.heightAnchor.constraint(equalToConstant: 38),
            emailField.widthAnchor.constraint(equalToConstant: 360), emailField.heightAnchor.constraint(equalToConstant: 38),
            inputField.widthAnchor.constraint(equalToConstant: 360), inputField.heightAnchor.constraint(equalToConstant: 38),
            secureInputField.widthAnchor.constraint(equalToConstant: 360), secureInputField.heightAnchor.constraint(equalToConstant: 38),
            firstNameField.widthAnchor.constraint(equalToConstant: 360), firstNameField.heightAnchor.constraint(equalToConstant: 38),
            lastNameField.widthAnchor.constraint(equalToConstant: 360), lastNameField.heightAnchor.constraint(equalToConstant: 38),
            registrationConsent.widthAnchor.constraint(equalToConstant: 500),
            qrImageView.widthAnchor.constraint(equalToConstant: 180), qrImageView.heightAnchor.constraint(equalToConstant: 180),
            statusLabel.widthAnchor.constraint(equalToConstant: 500),
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
        let lockedTitle = NSTextField(labelWithString: "NeTelegram заблокирован")
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
        window.title = "NeTelegram"
        window.contentView = content
        // Assign the content view before fixing the size. This prevents a stale
        // restored frame from leaving the root view narrower than its window,
        // which would make centerX constraints look left-aligned on wide screens.
        window.setContentSize(NSSize(width: contentWidth, height: contentHeight))
        window.center()
        window.minSize = NSSize(width: 900, height: 620)
        window.isReleasedWhenClosed = false
        window.delegate = self
        self.window = window
        layoutWindowContents()
        showWindow()
    }

    func windowDidResize(_ notification: Notification) {
        guard (notification.object as? NSWindow) === window else { return }
        layoutWindowContents()
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
        // NSWindow can restore a frame independently of a programmatically
        // created root view. Keep the view's actual coordinate space equal to
        // the visible content area before centering the login stack.
        let visibleContentSize = window.contentLayoutRect.size
        if abs(content.frame.width - visibleContentSize.width) > 0.5 ||
            abs(content.frame.height - visibleContentSize.height) > 0.5 {
            content.setFrameSize(visibleContentSize)
            content.setBoundsSize(visibleContentSize)
        }
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
        networkMonitor.pathUpdateHandler = { [weak self] path in
            let type = NetworkTypeUpdatePolicy.tdlibType(
                isSatisfied: path.status == .satisfied,
                usesWiFi: path.usesInterfaceType(.wifi),
                usesCellular: path.usesInterfaceType(.cellular)
            )
            Task { @MainActor [weak self] in self?.scheduleNetworkTypeUpdate(type) }
        }
        networkMonitor.start(queue: networkMonitorQueue)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(didWakeFromSleep(_:)),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    private func scheduleNetworkTypeUpdate(_ type: String, force: Bool = false) {
        guard NetworkTypeUpdatePolicy.shouldApply(current: currentTDLibNetworkType, next: type, force: force) else { return }
        networkTypeUpdateTask?.cancel()
        networkTypeUpdateTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled, let self else { return }
            guard NetworkTypeUpdatePolicy.shouldApply(
                current: self.currentTDLibNetworkType,
                next: type,
                force: force
            ) else { return }
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
        scheduleNetworkTypeUpdate(
            NetworkTypeUpdatePolicy.tdlibType(
                isSatisfied: path.status == .satisfied,
                usesWiFi: path.usesInterfaceType(.wifi),
                usesCellular: path.usesInterfaceType(.cellular)
            ),
            force: true
        )
    }

    private func refreshStatusMenu() {
        guard statusMenuItem != nil else { return }
        let accounts = Array(runtimesByAccount.values)
        let authorized = accounts.filter { $0.telegramUserID != nil }.count
        let awaitingInput = accounts.filter { AuthorizationStep(tdlibType: $0.authorizationState).awaitsUserInput }.count
        let failed = accounts.filter { $0.authorizationState == "authorizationStateClosed" || $0.lastTDLibError != nil }.count
        let storageWarning = pendingProfileStorageWarnings > 0
            ? " · \(pendingProfileStorageWarnings) локальных профилей не проверены"
            : ""
        if accounts.isEmpty {
            statusMenuItem.title = "Аккаунтов пока нет\(storageWarning)"
        } else {
            statusMenuItem.title = "Аккаунты: \(authorized) авторизованы · \(awaitingInput) требуют входа · \(failed) с ошибкой\(storageWarning)"
        }
    }

    private func buildMainMenu() {
        let main = NSMenu()
        let appMenuItem = NSMenuItem()
        main.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "О NeTelegram", action: nil, keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Выйти", action: #selector(quit), keyEquivalent: "q")
        appMenu.items.forEach { $0.target = self }
        appMenuItem.submenu = appMenu

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

    @objc private func primaryAction() {
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
            try runtime.send(routedRequest)
            pendingAuthRequestsByExtra[extra] = (runtime.account, authType)
            authRequestInFlight = true
            actionButton.isEnabled = false
            setStatus("Запрос отправлен TDLib. Ожидание следующего шага…")
        } catch {
            setStatus("Не удалось отправить запрос авторизации.")
        }
    }

    private func validatedPhoneNumber() -> String? {
        let rawPhone = phoneField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawPhone.isEmpty else { setStatus("Введите номер телефона."); return nil }
        let digits = rawPhone.compactMap { character in character.wholeNumberValue.map(String.init) }.joined()
        let explicitlyInternational = rawPhone.hasPrefix("+")
        let normalizedDigitCount = explicitlyInternational ? digits.count : selectedCallingCode.count + digits.count
        guard (4...15).contains(normalizedDigitCount) else {
            setStatus("Введите номер с кодом страны: от 4 до 15 цифр.")
            return nil
        }
        guard explicitlyInternational || !phoneCountries.isEmpty else {
            setStatus("Загружается список стран. Можно также ввести номер полностью, начиная с +.")
            return nil
        }
        return explicitlyInternational ? "+\(digits)" : "+\(selectedCallingCode)\(digits)"
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
        let accounts = runtimesByAccount.keys.filter { runtimesByAccount[$0]?.telegramUserID != nil }.sorted {
            (runtimesByAccount[$0].flatMap(safeAccountName) ?? "") < (runtimesByAccount[$1].flatMap(safeAccountName) ?? "")
        }
        let index = accountPicker.indexOfSelectedItem
        guard accounts.indices.contains(index), let selected = runtimesByAccount[accounts[index]] else { return }
        authRequestInFlight = false
        closePhotoViewer()
        if let previous = runtime, previous !== selected,
           let previousChat = selectedChatByAccount[previous.account] {
            cancelPhotoDownloads(account: previous.account, chatID: previousChat)
            try? previous.send(["@type": "closeChat", "chat_id": previousChat])
        }
        runtime = selected
        pendingAuthorizationType = selected.authorizationState
        inputField.isHidden = true
        secureInputField.isHidden = true
        actionButton.isEnabled = false
        setStatus("Выбран аккаунт \(safeAccountName(selected) ?? "Аккаунт"). Остальные авторизованные аккаунты продолжают работу.")
        if selected.telegramUserID != nil {
            selected.loadMainChats()
            showAuthenticatedChatUI()
            refreshChatList()
            displaySelectedConversation()
            refreshComposerState()
            return
        }
        switch selected.authorizationState {
        case "authorizationStateWaitPhoneNumber": showPhoneEntry()
        case "authorizationStateWaitCode": showAuthInput("Введите код, полученный для этого входа.", placeholder: "Код", button: "Продолжить")
        case "authorizationStateWaitPassword": showAuthInput("Введите пароль двухэтапной проверки. Он не сохраняется.", placeholder: "Пароль двухэтапной проверки", button: "Продолжить")
        case "authorizationStateWaitEmailAddress": showEmailEntry()
        case "authorizationStateWaitEmailCode": showEmailCode(authPresentationInfoByAccount[selected.account] ?? [:])
        case "authorizationStateWaitRegistration": showRegistration(authPresentationInfoByAccount[selected.account] ?? [:])
        default: break
        }
    }

    private func refreshAccountPicker(select account: AccountUUID? = nil) {
        let accounts = runtimesByAccount.keys.filter { runtimesByAccount[$0]?.telegramUserID != nil }.sorted {
            (runtimesByAccount[$0].flatMap(safeAccountName) ?? "") < (runtimesByAccount[$1].flatMap(safeAccountName) ?? "")
        }
        accountPicker.removeAllItems()
        accounts.enumerated().forEach { index, id in
            accountPicker.addItem(withTitle: runtimesByAccount[id].flatMap(safeAccountName) ?? "Аккаунт \(index + 1)")
        }
        accountPicker.isHidden = accounts.count < 2
        addAccountButton.isHidden = runtimesByAccount.isEmpty
        accountPicker.isEnabled = accounts.count > 1
        if let account, let index = accounts.firstIndex(of: account) {
            accountPicker.selectItem(at: index)
            runtime = runtimesByAccount[account]
        } else if let runtime, let index = accounts.firstIndex(of: runtime.account) {
            accountPicker.selectItem(at: index)
        }
    }

    @objc private func addAccount() {
        Task { @MainActor in await addAccountProfile() }
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

    private func restoreProfiles(recoveryAfterCancelledTermination: Bool = false) async {
        guard !profileRestoreInProgress || recoveryAfterCancelledTermination else { return }
        profileRestoreInProgress = true
        defer { profileRestoreInProgress = false }
        do {
            let catalogue = try accountCatalogue()
            let profiles = await catalogue.allProfiles()
            let apiHash = try SecretsStore().telegramAPIHash()
            let authorized = profiles.filter { $0.telegramUserID != nil }
            let pending = profiles.filter { $0.telegramUserID == nil }.sorted { $0.createdAt < $1.createdAt }
            var pendingWithStoredDatabase = Set<AccountUUID>()
            pendingProfileStorageWarnings = 0
            let storageRoot = try accountStorageRoot()
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
            let toRestore = candidates.filter { runtimesByAccount[$0.id] == nil }
            if toRestore.isEmpty {
                if profiles.isEmpty {
                    pendingAuthorizationType = "authorizationStateWaitPhoneNumber"
                    showPhoneEntry()
                    setStatus("Введите номер и нажмите «Продолжить», чтобы начать вход.")
                }
                refreshStatusMenu()
                return
            }
            setStatus(authorized.isEmpty ? "Подключаю вход…" : "Восстанавливаю аккаунты…")
            // Start every authorized profile through the bounded scheduler.
            // openProfile releases its permit after the first TDLib request,
            // before any phone/code/2FA network wait can begin.
            let starts = toRestore.map { profile in
                Task { @MainActor in await openProfile(profile, apiHash: apiHash) }
            }
            for start in starts { await start.value }
            refreshAccountPicker()
            if authorized.isEmpty {
                setStatus(phoneCountries.isEmpty
                    ? "Введите полный номер с + и кодом страны. Список стран загружается."
                    : "Выберите страну и введите номер телефона.")
            }
        } catch SecretsStoreError.missing {
            setStatus("API hash не найден в Keychain; профили не будут заменены или пересозданы.")
        } catch {
            setStatus("Каталог профилей не удалось безопасно открыть. Данные не сброшены.")
        }
    }

    private func stopReceiverAndReplyWhenExited(_ gateway: TDLibGateway) {
        gateway.requestWorkerStop()
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
            self.setStatus("Все runtime закрыты; подтверждаю выход macOS…")
            self.terminationBarrierFinished = true
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

    private func addAccountProfile() async {
        do {
            let catalogue = try accountCatalogue()
            let profile = try await catalogue.addProfile()
            let apiHash = try SecretsStore().telegramAPIHash()
            await openProfile(profile, apiHash: apiHash, select: true)
            refreshAccountPicker(select: profile.id)
        } catch SecretsStoreError.missing {
            setStatus("API hash не найден в Keychain; профиль сохранён без подмены identity.")
        } catch {
            setStatus("Не удалось создать профиль. Проверьте хранилище и Keychain.")
        }
    }

    private func openProfile(_ profile: AccountProfile, apiHash: String, select: Bool = false) async {
        await startupScheduler.acquire()
        do {
            guard let library = tdjsonLibraryURL() else { throw TDLibGatewayError.libraryLoad("Pinned TDLib not found") }
            if gateway == nil { gateway = try TDLibGateway(libraryURL: library) }
            guard let gateway, let catalogue else { throw TDLibGatewayError.clientCreation }
            let root = try accountStorageRoot()
            let prepared = try await Task.detached(priority: .utility) { () throws -> (AccountStoragePaths, Data) in
                let paths = try AccountStoragePaths(rootURL: root, account: profile.id)
                let hasDatabaseFiles = try !FileManager.default.contentsOfDirectory(atPath: paths.database.path).isEmpty
                let key = try SecretsStore().databaseKey(for: profile.id, createIfMissing: !hasDatabaseFiles)
                return (paths, key)
            }.value
            do {
                let draftsURL = prepared.0.appState.appendingPathComponent("drafts.aesgcm")
                let appStateKey = try SecretsStore().appStateKey(
                    for: profile.id,
                    createIfMissing: !FileManager.default.fileExists(atPath: draftsURL.path)
                )
                let draftStore = try EncryptedDraftStore(account: profile.id, stateDirectory: prepared.0.appState, key: appStateKey)
                draftStoresByAccount[profile.id] = draftStore
                for (conversation, text) in try draftStore.load() { draftsByConversation[conversation] = text }
                unavailableDraftAccounts.remove(profile.id)
            } catch {
                // Keep unreadable ciphertext intact and refuse edits that could overwrite it.
                unavailableDraftAccounts.insert(profile.id)
                setStatus("Черновики этого аккаунта не открыты; сохранённые данные не изменены.")
            }
            let generation = await runtimeCoordinator.nextGeneration(for: profile.id)
            let runtime = LocalAccountRuntime(account: profile.id, paths: prepared.0, databaseKey: prepared.1, apiHash: apiHash, gateway: gateway, catalogue: catalogue, generation: generation)
            let route = try runtime.registerRoute()
            try await runtimeCoordinator.registerBeforeFirstRequest(route)
            runtimesByClient[route.client.value] = runtime
            runtimesByAccount[profile.id] = runtime
            refreshStatusMenu()
            let presentsThisRuntime = select || self.runtime == nil
            if presentsThisRuntime { self.runtime = runtime }
            if updatePipeline == nil {
                let pipeline = TDLibUpdatePipeline(gateway: gateway, coordinator: runtimeCoordinator)
                updatePipeline = pipeline
                pipeline.start { [weak self] event in
                    // Synchronous handoff is intentional: the pipeline must
                    // wait for UI reduction before it accepts another event.
                    let completed = DispatchSemaphore(value: 0)
                    Task { @MainActor [weak self] in
                        defer { completed.signal() }
                        await self?.receive(event)
                    }
                    completed.wait()
                }
            }
            await runtimeCoordinator.setState(.waitingForAuthorization, for: profile.id)
            try runtime.send(parametersRequest(for: runtime))
            try runtime.applyNetworkType(currentTDLibNetworkType)
            if presentsThisRuntime { try runtime.send(["@type": "getCountries"]) }
            await startupScheduler.release()
        } catch {
            await runtimeCoordinator.setState(.failed("Profile startup failed"), for: profile.id)
            await startupScheduler.release()
            setStatus("Не удалось открыть вход. Сохранённые данные не удалены; остальные аккаунты продолжают работу.")
        }
    }

    private func receive(_ event: TDLibPipelineEvent) async {
        switch event {
        case .routingFailure(let error):
            setStatus("TDLib update не маршрутизирован (\(error)); fallback на выбранный профиль запрещён.")
        case .routed(let update):
            guard let target = runtimesByClient[update.route.client.value], target.route == update.route else {
                setStatus("TDLib update пришёл от неизвестного профиля; fallback на выбранный аккаунт запрещён.")
                return
            }
            await target.consume(update.json)
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
            handle(update.json, from: target)
            refreshStatusMenu()
        }
    }

    private func handle(_ update: Data, from target: LocalAccountRuntime) {
        guard let object = (try? JSONSerialization.jsonObject(with: update)) as? [String: Any] else { return }
        let updateType = object["@type"] as? String ?? ""
        if target.telegramUserID == nil,
           !["updateAuthorizationState", "countries", "error"].contains(updateType) {
            return
        }
        if let extra = object["@extra"] as? String,
           extra.hasPrefix("search-") {
            guard let pending = pendingSearchByExtra.removeValue(forKey: extra) else { return }
            guard pending.generation == searchGeneration, !lockState else {
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
                target.finishClose()
                if let client {
                    runtimesByClient.removeValue(forKey: client)
                    pendingClosures.remove(client)
                    if let route = target.route { Task { await runtimeCoordinator.removeRouteAfterClosed(route.client) } }
                }
                runtimesByAccount.removeValue(forKey: target.account)
                authPresentationInfoByAccount.removeValue(forKey: target.account)
                if target === runtime { runtime = runtimesByAccount.values.first }
                refreshAccountPicker()
                if closingForTermination && pendingClosures.isEmpty {
                    closingForTermination = false
                    if let gateway { stopReceiverAndReplyWhenExited(gateway) }
                    else {
                        terminationBarrierFinished = true
                        terminationReply?(true)
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
                showingQR = true
                authStack.isHidden = false
                phoneField.isHidden = true
                emailField.isHidden = true
                firstNameField.isHidden = true
                lastNameField.isHidden = true
                registrationConsent.isHidden = true
                registrationTermsScroll.isHidden = true
                phoneField.stringValue = ""
                countryPicker.isHidden = true
                inputField.isHidden = true
                secureInputField.isHidden = true
                qrImageView.isHidden = false
                loginHeading.stringValue = "Вход по QR-коду"
                loginSubtitle.stringValue = "Откройте Telegram на телефоне → Настройки → Устройства → Подключить устройство и отсканируйте код."
                if let link = auth["link"] as? String { qrImageView.image = qrImage(for: link) }
                actionButton.isHidden = true
                qrButton.isHidden = true
                setStatus("Подтвердите вход на своём телефоне.")
            case "authorizationStateLoggingOut", "authorizationStateClosing":
                pendingAuthorizationType = nil
                if closingForTermination {
                    setStatus("Завершаю работу: TDLib закрывает аккаунты и сохраняет базы…")
                } else {
                    setStatus("Состояние авторизации: \(authType)")
                }
            default:
                setStatus("Состояние авторизации: \(authType)")
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
        } else if object["@type"] as? String == "updateNotificationGroup" {
            updateNotificationGroup(object, for: target)
        } else if object["@type"] as? String == "updateDeleteMessages",
                  let chatID = (object["chat_id"] as? NSNumber)?.int64Value,
                  let ids = object["message_ids"] as? [NSNumber] {
            let deletedIDs = Set(ids.map(\.int64Value))
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
            if draftsByConversation[pending.intent.conversation] == pending.text {
                draftsByConversation.removeValue(forKey: pending.intent.conversation)
                persistDrafts(for: pending.intent.account)
                if !lockState, currentConversationKey() == pending.intent.conversation {
                    setComposerText("")
                }
            }
            if let replyID = pending.intent.replyToMessageID,
               replyTargetsByConversation[pending.intent.conversation] == replyID {
                replyTargetsByConversation.removeValue(forKey: pending.intent.conversation)
                if !lockState, currentConversationKey() == pending.intent.conversation {
                    refreshReplyStatus(for: pending.intent.conversation)
                }
            }
            if !lockState, target === runtime {
                setStatus("Сообщение принято TDLib.")
                refreshComposerState()
            }
        } else if let type = object["@type"] as? String, type == "messages",
                  let messages = object["messages"] as? [[String: Any]],
                  let extra = object["@extra"] as? String, let conversation = pendingHistoryByExtra.removeValue(forKey: extra) {
            guard !lockState else { return }
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
        } else if let type = object["@type"] as? String, type == "user" {
            refreshAccountPicker(select: target === runtime ? target.account : nil)
            if target === runtime {
                showAuthenticatedChatUI()
                setStatus("Аккаунт авторизован. Загружаю список переписок…")
            }
        } else if let type = object["@type"] as? String, type == "error" {
            if let extra = object["@extra"] as? String,
               let pending = pendingAuthRequestsByExtra.removeValue(forKey: extra) {
                guard !lockState, target === runtime, target.account == pending.account else { return }
                authRequestInFlight = false
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
               pendingHistoryByExtra.removeValue(forKey: extra) != nil {
                if !lockState, target === runtime { setStatus("Не удалось загрузить историю выбранной темы.") }
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
                    pendingStagedPhotoPaths[pending.intent.account]?.remove(attachment.localFileURL.standardizedFileURL)
                    try? FileManager.default.removeItem(at: attachment.localFileURL)
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

    private func deliverNotification(_ value: RoutedTDLibNotification, for target: LocalAccountRuntime) {
        guard target.telegramUserID != nil else { return }
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            Task { @MainActor [weak self] in
                guard let self, self.runtimesByAccount[value.account] === target else { return }
                let content = UNMutableNotificationContent()
                content.title = self.lockState ? "NeTelegram" : (self.chatRowsByAccount[value.account]?[value.conversation.chatID]?.title ?? "Новое сообщение")
                content.body = self.lockState ? "Новое сообщение" : (value.showsPreview ? (value.preview ?? "Новое сообщение") : "Новое сообщение")
                content.sound = value.isSilent ? nil : .default
                content.userInfo = ["route": value.systemIdentifier]
                let request = UNNotificationRequest(identifier: value.systemIdentifier, content: content, trigger: nil)
                try? await UNUserNotificationCenter.current().add(request)
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
            if self.lockState { self.showWindow(); return }
            switch value.conversation.topic {
            case .main, .forum: break
            default:
                self.setStatus("Уведомление сохранено для этой темы, но такой тип темы пока не поддержан интерфейсом.")
                self.showWindow()
                return
            }
            guard let accountRuntime = self.runtimesByAccount[value.account], accountRuntime.telegramUserID != nil else { return }
            self.runtime = accountRuntime
            self.refreshAccountPicker(select: value.account)
            if case .forum(let topicID) = value.conversation.topic {
                self.forumChatsByAccount[value.account, default: []].insert(value.conversation.chatID)
                self.selectedForumTopicIDsByAccount[value.account, default: [:]][value.conversation.chatID] = topicID
            }
            self.showWindow()
            self.openChat(chatID: value.conversation.chatID, in: accountRuntime)
        }
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

    private func refreshChatList() {
        guard chatList != nil else { return }
        clearStack(chatList)
        if !activeSearchQuery.isEmpty {
            if searchResults.isEmpty {
                let state = pendingSearchByExtra.isEmpty ? "Совпадений пока нет" : "Ищу в подключённых аккаунтах…"
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
        guard pendingSearchByExtra.isEmpty else {
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
            pendingSearchByExtra[chatsExtra] = PendingSearchRequest(account: accountRuntime.account, generation: generation)
            do {
                try accountRuntime.send(["@type": "searchChats", "query": query, "type_filter": NSNull(), "limit": 10, "@extra": chatsExtra])
            } catch {
                pendingSearchByExtra.removeValue(forKey: chatsExtra)
            }
            historyRequestCounter &+= 1
            let messagesExtra = "search-messages-\(generation)-\(historyRequestCounter)"
            pendingSearchByExtra[messagesExtra] = PendingSearchRequest(account: accountRuntime.account, generation: generation)
            do {
                try accountRuntime.send([
                    "@type": "searchMessages", "chat_list": NSNull(), "query": query,
                    "offset": "", "limit": 10,
                    "filter": ["@type": "searchMessagesFilterEmpty"],
                    "chat_type_filter": NSNull(), "min_date": 0, "max_date": 0,
                    "@extra": messagesExtra,
                ])
            } catch {
                pendingSearchByExtra.removeValue(forKey: messagesExtra)
            }
        }
        refreshChatList()
    }

    private func startDeferredSearchIfReady() {
        guard pendingSearchByExtra.isEmpty, let deferredSearch else { return }
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
        if forumChatsByAccount[account, default: []].contains(chatID),
           let topicID = selectedForumTopicIDsByAccount[account]?[chatID] {
            return ConversationKey(account: account, chatID: chatID, topic: .forum(topicID: topicID))
        }
        return ConversationKey(account: account, chatID: chatID)
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
        selectedForumTopicIDsByAccount[runtime.account, default: [:]][chatID] = topicID
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
        pendingHistoryByExtra[extra] = conversation
        messagesByConversation[conversation] = messagesByConversation[conversation] ?? []
        do {
            switch conversation.topic {
            case .forum(let topicID):
                try runtime.send(["@type": "getForumTopicHistory", "chat_id": chatID, "forum_topic_id": topicID, "from_message_id": anchorMessageID, "offset": 0, "limit": 50, "@extra": extra])
            case .main:
                try runtime.send(["@type": "getChatHistory", "chat_id": chatID, "from_message_id": anchorMessageID, "offset": 0, "limit": 50, "only_local": false, "@extra": extra])
            default:
                setStatus("Этот тип темы пока не поддержан.")
            }
        } catch {
            pendingHistoryByExtra.removeValue(forKey: extra)
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
        guard !unavailableDraftAccounts.contains(runtime.account) else {
            draftsByConversation[key] = composer.string
            dirtyDraftAccounts.insert(runtime.account)
            setStatus("Черновики недоступны из-за ошибки защищённого хранилища.")
            return
        }
        draftsByConversation[key] = composer.string
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
        guard !lockState, let runtime, let userID = runtime.telegramUserID,
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
        guard !lockState, let runtime, let userID = runtime.telegramUserID,
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
                    self.pendingStagedPhotoPaths[context.account]?.remove(stagedURL.standardizedFileURL)
                    try? FileManager.default.removeItem(at: stagedURL)
                    self.setStatus("Отправка фото отменена: блокировка или профиль изменились.")
                    return
                }
                self.pendingSendByExtra[extra] = PendingSend(intent: intent, text: context.caption)
                self.photoSendButton.isEnabled = false
                self.sendButton.isEnabled = false
                self.setStatus("Фото передано TDLib; ожидаю подтверждение.")
            } catch {
                self.pendingStagedPhotoPaths[context.account]?.remove(stagedURL.standardizedFileURL)
                try? FileManager.default.removeItem(at: stagedURL)
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
                pendingStagedPhotoPaths[account]?.remove(stagedURL.standardizedFileURL)
                try? FileManager.default.removeItem(at: stagedURL)
                return
            } else {
                stagedOutgoingPhotosByFileID[account, default: [:]][fileID] = stagedURL
            }
        }
    }

    private func finishOutgoingPhotoUploadIfReady(_ file: [String: Any], account: AccountUUID) {
        guard let fileID = (file["id"] as? NSNumber)?.int32Value,
              let remote = file["remote"] as? [String: Any],
              remote["is_uploading_completed"] as? Bool == true else { return }
        if let stagedURL = stagedOutgoingPhotosByFileID[account]?.removeValue(forKey: fileID) {
            pendingStagedPhotoPaths[account]?.remove(stagedURL.standardizedFileURL)
            try? FileManager.default.removeItem(at: stagedURL)
        } else if let local = file["local"] as? [String: Any],
                  let path = local["path"] as? String,
                  let stagedURL = pendingStagedPhotoPaths[account]?.first(where: { $0 == URL(fileURLWithPath: path).standardizedFileURL }) {
            pendingStagedPhotoPaths[account]?.remove(stagedURL)
            completedOutgoingPhotoFileIDs[account, default: []].insert(fileID)
            try? FileManager.default.removeItem(at: stagedURL)
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
        composer.isEditable = !lockState && topicIsReady && runtime.map { !unavailableDraftAccounts.contains($0.account) } == true
        guard !lockState, let runtime, let userID = runtime.telegramUserID,
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
                try store.save(draftsByConversation.filter { $0.key.account == account })
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
        let ordered = Array(messages)
        let ids = ordered.map { ($0["media_album_id"] as? NSNumber)?.int64Value ?? 0 }
        for run in MediaAlbumGrouping.runs(albumIDs: ids) {
            let items = run.messageIndices.map { ordered[$0] }
            if run.albumID == nil {
                for message in items { appendMessage(message) }
            } else {
                appendPhotoAlbum(items)
            }
        }
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
                appendMessage(message, into: tile, photoWidth: 180)
                row.addArrangedSubview(tile)
            }
            messageList.addArrangedSubview(row)
            offset += 3
        }
    }

    private func appendMessage(_ message: [String: Any], into stack: NSStackView? = nil, photoWidth: CGFloat = 320) {
        let destination: NSStackView = stack ?? messageList!
        guard let content = message["content"] as? [String: Any] else { return }
        let type = content["@type"] as? String ?? ""
        if type == "messagePhoto" {
            appendPhotoMessage(message, content: content, into: destination, width: photoWidth)
            appendReplyAction(message, into: destination)
            appendMessageActions(message, into: destination)
            return
        }
        let textValue: String
        if type == "messageText", let text = content["text"] as? [String: Any] {
            textValue = text["text"] as? String ?? ""
        } else {
            textValue = IncomingMessagePresentation.cardText(for: type)
        }
        let sender = message["sender_id"] as? [String: Any]
        let who = sender? ["@type"] as? String == "messageSenderUser" ? "Пользователь" : "Сообщение"
        let label = NSTextField(wrappingLabelWithString: "\(who): \(textValue)")
        label.font = .systemFont(ofSize: 14)
        label.maximumNumberOfLines = 0
        label.setAccessibilityLabel("\(who). \(textValue)")
        destination.addArrangedSubview(label)
        appendReplyAction(message, into: destination)
        appendMessageActions(message, into: destination)
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

    private func updateCachedMessage(_ message: [String: Any], for account: AccountUUID) {
        guard let chatID = (message["chat_id"] as? NSNumber)?.int64Value,
              let messageID = (message["id"] as? NSNumber)?.int64Value else { return }
        let key = conversationKey(for: message, account: account, chatID: chatID)
        if var cache = messagesByConversation[key],
           let index = cache.firstIndex(where: { ($0["id"] as? NSNumber)?.int64Value == messageID }) {
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

        let caption = ((content["caption"] as? [String: Any])?["text"] as? String ?? "")
        if !caption.isEmpty {
            let label = NSTextField(wrappingLabelWithString: caption)
            label.font = .systemFont(ofSize: 13)
            label.maximumNumberOfLines = 0
            destination.addArrangedSubview(label)
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
        pendingPhotoByExtra = pendingPhotoByExtra.filter {
            $0.value.account != target.account || $0.value.chatID != chatID || $0.value.fileID != fileID
        }
        for key in photoViews.keys where key.account == target.account && key.chatID == chatID && key.fileID == fileID {
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
        authStack.isHidden = true
        chatPane.isHidden = false
        window.title = runtime.flatMap(safeAccountName).map { "\($0) — NeTelegram" } ?? "NeTelegram"
    }

    private func targetIsAuthorizedSelected() -> Bool { runtime?.telegramUserID != nil }

    private func safeAccountName(_ runtime: LocalAccountRuntime) -> String? {
        AccountPresentation.verifiedDisplayName(
            telegramUserID: runtime.telegramUserID,
            candidate: runtime.displayName
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
        authStack.isHidden = false
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

    private func showEmailEntry() {
        authStack.isHidden = false
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
        authStack.isHidden = false
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
        let kind = ((codeInfo["type"] as? [String: Any])?["@type"] as? String) ?? ""
        switch kind {
        case "authenticationCodeTypeTelegramMessage": return "Введите код из сообщения Telegram на другом устройстве."
        case "authenticationCodeTypeSms": return "Введите код из SMS."
        case "authenticationCodeTypeCall": return "Введите код из телефонного звонка."
        case "authenticationCodeTypeSmsWord": return "Введите слово из SMS."
        case "authenticationCodeTypeSmsPhrase": return "Введите фразу из SMS."
        case "authenticationCodeTypeFlashCall", "authenticationCodeTypeMissedCall": return "Следуйте инструкции для подтверждения звонком."
        default: return "Введите код, указанный в сообщении Telegram или способом, выбранным для этого входа."
        }
    }

    private func showPhoneEntry() {
        authStack.isHidden = false
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
        actionButton.isHidden = false
        actionButton.title = "Продолжить"
        actionButton.isEnabled = !authRequestInFlight
        setStatus(phoneCountries.isEmpty
            ? "Введите полный номер с + и кодом страны. Загружаю список стран…"
            : "Выберите страну и введите номер телефона.")
        phoneField.becomeFirstResponder()
    }

    @objc private func selectCountry() {
        let index = countryPicker.indexOfSelectedItem
        guard phoneCountries.indices.contains(index) else { return }
        selectedCallingCode = phoneCountries[index].callingCodes[0]
    }

    @objc private func beginQRLogin() {
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
            authRequestInFlight = true
            qrButton.isEnabled = false
            historyRequestCounter &+= 1
            let extra = "auth-\(historyRequestCounter)"
            try runtime.send(["@type": "requestQrCodeAuthentication", "other_user_ids": [], "@extra": extra])
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
        searchDebounceTask?.cancel()
        searchDebounceTask = nil
        searchGeneration &+= 1
        deferredSearch = nil
        activeSearchQuery = ""
        searchField.stringValue = ""
        searchResults.removeAll()
        searchResultByControlID.removeAll()
        pendingSearchByExtra.removeAll()
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
        registrationConsent.state = .off
        authRequestInFlight = false
        for (account, info) in Array(authPresentationInfoByAccount) {
            if let terms = info["terms_of_service"] {
                authPresentationInfoByAccount[account] = ["terms_of_service": terms]
            } else {
                authPresentationInfoByAccount.removeValue(forKey: account)
            }
        }
        cancelAllPhotoDownloads()
        let draftsFlushed = flushDirtyDraftsBeforeQuit()
        lockState = true
        privacyDispatchBarrier.setLocked(true)
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
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
        pendingHistoryByExtra.removeAll()
        pendingForumTopicsByExtra.removeAll()
        selectedChatByAccount.removeAll()
        if draftsFlushed { draftsByConversation.removeAll() }
        clearStack(chatList)
        photoPipeline.cancelAllPreviews()
        closePhotoViewer()
        for account in runtimesByAccount.keys { photoPipeline.removeCachedPreviews(for: account) }
        clearStack(messageList)
        setComposerText("")
        refreshComposerState()
        lockedView.isHidden = false
        window.title = "Заблокировано — NeTelegram"
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
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Разблокировать NeTelegram") { [weak self] success, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.unlockInProgress = false
                guard self.lockState, success else { return }
                self.lockState = false
                self.privacyDispatchBarrier.setLocked(false)
                self.lockedView.isHidden = true
                if let selected = self.runtime, selected.telegramUserID != nil {
                    self.reloadPersistedDrafts(for: selected.account)
                    selected.loadMainChats(reload: true)
                    self.showAuthenticatedChatUI()
                    self.refreshChatList()
                    self.displaySelectedConversation()
                    self.window.title = self.safeAccountName(selected).map { "\($0) — NeTelegram" } ?? "NeTelegram"
                } else if let selected = self.runtime {
                    switch self.pendingAuthorizationType {
                    case "authorizationStateWaitPhoneNumber": self.showPhoneEntry()
                    case "authorizationStateWaitCode": self.showAuthInput("Введите код, полученный для этого входа.", placeholder: "Код", button: "Продолжить")
                    case "authorizationStateWaitPassword": self.showAuthInput("Введите пароль двухэтапной проверки. Он не сохраняется.", placeholder: "Пароль двухэтапной проверки", button: "Продолжить")
                    case "authorizationStateWaitEmailAddress": self.showEmailEntry()
                    case "authorizationStateWaitEmailCode": self.showEmailCode(self.authPresentationInfoByAccount[selected.account] ?? [:])
                    case "authorizationStateWaitRegistration": self.showRegistration(self.authPresentationInfoByAccount[selected.account] ?? [:])
                    default: break
                    }
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

private struct PendingSend {
    let intent: SendIntent
    let text: String
}

private enum InitialAuthorizationAction {
    case phoneNumber(String)
    case qrCode
}

private struct PendingSearchRequest {
    let account: AccountUUID
    let generation: UInt64
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
    fileprivate var route: RuntimeRoute?
    fileprivate let generation: RuntimeGeneration
    private var closeRequested = false
    private var didRequestCurrentUser = false
    private var didLoadMainChats = false
    private var didSendTDLibParameters = false
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
        let bytes = try JSONSerialization.data(withJSONObject: request, options: [.sortedKeys])
        try gateway.send(String(decoding: bytes, as: UTF8.self), to: route.client)
        if request["@type"] as? String == "setTdlibParameters" { didSendTDLibParameters = true }
    }

    func applyNetworkType(_ type: String) throws {
        guard didSendTDLibParameters,
              authorizationState != "authorizationStateClosed",
              authorizationState != "authorizationStateClosing" else { return }
        try send(["@type": "setNetworkType", "type": ["@type": type]])
    }

    func loadMainChats(reload: Bool = false) {
        guard authorizationState == "authorizationStateReady", telegramUserID != nil else { return }
        if reload { didLoadMainChats = false }
        guard !didLoadMainChats else { return }
        do {
            try send(["@type": "loadChats", "chat_list": NSNull(), "limit": 100])
            didLoadMainChats = true
        } catch {
            // A later account selection or explicit reopen can retry safely.
        }
    }

    func consume(_ update: Data) async {
        guard let object = (try? JSONSerialization.jsonObject(with: update)) as? [String: Any] else { return }
        if object["@type"] as? String == "updateAuthorizationState",
           let authorization = object["authorization_state"] as? [String: Any],
           let state = authorization["@type"] as? String {
            authorizationState = state
            if state == "authorizationStateReady", !didRequestCurrentUser {
                didRequestCurrentUser = true
                try? send(["@type": "getMe"])
            }
        } else if object["@type"] as? String == "error" {
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
        guard !closeRequested else { return true }
        do {
            try send(["@type": "close"])
            closeRequested = true
            return true
        } catch {
            // Keep the receive worker alive. Without a close acknowledgement,
            // the app must not claim a clean TDLib shutdown.
            lastTDLibError = "TDLib close request failed"
            return false
        }
    }

    func finishClose() {}
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
