import Foundation
import CoreGraphics
import ImageIO
import Security
import Testing
@testable import NeTelegramCore

@Test func sponsoredMessagesCacheExpiresAtFiveMinutesAndRejectsFutureTimestamp() {
    let now = Date(timeIntervalSince1970: 10_000)
    #expect(SponsoredMessagesPolicy.shouldRequest(lastFetchedAt: nil, now: now))
    #expect(!SponsoredMessagesPolicy.shouldRequest(lastFetchedAt: now.addingTimeInterval(-299), now: now))
    #expect(SponsoredMessagesPolicy.shouldRequest(lastFetchedAt: now.addingTimeInterval(-300), now: now))
    #expect(SponsoredMessagesPolicy.shouldRequest(lastFetchedAt: now.addingTimeInterval(1), now: now))
}

@Test func phoneNumberInputRejectsAmbiguousAndMalformedNumbersWithoutSilentMutation() {
    #expect(PhoneNumberInputPolicy.validate("(555) 123-4567", selectedCallingCode: "1") == .accepted("+15551234567"))
    #expect(PhoneNumberInputPolicy.validate("+44 20 7183 8750", selectedCallingCode: "1") == .accepted("+442071838750"))
    #expect(PhoneNumberInputPolicy.validate("٢٣٤٥٦٧٨٩", selectedCallingCode: "1") == .accepted("+123456789"))
    #expect(PhoneNumberInputPolicy.validate("12a345", selectedCallingCode: "1") == .invalidCharacters)
    #expect(PhoneNumberInputPolicy.validate("+1+5551234", selectedCallingCode: "1") == .invalidCharacters)
    #expect(PhoneNumberInputPolicy.validate("1 (555) 123-4567", selectedCallingCode: "1") == .repeatedCountryCode)
    #expect(PhoneNumberInputPolicy.validate("+1234", selectedCallingCode: "1") == .accepted("+1234"))
    #expect(PhoneNumberInputPolicy.validate("+123456789012345", selectedCallingCode: "1") == .accepted("+123456789012345"))
    #expect(PhoneNumberInputPolicy.validate("+123", selectedCallingCode: "1") == .invalidLength)
    #expect(PhoneNumberInputPolicy.validate("+1234567890123456", selectedCallingCode: "1") == .invalidLength)
    #expect(PhoneNumberInputPolicy.validate("   ", selectedCallingCode: "1") == .empty)
    #expect(PhoneNumberInputPolicy.validate("5551234", selectedCallingCode: "US") == .invalidCountryCode)
}

@Test func sponsoredChannelPlacementsRespectServerIntervalAndKeepAlbumsWhole() {
    let spaced = SponsoredMessagesPolicy.placements(
        cardCount: 5,
        ordinaryMessageCount: 50,
        albumEndMessageCounts: Array(1...50),
        messagesBetween: 20
    )
    #expect(spaced == [
        SponsoredMessagePlacement(cardIndex: 0, afterMessageCount: 50),
        SponsoredMessagePlacement(cardIndex: 1, afterMessageCount: 30),
        SponsoredMessagePlacement(cardIndex: 2, afterMessageCount: 10),
    ])

    let albums = SponsoredMessagesPolicy.placements(
        cardCount: 4,
        ordinaryMessageCount: 31,
        albumEndMessageCounts: [5, 11, 16, 27],
        messagesBetween: 10
    )
    #expect(albums == [
        SponsoredMessagePlacement(cardIndex: 0, afterMessageCount: 31),
        SponsoredMessagePlacement(cardIndex: 1, afterMessageCount: 16),
        SponsoredMessagePlacement(cardIndex: 2, afterMessageCount: 5),
    ])

    let zeroInterval = SponsoredMessagesPolicy.placements(
        cardCount: 3,
        ordinaryMessageCount: 8,
        albumEndMessageCounts: [2, 4, 8],
        messagesBetween: 0
    )
    #expect(zeroInterval == [SponsoredMessagePlacement(cardIndex: 0, afterMessageCount: 8)])
}

@Test func sponsoredMessageRequestsKeepServerChatAndMessageIDs() {
    let load = SponsoredMessagesPolicy.request(chatID: 73, extra: "sponsored-1")
    #expect(load["@type"] as? String == "getChatSponsoredMessages")
    #expect((load["chat_id"] as? NSNumber)?.int64Value == 73)
    #expect(load["@extra"] as? String == "sponsored-1")

    let click = SponsoredMessagesPolicy.click(chatID: 73, messageID: 91, media: true, fullscreen: false)
    #expect(click["@type"] as? String == "clickChatSponsoredMessage")
    #expect((click["chat_id"] as? NSNumber)?.int64Value == 73)
    #expect((click["message_id"] as? NSNumber)?.int64Value == 91)
    #expect(click["is_media_click"] as? Bool == true)
    #expect(click["from_fullscreen"] as? Bool == false)

    let report = SponsoredMessagesPolicy.report(chatID: 73, messageID: 91, optionID: "option", extra: "report-1")
    #expect(report["@type"] as? String == "reportChatSponsoredMessage")
    #expect(report["option_id"] as? String == "option")
    #expect(report["@extra"] as? String == "report-1")
}

@Test func sponsoredReportOptionsKeepOpaqueTDLibByteIDsAndLocalizedLabels() {
    let options = SponsoredReportResult.options(from: [
        "@type": "reportSponsoredResultOptionRequired",
        "options": [
            ["@type": "reportOption", "id": "AQID", "text": "Недостоверная информация"],
            ["@type": "reportOption", "id": "BAUG", "text": "Спам"],
            ["@type": "reportOption", "id": "", "text": "ignored"],
        ],
    ])
    #expect(options.map(\.id) == ["AQID", "BAUG"])
    #expect(options.map(\.text) == ["Недостоверная информация", "Спам"])
    #expect(SponsoredReportResult.type(from: ["@type": "reportSponsoredResultOptionRequired"]) == "reportSponsoredResultOptionRequired")
}

@Test func sponsoredMessageCardPreservesLabelsTextAndSponsorContext() {
    let card = SponsoredMessageCard(tdlibObject: [
        "message_id": 17,
        "is_recommended": true,
        "can_be_reported": true,
        "title": "Partner",
        "button_text": "Open",
        "additional_info": "Terms apply",
        "content": ["@type": "messageText", "text": ["text": "Hello 👋"]],
        "sponsor": ["url": "https://example.org/", "info": "Sponsor details"],
    ])
    #expect(card?.messageID == 17)
    #expect(card?.recommended == true)
    #expect(card?.reportable == true)
    #expect(card?.text == "Hello 👋")
    #expect(card?.buttonText == "Open")
    #expect(card?.sponsorInfo == "Sponsor details")
    #expect(card?.additionalInfo == "Terms apply")
}

@Test func sponsoredMessageCardKeepsUnsupportedMediaTypeVisibleForFallback() {
    let card = SponsoredMessageCard(tdlibObject: [
        "message_id": 18,
        "title": "Media sponsor",
        "button_text": "Visit",
        "content": ["@type": "messageVideo"],
        "sponsor": ["url": "https://example.org/"],
    ])
    #expect(card?.contentType == "messageVideo")
    #expect(card?.text == "")
}

@Test func sponsoredPhotoCardSelectsFullTDLibPhotoVariantWithoutDownloadingIt() {
    let card = SponsoredMessageCard(tdlibObject: [
        "message_id": 19,
        "title": "Photo sponsor",
        "button_text": "Visit",
        "content": [
            "@type": "messagePhoto",
            "caption": ["text": "Sponsored caption"],
            "photo": ["sizes": [
                ["width": 320, "height": 240, "photo": ["id": 201, "expected_size": 12000, "local": ["can_be_downloaded": true, "is_downloading_completed": false, "path": ""]]],
                ["width": 1920, "height": 1440, "photo": ["id": 202, "expected_size": 420000, "local": ["can_be_downloaded": true, "is_downloading_completed": false, "path": ""]]],
            ]],
        ],
        "sponsor": ["url": "https://example.org/"],
    ])
    #expect(card?.contentType == "messagePhoto")
    #expect(card?.text == "Sponsored caption")
    #expect(card?.photo?.fileID == 202)
    #expect(card?.photo?.isDownloaded == false)
}

@Test func authenticationCodePromptUsesMaskedTDLibDestination() {
    let message = AuthenticationCodePrompt.message(
        codeType: "authenticationCodeTypeTelegramMessage",
        phoneNumber: "+1 (555) 123-4567"
    )
    #expect(message.contains("сообщения Telegram"))
    #expect(message.contains("Номер: +••••••67"))
    #expect(!message.contains("555"))
    #expect(!message.contains("123-4567"))
}

@Test func authenticationCodePromptHandlesUnknownMethodWithoutLeakingShortNumbers() {
    let message = AuthenticationCodePrompt.message(codeType: nil, phoneNumber: "+123")
    #expect(message.contains("способом, выбранным"))
    #expect(!message.contains("Номер:"))
    #expect(AuthenticationCodePrompt.message(codeType: "authenticationCodeTypeSms", phoneNumber: nil) == "Введите код из SMS.")
}

@Test func terminationBarrierWaitsForAccountCloseAndReceiverDrain() {
    var barrier = TerminationBarrier()
    #expect(!barrier.isPending)
    #expect(!barrier.isFinished)

    let drainBeforeAccountClose = barrier.beginReceiverDrain()
    #expect(!drainBeforeAccountClose)
    barrier.begin()
    #expect(barrier.isPending)

    let beganDrain = barrier.beginReceiverDrain()
    #expect(beganDrain)
    #expect(barrier.isPending)
    let finishedDrain = barrier.finishReceiverDrain()
    #expect(finishedDrain)
    #expect(barrier.isFinished)
    let duplicateFinish = barrier.finishReceiverDrain()
    #expect(!duplicateFinish)
}

@Test func terminationBarrierCancellationAllowsRetryAfterRejectedClose() {
    var barrier = TerminationBarrier()
    barrier.begin()
    barrier.cancel()
    #expect(!barrier.isPending)
    let drainAfterCancel = barrier.beginReceiverDrain()
    #expect(!drainAfterCancel)

    barrier.begin()
    let beganRetryDrain = barrier.beginReceiverDrain()
    #expect(beganRetryDrain)
    let finishedRetryDrain = barrier.finishReceiverDrain()
    #expect(finishedRetryDrain)
    #expect(barrier.isFinished)
}

private final class LockedTestValue<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Value

    init(_ value: Value) { stored = value }

    func set(_ value: Value) {
        lock.lock()
        stored = value
        lock.unlock()
    }

    func mutate(_ body: (inout Value) -> Void) {
        lock.lock()
        body(&stored)
        lock.unlock()
    }

    func get() -> Value {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }
}

private actor AsyncTestGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }
}

private func waitForTrue(_ value: LockedTestValue<Bool>, timeout: Duration) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while clock.now < deadline {
        if value.get() { return true }
        try? await Task.sleep(for: .milliseconds(1))
    }
    return value.get()
}

@Test func accountPresentationNeverExposesLocalOrUnverifiedProfileNames() {
    #expect(AccountPresentation.verifiedDisplayName(telegramUserID: nil, candidate: "Test User") == nil)
    #expect(AccountPresentation.verifiedDisplayName(telegramUserID: 123, candidate: nil) == nil)
    #expect(AccountPresentation.verifiedDisplayName(telegramUserID: 123, candidate: "  ") == nil)
    #expect(AccountPresentation.verifiedDisplayName(telegramUserID: 123, candidate: "6BFF7C49-92B1-4883-8262-BF1E56906A42") == nil)
    #expect(AccountPresentation.verifiedDisplayName(telegramUserID: 123, candidate: " Test User ") == "Test User")
}

@Test func unlockRestoresOnlyVerifiedAndCurrentAuthorizationIdentity() {
    #expect(AccountPresentation.restoresAuthenticatedChat(telegramUserID: 441, authorizationState: nil))
    #expect(AccountPresentation.restoresAuthenticatedChat(telegramUserID: 441, authorizationState: "authorizationStateReady"))
    #expect(!AccountPresentation.restoresAuthenticatedChat(telegramUserID: nil, authorizationState: "authorizationStateReady"))
    #expect(!AccountPresentation.restoresAuthenticatedChat(telegramUserID: 441, authorizationState: "authorizationStateClosing"))
    #expect(!AccountPresentation.restoresAuthenticatedChat(telegramUserID: 441, authorizationState: "authorizationStateWaitCode"))
}

@Test func accountPickerUsesHumanLocalLabelsAndExplicitAuthorizationStatus() {
    let firstPending = AccountPresentation.pickerTitle(
        localOrdinal: 1,
        telegramUserID: nil,
        candidate: "6BFF7C49-92B1-4883-8262-BF1E56906A42",
        authorizationState: "authorizationStateWaitPhoneNumber",
        runtimeIsOpen: true,
        hasError: false
    )
    let secondPending = AccountPresentation.pickerTitle(
        localOrdinal: 2,
        telegramUserID: nil,
        candidate: "Unverified name",
        authorizationState: "authorizationStateWaitCode",
        runtimeIsOpen: true,
        hasError: false
    )
    let verified = AccountPresentation.pickerTitle(
        localOrdinal: 3,
        telegramUserID: 123,
        candidate: "Test User",
        authorizationState: "authorizationStateReady",
        runtimeIsOpen: true,
        hasError: false
    )

    #expect(firstPending == "Локальный вход 1 — ожидает номер")
    #expect(secondPending == "Локальный вход 2 — ожидает код")
    #expect(verified == "Test User · профиль 3 — подключён")
    #expect(!firstPending.contains("6BFF7C49"))
    #expect(!secondPending.contains("Unverified name"))
    #expect(AccountPresentation.pickerStatus(
        telegramUserID: nil,
        authorizationState: nil,
        runtimeIsOpen: false,
        hasError: true
    ) == .failed)
    #expect(AccountPresentation.pickerStatus(
        telegramUserID: nil,
        authorizationState: "authorizationStateWaitPremiumPurchase",
        runtimeIsOpen: true,
        hasError: false
    ) == .purchaseRequired)
    #expect(AccountPresentation.pickerStatus(
        telegramUserID: nil,
        authorizationState: "authorizationStateWaitEncryptionKey",
        runtimeIsOpen: true,
        hasError: false
    ) == .unsupported)
}

@Test func unsupportedIncomingContentKeepsHumanReadableContextWithoutLeakingConstructors() {
    #expect(IncomingMessagePresentation.cardText(for: "messageVoiceNote") == "Голосовое сообщение · воспроизведение не поддерживается")
    #expect(IncomingMessagePresentation.chatPreview(for: "messagePaidMedia") == "Платный контент")
    #expect(IncomingMessagePresentation.cardText(for: "messageFutureType").contains("Вложение или новый тип сообщения"))
    #expect(!IncomingMessagePresentation.cardText(for: "messageFutureType").contains("messageFutureType"))
    #expect(IncomingMessagePresentation.cardText(for: "messagePaidMedia").contains("не выполняет оплату"))
}

@Test func developmentBundlesGetSeparateAccountCataloguesAndReleasePathStaysStable() {
    let support = URL(fileURLWithPath: "/tmp/example-support", isDirectory: true)
    let first = AccountStorageRoot.resolve(
        applicationSupportDirectory: support,
        bundleIdentifier: "org.example.app.first",
        isDevelopmentBuild: true
    )
    let second = AccountStorageRoot.resolve(
        applicationSupportDirectory: support,
        bundleIdentifier: "org.example.app.second",
        isDevelopmentBuild: true
    )
    let releaseA = AccountStorageRoot.resolve(
        applicationSupportDirectory: support,
        bundleIdentifier: "org.example.app.first",
        isDevelopmentBuild: false
    )
    let releaseB = AccountStorageRoot.resolve(
        applicationSupportDirectory: support,
        bundleIdentifier: "org.example.app.second",
        isDevelopmentBuild: false
    )
    let override = AccountStorageRoot.resolve(
        applicationSupportDirectory: support,
        bundleIdentifier: "org.example.app.first",
        isDevelopmentBuild: true,
        override: URL(fileURLWithPath: "/tmp/isolation")
    )

    #expect(first != second)
    #expect(releaseA == releaseB)
    #expect(override.path == "/tmp/isolation")
    #expect(!first.path.contains("/../"))
}

@Test func secretsStoreUsesStandardMacOSKeychainWithoutUnsupportedAttributes() {
    let query = SecretsStore.itemQuery(account: "test-account", service: "test-service")
    #expect(query[kSecAttrAccount as String] as? String == "test-account")
    #expect(query[kSecAttrService as String] as? String == "test-service")
    #expect(query[kSecUseDataProtectionKeychain as String] == nil)
    #expect(query[kSecAttrAccessible as String] == nil)
}

@Test func startupLimitDoesNotBecomeResidentAccountLimit() async throws {
    let coordinator = RuntimeCoordinator(startupParallelism: 2)
    #expect(await coordinator.acquireStartupPermit())
    #expect(await coordinator.acquireStartupPermit())
    #expect(!(await coordinator.acquireStartupPermit()))
    await coordinator.releaseStartupPermit()
    #expect(await coordinator.acquireStartupPermit())

    for n in 1...20 {
        let account = AccountUUID()
        let generation = RuntimeGeneration(UInt64(n))
        let route = RuntimeRoute(account: account, generation: generation, client: ClientID(Int32(n)))
        try await coordinator.registerBeforeFirstRequest(route)
        await coordinator.setState(.active(telegramUserID: Int64(n)), for: account)
    }
    for n in 1...20 {
        #expect(await coordinator.route(for: ClientID(Int32(n)))?.generation == RuntimeGeneration(UInt64(n)))
    }
}

@Test func accountRestoreIncludesStoredUnverifiedSessionsButSkipsEmptyPlaceholders() {
    let authorized = AccountProfile(id: AccountUUID(UUID(uuidString: "10000000-0000-0000-0000-000000000001")!), telegramUserID: 501)
    let emptyPending = AccountProfile(id: AccountUUID(UUID(uuidString: "20000000-0000-0000-0000-000000000001")!), createdAt: Date(timeIntervalSince1970: 1))
    let storedPending = AccountProfile(id: AccountUUID(UUID(uuidString: "20000000-0000-0000-0000-000000000002")!), createdAt: Date(timeIntervalSince1970: 2))

    #expect(AccountRestorePlanner.profilesToRestore(
        authorized: [authorized],
        pending: [emptyPending, storedPending],
        pendingWithStoredDatabase: [storedPending.id]
    ) == [authorized, storedPending])
    #expect(AccountRestorePlanner.profilesToRestore(
        authorized: [],
        pending: [emptyPending, storedPending],
        pendingWithStoredDatabase: []
    ) == [emptyPending])
    #expect(AccountRestorePlanner.profilesToRestore(
        authorized: [],
        pending: [emptyPending, storedPending],
        pendingWithStoredDatabase: [storedPending.id]
    ) == [storedPending])
}

@Test func chatListSnapshotCanReloadAfterPrivacyLockAndAfterRequestFailure() {
    var state = ChatListLoadState()
    let firstLoad = state.beginLoad()
    #expect(firstLoad)
    #expect(state.state == .loading)
    let duplicateLoad = state.beginLoad()
    #expect(!duplicateLoad)

    state.completeLoad()
    #expect(state.state == .loaded)
    let alreadyLoaded = state.beginLoad()
    #expect(!alreadyLoaded)

    state.invalidate()
    #expect(state.state == .needsLoad)
    let privacyReload = state.beginLoad()
    #expect(privacyReload)
    state.failLoad()
    let retryAfterFailure = state.beginLoad()
    #expect(retryAfterFailure)
    state.completeLoad()
    #expect(state.state == .loaded)

    let forcedReload = state.beginLoad(reload: true)
    #expect(forcedReload)
    #expect(state.state == .loading)
}

@Test func restorePlanIncludesAllTwentyAuthorizedProfilesAndStartupQueueDrains() async {
    let profiles = (1...20).map { n in
        AccountProfile(
            id: AccountUUID(UUID(uuidString: String(format: "30000000-0000-0000-0000-%012d", n))!),
            telegramUserID: Int64(10_000 + n)
        )
    }
    let plan = AccountRestorePlanner.profilesToRestore(
        authorized: profiles,
        pending: [],
        pendingWithStoredDatabase: []
    )
    #expect(plan == profiles)

    let scheduler = RuntimeStartupScheduler(parallelism: 2)
    await scheduler.acquire()
    await scheduler.acquire()
    let queuedStarts = (0..<18).map { _ in Task { await scheduler.acquire() } }
    var allQueued = false
    for _ in 0..<2_000 {
        if await scheduler.queuedStarts() == 18 {
            allQueued = true
            break
        }
        try? await Task.sleep(for: .milliseconds(1))
    }
    #expect(allQueued)
    #expect(await scheduler.activeStarts() == 2)

    for _ in 0..<20 {
        await scheduler.release()
        #expect(await scheduler.activeStarts() <= 2)
    }
    for start in queuedStarts { await start.value }
    #expect(await scheduler.activeStarts() == 0)
    #expect(await scheduler.queuedStarts() == 0)
}

@Test func runtimeGenerationChangesForEveryClientOfAnAccount() async {
    let coordinator = RuntimeCoordinator()
    let account = AccountUUID()
    #expect(await coordinator.nextGeneration(for: account) == RuntimeGeneration(1))
    #expect(await coordinator.nextGeneration(for: account) == RuntimeGeneration(2))
}

@Test func authorizationReducerTracksLifecycleAndRejectsStaleRuntimeEvents() async throws {
    let coordinator = RuntimeCoordinator()
    let account = AccountUUID()
    let oldRoute = RuntimeRoute(account: account, generation: RuntimeGeneration(1), client: ClientID(91))
    try await coordinator.registerBeforeFirstRequest(oldRoute)

    #expect(await coordinator.applyAuthorizationState("authorizationStateWaitPhoneNumber", telegramUserID: nil, from: oldRoute))
    #expect(await coordinator.state(for: account) == .needsAuthorization)
    #expect(await coordinator.applyAuthorizationState("authorizationStateReady", telegramUserID: nil, from: oldRoute))
    #expect(await coordinator.state(for: account) == .readyIdentityPending)
    #expect(await coordinator.applyAuthorizationState("authorizationStateReady", telegramUserID: 441, from: oldRoute))
    #expect(await coordinator.state(for: account) == .active(telegramUserID: 441))

    let newRoute = RuntimeRoute(account: account, generation: RuntimeGeneration(2), client: ClientID(92))
    await #expect(throws: RuntimeError.generationAlreadyRouted) {
        try await coordinator.registerBeforeFirstRequest(newRoute)
    }
    #expect(await coordinator.applyAuthorizationState("authorizationStateClosed", telegramUserID: nil, from: oldRoute))
    #expect(await coordinator.route(for: oldRoute.client) == nil)
    try await coordinator.registerBeforeFirstRequest(newRoute)
    #expect(!(await coordinator.applyAuthorizationState("authorizationStateClosed", telegramUserID: nil, from: oldRoute)))
    #expect(await coordinator.route(for: newRoute.client) == newRoute)
    #expect(await coordinator.state(for: account) == .starting)

    #expect(await coordinator.applyAuthorizationState("authorizationStateClosing", telegramUserID: 441, from: newRoute))
    #expect(await coordinator.state(for: account) == .closing)
    #expect(await coordinator.applyAuthorizationState("authorizationStateClosed", telegramUserID: nil, from: newRoute))
    #expect(await coordinator.state(for: account) == .closed)
    #expect(await coordinator.route(for: newRoute.client) == nil)
}

@Test func rejectedFirstRequestRemovesOnlyItsUninitializedRoute() async throws {
    let coordinator = RuntimeCoordinator()
    let account = AccountUUID()
    let first = RuntimeRoute(account: account, generation: RuntimeGeneration(1), client: ClientID(301))
    try await coordinator.registerBeforeFirstRequest(first)

    #expect(await coordinator.removeRouteAfterInitializationRequestRejected(first))
    #expect(await coordinator.route(for: first.client) == nil)
    #expect(await coordinator.state(for: account) == .failed("TDLib initialization request could not be queued"))

    let retry = RuntimeRoute(account: account, generation: RuntimeGeneration(2), client: ClientID(302))
    try await coordinator.registerBeforeFirstRequest(retry)
    #expect(await coordinator.route(for: retry.client) == retry)
    #expect(!(await coordinator.removeRouteAfterInitializationRequestRejected(first)))
    #expect(await coordinator.route(for: retry.client) == retry)
}

@Test func startupSchedulerQueuesPastTheParallelOpenLimit() async {
    let scheduler = RuntimeStartupScheduler(parallelism: 2)
    await scheduler.acquire()
    await scheduler.acquire()
    let third = Task { await scheduler.acquire() }

    // A broken scheduler must fail this test instead of hanging the whole CI job.
    var queued = false
    for _ in 0..<2_000 {
        if await scheduler.queuedStarts() == 1 {
            queued = true
            break
        }
        try? await Task.sleep(for: .milliseconds(1))
    }
    #expect(queued)
    #expect(await scheduler.activeStarts() == 2)
    await scheduler.release()
    var thirdStarted = false
    for _ in 0..<2_000 {
        if await scheduler.activeStarts() == 2 {
            thirdStarted = true
            break
        }
        try? await Task.sleep(for: .milliseconds(1))
    }
    #expect(thirdStarted)
    await scheduler.release()
    await scheduler.release()
    // Once both permits have been released, the queued acquire has no reason to remain blocked.
    await third.value
    #expect(await scheduler.activeStarts() == 0)
}

@Test func criticalEventsAreNotCoalescedAway() async {
    let coordinator = RuntimeCoordinator()
    #expect(await coordinator.mayCoalesce(.ordinaryState))
    #expect(!(await coordinator.mayCoalesce(.authorization)))
    #expect(!(await coordinator.mayCoalesce(.deletion)))
    #expect(!(await coordinator.mayCoalesce(.ttl)))
}

@Test func networkTypePolicyTracksPathEventsEvenWhenTDLibTypeIsUnchanged() {
    #expect(NetworkTypeUpdatePolicy.tdlibType(isSatisfied: false, usesWiFi: false, usesCellular: false) == "networkTypeNone")
    #expect(NetworkTypeUpdatePolicy.tdlibType(isSatisfied: true, usesWiFi: true, usesCellular: false) == "networkTypeWiFi")
    #expect(NetworkTypeUpdatePolicy.tdlibType(isSatisfied: true, usesWiFi: false, usesCellular: true) == "networkTypeMobile")
    #expect(NetworkTypeUpdatePolicy.tdlibType(isSatisfied: true, usesWiFi: false, usesCellular: false) == "networkTypeOther")
    #expect(NetworkTypeUpdatePolicy.tdlibType(isSatisfied: true, usesWiFi: true, usesCellular: true) == "networkTypeWiFi")
    #expect(!NetworkTypeUpdatePolicy.shouldApply(currentRevision: 8, nextRevision: 8))
    #expect(NetworkTypeUpdatePolicy.shouldApply(currentRevision: 8, nextRevision: 9)) // Wi-Fi route A → B
    #expect(NetworkTypeUpdatePolicy.shouldApply(currentRevision: 9, nextRevision: 10)) // offline → online
    #expect(NetworkTypeUpdatePolicy.shouldApply(currentRevision: 10, nextRevision: 10, force: true)) // wake
}

@Test func networkPathRevisionGateRejectsDuplicatesAndSupersededDebounceWork() {
    var gate = NetworkPathRevisionGate()
    let acceptedFirst = gate.accept(1)
    let acceptedDuplicate = gate.accept(1)
    #expect(acceptedFirst)
    #expect(!acceptedDuplicate)
    #expect(gate.isLatest(1))

    let acceptedSecond = gate.accept(2) // Wi-Fi route B arrives before A's debounce expires.
    let acceptedThird = gate.accept(3) // Route C supersedes B; only C may be applied.
    #expect(acceptedSecond)
    #expect(acceptedThird)
    #expect(!gate.isLatest(1))
    #expect(!gate.isLatest(2))
    #expect(gate.isLatest(3))
    let acceptedLate = gate.accept(2) // Late delivery from an older actor task.
    #expect(!acceptedLate)
}

@Test func networkPathRevisionCounterProducesMonotonicObservations() {
    let counter = NetworkPathRevisionCounter()
    #expect(counter.next() == 1)
    #expect(counter.next() == 2)
    #expect(counter.next() == 3)
}

@Test func updateBufferPreservesFIFOAndBackpressuresAtCapacity() async {
    let buffer = TDLibUpdateBuffer(capacity: 1)
    let first = Data("first".utf8)
    let second = Data("second".utf8)
    #expect(buffer.append(first))
    let producer = Task.detached {
        return buffer.append(second)
    }
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(1))
    while buffer.blockedProducerCount == 0 && clock.now < deadline {
        await Task.yield()
    }
    #expect(buffer.count == 1)
    #expect(buffer.queuedByteCount == first.count)
    #expect(buffer.blockedProducerCount == 1)
    let firstUpdate = buffer.take()
    #expect(firstUpdate?.json == first)
    if let firstUpdate { buffer.complete(firstUpdate) }
    #expect(await producer.value)
    #expect(buffer.count == 1)
    #expect(buffer.queuedByteCount == second.count)
    #expect(buffer.blockedProducerCount == 0)
    let secondUpdate = buffer.take()
    #expect(secondUpdate?.json == second)
    if let secondUpdate { buffer.complete(secondUpdate) }
    #expect(buffer.queuedByteCount == 0)
}

@Test func updateBufferCloseRejectsBlockedAppendAndDrainsAcceptedUpdates() async {
    let buffer = TDLibUpdateBuffer(capacity: 1)
    let accepted = Data("accepted".utf8)
    #expect(buffer.append(accepted))
    let appendResult = LockedTestValue<Bool?>(nil)
    let appendFinished = LockedTestValue(false)
    // append() intentionally blocks under backpressure. Keep that blocking call off
    // Swift's cooperative executor so this test remains reliable on older CI toolchains.
    DispatchQueue(label: "NeTelegramTests.blocked-update-append").async {
        appendResult.set(buffer.append(Data("after-close".utf8)))
        appendFinished.set(true)
    }

    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(1))
    while buffer.blockedProducerCount == 0 && clock.now < deadline {
        await Task.yield()
    }
    #expect(buffer.blockedProducerCount == 1)

    buffer.close()
    let producerFinished = await waitForTrue(appendFinished, timeout: .seconds(2))
    #expect(producerFinished)
    #expect(appendResult.get() == false)
    let acceptedUpdate = buffer.take()
    #expect(acceptedUpdate?.json == accepted)
    if let acceptedUpdate { buffer.complete(acceptedUpdate) }
    #expect(buffer.take()?.json == nil)
    #expect(buffer.count == 0)
}

@Test func updateBufferShutdownPreservesOneInFlightReceiveAndRejectsLaterInput() async {
    let buffer = TDLibUpdateBuffer(capacity: 1)
    let accepted = Data("accepted".utf8)
    let inFlight = Data("TDLib-final-receive".utf8)
    #expect(buffer.append(accepted))
    let appendResult = LockedTestValue<Bool?>(nil)
    let appendFinished = LockedTestValue(false)
    DispatchQueue(label: "NeTelegramTests.shutdown-in-flight-receive").async {
        appendResult.set(buffer.append(inFlight))
        appendFinished.set(true)
    }

    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(1))
    while buffer.blockedProducerCount == 0 && clock.now < deadline {
        await Task.yield()
    }
    #expect(buffer.blockedProducerCount == 1)

    buffer.close(allowInFlightReceive: true)
    let producerFinished = await waitForTrue(appendFinished, timeout: .seconds(2))
    #expect(producerFinished)
    #expect(appendResult.get() == true)
    #expect(buffer.count == 2)

    let first = buffer.take()
    #expect(first?.json == accepted)
    if let first { buffer.complete(first) }
    let final = buffer.take()
    #expect(final?.json == inFlight)
    if let final { buffer.complete(final) }
    #expect(!buffer.append(Data("after-stop".utf8)))
    #expect(buffer.take() == nil)
    #expect(buffer.count == 0)
}

@Test func updateBufferBackpressuresByBytesAndAdmitsOneOversizedUpdateAlone() async {
    let buffer = TDLibUpdateBuffer(capacity: 8, byteCapacity: 5)
    let first = Data("1234".utf8)
    let second = Data("56".utf8)
    #expect(buffer.append(first))
    let producer = Task.detached { buffer.append(second) }

    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(1))
    while buffer.blockedProducerCount == 0 && clock.now < deadline {
        await Task.yield()
    }
    #expect(buffer.queuedByteCount == 4)
    #expect(buffer.blockedProducerCount == 1)
    let firstUpdate = buffer.take()
    #expect(firstUpdate?.json == first)
    if let firstUpdate { buffer.complete(firstUpdate) }
    #expect(await producer.value)
    #expect(buffer.queuedByteCount == 2)
    let secondUpdate = buffer.take()
    #expect(secondUpdate?.json == second)
    if let secondUpdate { buffer.complete(secondUpdate) }
    #expect(buffer.queuedByteCount == 0)

    let oversized = Data(repeating: 0x7f, count: 9)
    #expect(buffer.append(oversized))
    #expect(buffer.queuedByteCount == oversized.count)
    let following = Task.detached { buffer.append(Data("x".utf8)) }
    let oversizedDeadline = clock.now.advanced(by: .seconds(1))
    while buffer.blockedProducerCount == 0 && clock.now < oversizedDeadline {
        await Task.yield()
    }
    #expect(buffer.blockedProducerCount == 1)
    let oversizedUpdate = buffer.take()
    #expect(oversizedUpdate?.json == oversized)
    if let oversizedUpdate { buffer.complete(oversizedUpdate) }
    #expect(await following.value)
    let followingUpdate = buffer.take()
    #expect(followingUpdate?.json == Data("x".utf8))
    if let followingUpdate { buffer.complete(followingUpdate) }
}

@Test func updateBufferRoundRobinsClientsAndPreservesEachClientFIFO() {
    let buffer = TDLibUpdateBuffer(capacity: 8)
    func update(_ client: Int, _ sequence: Int) -> Data {
        Data("{\"@client_id\":\(client),\"sequence\":\(sequence)}".utf8)
    }

    let a1 = update(1, 1)
    let a2 = update(1, 2)
    let a3 = update(1, 3)
    let b1 = update(2, 1)
    let b2 = update(2, 2)
    #expect(buffer.append(a1))
    #expect(buffer.append(a2))
    #expect(buffer.append(a3))
    #expect(buffer.append(b1))
    #expect(buffer.append(b2))

    #expect(buffer.queuedClientCount(for: ClientID(1)) == 3)
    #expect(buffer.queuedClientCount(for: ClientID(2)) == 2)
    for expected in [a1, b1, a2, b2, a3] {
        let update = buffer.take()
        #expect(update?.json == expected)
        if let update { buffer.complete(update) }
    }
    #expect(buffer.queuedClientCount(for: ClientID(1)) == 0)
    #expect(buffer.queuedClientCount(for: ClientID(2)) == 0)
}

@Test func updateBufferGivesSparseClientsProgressBesideOneHotClient() {
    let buffer = TDLibUpdateBuffer(capacity: 64)
    func update(_ client: Int, _ sequence: Int) -> Data {
        Data("{\"@client_id\":\(client),\"sequence\":\(sequence)}".utf8)
    }
    for sequence in 1...40 { #expect(buffer.append(update(1, sequence))) }
    for client in 2...20 { #expect(buffer.append(update(client, 1))) }

    // The hot lane gets one turn, then each sparse lane gets one before the
    // hot lane can consume its next item.
    let hot = buffer.take()
    #expect(hot?.clientID == ClientID(1))
    if let hot { buffer.complete(hot) }
    for client in 2...20 {
        let sparse = buffer.take()
        #expect(sparse?.clientID == ClientID(Int32(client)))
        if let sparse { buffer.complete(sparse) }
    }
    #expect(buffer.queuedClientCount(for: ClientID(1)) == 39)
}

@Test func asynchronousDeliveryKeepsClientOrderWithoutCrossAccountHeadOfLineBlocking() async {
    let buffer = TDLibUpdateBuffer(capacity: 8)
    let scheduler = TDLibUpdateDeliveryScheduler()
    let blockedFirstAccountEvent = AsyncTestGate()
    let started = LockedTestValue<[String]>([])
    let completed = LockedTestValue<[String]>([])
    func update(_ client: Int32, _ sequence: Int) -> Data {
        Data("{\"@client_id\":\(client),\"sequence\":\(sequence)}".utf8)
    }

    let a1 = update(1, 1)
    let a2 = update(1, 2)
    let b1 = update(2, 1)
    for bytes in [a1, a2, b1] { #expect(buffer.append(bytes)) }

    for _ in 0..<3 {
        guard let item = buffer.take(), let client = item.clientID else {
            Issue.record("Expected routed update in the buffer")
            break
        }
        let route = RuntimeRoute(account: AccountUUID(), generation: RuntimeGeneration(1), client: client)
        let event = TDLibPipelineEvent.routed(RoutedTDLibUpdate(route: route, json: item.json))
        scheduler.enqueue(event, update: item, buffer: buffer) { event in
            guard case .routed(let routed) = event,
                  let object = try? JSONSerialization.jsonObject(with: routed.json) as? [String: Any],
                  let sequence = object["sequence"] as? Int else { return }
            let label = "\(routed.route.client.value):\(sequence)"
            started.mutate { $0.append(label) }
            if label == "1:1" { await blockedFirstAccountEvent.wait() }
            completed.mutate { $0.append(label) }
        }
    }

    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(2))
    while (!started.get().contains("1:1") || !completed.get().contains("2:1")) && clock.now < deadline {
        await Task.yield()
    }
    #expect(started.get().contains("1:1"))
    #expect(completed.get().contains("2:1"))
    #expect(!started.get().contains("1:2"))
    #expect(buffer.count == 2, "The blocked callback and its queued same-account event remain charged to the shared bound")

    await blockedFirstAccountEvent.open()
    let drainDeadline = clock.now.advanced(by: .seconds(2))
    while buffer.count != 0 && clock.now < drainDeadline { await Task.yield() }
    #expect(buffer.count == 0)
    let finished = completed.get()
    #expect((finished.firstIndex(of: "1:1") ?? .max) < (finished.firstIndex(of: "1:2") ?? .min))
}

@Test func tdlibGatewayFailsClosedWhenPinnedLibraryIsUnavailable() {
    let missingLibrary = FileManager.default.temporaryDirectory
        .appendingPathComponent("netelegram-missing-\(UUID().uuidString).dylib")
    #expect(throws: TDLibGatewayError.self) {
        try TDLibGateway(libraryURL: missingLibrary)
    }
}

@Test func updatesNeverFallBackToTheSelectedAccount() async throws {
    let coordinator = RuntimeCoordinator()
    let account = AccountUUID()
    let route = RuntimeRoute(account: account, generation: RuntimeGeneration(1), client: ClientID(37))
    try await coordinator.registerBeforeFirstRequest(route)

    let routed = try await coordinator.routeUpdate(Data(#"{"@type":"updateAuthorizationState","@client_id":37}"#.utf8))
    #expect(routed.route == route)
    do {
        _ = try await coordinator.routeUpdate(Data(#"{"@type":"updateAuthorizationState","@client_id":99}"#.utf8))
        Issue.record("Unknown client ID must not be routed to a selected account")
    } catch let error as TDLibRoutingError {
        #expect(error == .unregisteredClientID(ClientID(99)))
    } catch {
        Issue.record("Unexpected routing error: \(error)")
    }
    do {
        _ = try await coordinator.routeUpdate(Data(#"{"@type":"updateAuthorizationState"}"#.utf8))
        Issue.record("Missing client ID must not be routed to a selected account")
    } catch let error as TDLibRoutingError {
        #expect(error == .missingClientID)
    } catch {
        Issue.record("Unexpected routing error: \(error)")
    }
}

@Test func accountCataloguePersistsStableNamespaceAndVerifiedIdentity() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let account = AccountUUID()
    let catalogue = try AccountCatalogue(rootURL: root)
    _ = try await catalogue.addProfile(id: account)
    try await catalogue.associateVerifiedIdentity(123456789, displayName: "Test User", with: account)

    let reopened = try AccountCatalogue(rootURL: root)
    let profiles = await reopened.allProfiles()
    #expect(profiles.count == 1)
    #expect(profiles[0].id == account)
    #expect(profiles[0].telegramUserID == 123456789)
    #expect(profiles[0].displayName == "Test User")
    let mode = try FileManager.default.attributesOfItem(atPath: root.appendingPathComponent("accounts.json").path)[.posixPermissions] as? NSNumber
    #expect(mode?.intValue == 0o600)
}

@Test func accountCatalogueRefusesToReassignAnExistingTelegramIdentity() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let account = AccountUUID()
    let catalogue = try AccountCatalogue(rootURL: root)
    _ = try await catalogue.addProfile(id: account)
    try await catalogue.associateVerifiedIdentity(123456789, displayName: "Original User", with: account)

    await #expect(throws: AccountCatalogueError.identityMismatch) {
        try await catalogue.associateVerifiedIdentity(987654321, displayName: "Other User", with: account)
    }
    let unchanged = await catalogue.allProfiles()
    #expect(unchanged.first?.telegramUserID == 123456789)
    #expect(unchanged.first?.displayName == "Original User")

    try await catalogue.associateVerifiedIdentity(123456789, displayName: "Updated Name", with: account)
    let sameIdentityUpdate = await catalogue.allProfiles()
    #expect(sameIdentityUpdate.first?.telegramUserID == 123456789)
    #expect(sameIdentityUpdate.first?.displayName == "Updated Name")
}

@Test func accountCatalogueRemovesOnlyTheExpectedLoggedOutIdentity() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let first = AccountUUID()
    let second = AccountUUID()
    let catalogue = try AccountCatalogue(rootURL: root)
    _ = try await catalogue.addProfile(id: first)
    _ = try await catalogue.addProfile(id: second)
    try await catalogue.associateVerifiedIdentity(101, with: first)
    try await catalogue.associateVerifiedIdentity(202, with: second)

    await #expect(throws: AccountCatalogueError.identityMismatch) {
        try await catalogue.removeProfile(first, expectedTelegramUserID: 202)
    }
    #expect(await catalogue.allProfiles().count == 2)

    try await catalogue.removeProfile(first, expectedTelegramUserID: 101)
    let reopened = try AccountCatalogue(rootURL: root)
    let remaining = await reopened.allProfiles()
    #expect(remaining.map(\.id) == [second])
    #expect(remaining.first?.telegramUserID == 202)
}

@Test func accountCatalogueDoesNotExposeUnpersistedTelegramIdentity() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let account = AccountUUID()
    let catalogue = try AccountCatalogue(rootURL: root)
    _ = try await catalogue.addProfile(id: account)

    let catalogueFile = root.appendingPathComponent("accounts.json")
    try FileManager.default.removeItem(at: catalogueFile)
    try FileManager.default.createDirectory(at: catalogueFile, withIntermediateDirectories: false)

    await #expect(throws: AccountCatalogueError.self) {
        try await catalogue.associateVerifiedIdentity(987654321, displayName: "Test User", with: account)
    }
    let profiles = await catalogue.allProfiles()
    #expect(profiles.count == 1)
    #expect(profiles[0].telegramUserID == nil)
    #expect(profiles[0].displayName == nil)
}

@Test func accountStorageDirectoriesDoNotShareAccountPaths() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let first = try AccountStoragePaths(rootURL: root, account: AccountUUID())
    let second = try AccountStoragePaths(rootURL: root, account: AccountUUID())
    #expect(first.database != second.database)
    #expect(first.files != second.files)
    #expect(first.appState != second.appState)
}

@Test func sendIntentIsBoundToAccountIdentityGenerationAndConversation() {
    let accountA = AccountUUID()
    let accountB = AccountUUID()
    let barrier = PrivacyDispatchBarrier()
    let attachmentURL = FileManager.default.temporaryDirectory.appendingPathComponent("capture.png")
    let intent = SendIntent(
        account: accountA,
        expectedTelegramUserID: 101,
        runtimeGeneration: RuntimeGeneration(4),
        conversation: ConversationKey(account: accountA, chatID: 9001, topic: .forum(topicID: 7)),
        replyToMessageID: 42,
        text: "hello",
        attachments: [SendAttachment(localFileURL: attachmentURL)],
        privacyEpoch: barrier.currentEpoch()
    )
    #expect(intent.attachments == [SendAttachment(localFileURL: attachmentURL)])
    #expect(intent.replyToMessageID == 42)
    var sends = 0
    #expect(barrier.dispatch(intent, currentAccount: accountA, currentTelegramUserID: 101, currentGeneration: RuntimeGeneration(4)) { sends += 1 })
    #expect(!barrier.dispatch(intent, currentAccount: accountB, currentTelegramUserID: 101, currentGeneration: RuntimeGeneration(4)) { sends += 1 })
    #expect(!barrier.dispatch(intent, currentAccount: accountA, currentTelegramUserID: 202, currentGeneration: RuntimeGeneration(4)) { sends += 1 })
    #expect(!barrier.dispatch(intent, currentAccount: accountA, currentTelegramUserID: 101, currentGeneration: RuntimeGeneration(5)) { sends += 1 })
    #expect(sends == 1)
}

@Test func runtimeCommandGateOrdersAcceptedCommandsBeforeCloseAndRejectsLateDispatch() {
    let gate = RuntimeCommandGate()
    let commandEntered = DispatchSemaphore(value: 0)
    let finishCommand = DispatchSemaphore(value: 0)
    let closeAttempted = DispatchSemaphore(value: 0)
    let closeFinished = DispatchSemaphore(value: 0)
    let events = LockedTestValue<[String]>([])
    let commandQueue = DispatchQueue(label: "NeTelegram.Tests.RuntimeCommandGate.command")
    let closeQueue = DispatchQueue(label: "NeTelegram.Tests.RuntimeCommandGate.close")

    commandQueue.async {
        _ = gate.dispatch {
            commandEntered.signal()
            finishCommand.wait()
            events.set(events.get() + ["command"])
        }
    }
    #expect(commandEntered.wait(timeout: .now() + 2) == .success)

    closeQueue.async {
        closeAttempted.signal()
        _ = gate.beginClosing {
            events.set(events.get() + ["close"])
        }
        closeFinished.signal()
    }
    #expect(closeAttempted.wait(timeout: .now() + 2) == .success)
    #expect(closeFinished.wait(timeout: .now()) == .timedOut)
    finishCommand.signal()
    #expect(closeFinished.wait(timeout: .now() + 2) == .success)
    #expect(events.get() == ["command", "close"])

    var lateCommandRan = false
    #expect(!gate.dispatch { lateCommandRan = true })
    #expect(!lateCommandRan)
}

@Test func runtimeCommandGateReopensOnlyWhenCloseRequestWasRejected() throws {
    let gate = RuntimeCommandGate()
    var closeFailed = false
    do {
        _ = try gate.beginClosing { throw CocoaError(.fileWriteUnknown) }
    } catch {
        closeFailed = true
    }
    #expect(closeFailed)
    #expect(!gate.isClosing)

    var commandRan = false
    #expect(gate.dispatch { commandRan = true })
    #expect(commandRan)
    #expect(gate.beginClosing {})
    #expect(gate.isClosing)
    #expect(!gate.dispatch { commandRan = false })
}

@Test func lockingInvalidatesQueuedSendIntentsAcrossUnlock() throws {
    let account = AccountUUID()
    let barrier = PrivacyDispatchBarrier()
    let queued = SendIntent(
        account: account,
        expectedTelegramUserID: 101,
        runtimeGeneration: RuntimeGeneration(1),
        conversation: ConversationKey(account: account, chatID: 55),
        text: "draft",
        privacyEpoch: barrier.currentEpoch()
    )
    _ = barrier.setLocked(true)
    _ = barrier.setLocked(false)
    var sent = false
    #expect(!barrier.dispatch(queued, currentAccount: account, currentTelegramUserID: 101, currentGeneration: RuntimeGeneration(1)) { sent = true })
    #expect(!sent)
    #expect(SendIntent.maximumPaidStars == 0)
}

@Test func privacyBarrierBindsAccountLogoutAndRejectsLockedOrStaleCommands() throws {
    let account = AccountUUID()
    let barrier = PrivacyDispatchBarrier()
    let generation = RuntimeGeneration(3)
    let epoch = barrier.currentEpoch()
    var dispatched = 0

    #expect(barrier.dispatchBoundUserCommand(
        account: account,
        expectedTelegramUserID: 101,
        runtimeGeneration: generation,
        privacyEpoch: epoch,
        currentAccount: account,
        currentTelegramUserID: 101,
        currentGeneration: generation
    ) { dispatched += 1 })
    #expect(!barrier.dispatchBoundUserCommand(
        account: account,
        expectedTelegramUserID: 101,
        runtimeGeneration: generation,
        privacyEpoch: epoch,
        currentAccount: account,
        currentTelegramUserID: 101,
        currentGeneration: RuntimeGeneration(4)
    ) { dispatched += 1 })

    _ = barrier.setLocked(true)
    #expect(!barrier.dispatchBoundUserCommand(
        account: account,
        expectedTelegramUserID: 101,
        runtimeGeneration: generation,
        privacyEpoch: barrier.currentEpoch(),
        currentAccount: account,
        currentTelegramUserID: 101,
        currentGeneration: generation
    ) { dispatched += 1 })
    #expect(dispatched == 1)
}

@Test func privacyLockWaitsForAnAtomicDispatchAndRejectsTheNextIntent() async {
    let account = AccountUUID()
    let barrier = PrivacyDispatchBarrier()
    let intent = SendIntent(
        account: account,
        expectedTelegramUserID: 101,
        runtimeGeneration: RuntimeGeneration(1),
        conversation: ConversationKey(account: account, chatID: 55),
        text: "in flight",
        privacyEpoch: barrier.currentEpoch()
    )
    let sendEntered = LockedTestValue(false)
    let finishSend = DispatchSemaphore(value: 0)
    let dispatchFinished = LockedTestValue(false)
    let lockAttemptStarted = LockedTestValue(false)
    let lockFinished = LockedTestValue(false)
    let dispatchAccepted = LockedTestValue(false)
    let sendCount = LockedTestValue(0)
    let dispatchQueue = DispatchQueue(label: "NeTelegram.Tests.PrivacyDispatch")
    let lockQueue = DispatchQueue(label: "NeTelegram.Tests.PrivacyLock")

    dispatchQueue.async {
        let accepted = barrier.dispatch(
            intent,
            currentAccount: account,
            currentTelegramUserID: 101,
            currentGeneration: RuntimeGeneration(1)
        ) {
            sendEntered.set(true)
            finishSend.wait()
            sendCount.set(sendCount.get() + 1)
        }
        dispatchAccepted.set(accepted)
        dispatchFinished.set(true)
    }
    let sendDidEnter = await waitForTrue(sendEntered, timeout: .seconds(2))

    lockQueue.async {
        lockAttemptStarted.set(true)
        barrier.setLocked(true)
        lockFinished.set(true)
    }
    let lockAttemptDidStart = await waitForTrue(lockAttemptStarted, timeout: .seconds(2))
    let lockFinishedBeforeSend = await waitForTrue(lockFinished, timeout: .milliseconds(20))
    let lockWasSerializedBehindSend = !lockFinishedBeforeSend
    // Always release the simulated send, even when an earlier synchronization point failed.
    finishSend.signal()
    let dispatchDidFinish = await waitForTrue(dispatchFinished, timeout: .seconds(2))
    let lockDidFinish: Bool
    if lockFinishedBeforeSend {
        lockDidFinish = true
    } else {
        lockDidFinish = await waitForTrue(lockFinished, timeout: .seconds(2))
    }

    #expect(sendDidEnter)
    #expect(lockAttemptDidStart)
    #expect(dispatchDidFinish)
    #expect(lockDidFinish)
    #expect(lockWasSerializedBehindSend)
    #expect(dispatchAccepted.get())
    #expect(sendCount.get() == 1)
    #expect(barrier.currentEpoch() == intent.privacyEpoch + 1)
    #expect(!barrier.dispatch(intent, currentAccount: account, currentTelegramUserID: 101, currentGeneration: RuntimeGeneration(1)) {
        sendCount.set(sendCount.get() + 1)
    })
    #expect(sendCount.get() == 1)
}

@Test func notificationPublicationIsSerializedWithPrivacyLock() async {
    let barrier = PrivacyDispatchBarrier()
    let publicationEntered = LockedTestValue(false)
    let finishPublication = DispatchSemaphore(value: 0)
    let lockAttemptStarted = LockedTestValue(false)
    let lockFinished = LockedTestValue(false)
    let publicationQueue = DispatchQueue(label: "NeTelegram.Tests.NotificationPrivacy")
    let lockQueue = DispatchQueue(label: "NeTelegram.Tests.NotificationPrivacyLock")

    publicationQueue.async {
        barrier.withState { isLocked, _ in
            publicationEntered.set(true)
            if !isLocked { finishPublication.wait() }
        }
    }
    let publicationDidEnter = await waitForTrue(publicationEntered, timeout: .seconds(2))
    lockQueue.async {
        lockAttemptStarted.set(true)
        barrier.setLocked(true)
        lockFinished.set(true)
    }
    let lockAttemptDidStart = await waitForTrue(lockAttemptStarted, timeout: .seconds(2))
    let lockFinishedBeforePublication = await waitForTrue(lockFinished, timeout: .milliseconds(20))

    finishPublication.signal()
    let lockDidFinish = await waitForTrue(lockFinished, timeout: .seconds(2))
    let finalState = barrier.withState { ($0, $1) }

    #expect(publicationDidEnter)
    #expect(lockAttemptDidStart)
    #expect(!lockFinishedBeforePublication)
    #expect(lockDidFinish)
    #expect(finalState.0)
    #expect(finalState.1 == 1)
}

@Test func conversationAndMessageKeysIncludeAccountAndTopic() {
    let accountA = AccountUUID()
    let accountB = AccountUUID()
    let a = ConversationKey(account: accountA, chatID: 77, topic: .thread(messageThreadID: 12))
    let sameChatOtherAccount = ConversationKey(account: accountB, chatID: 77, topic: .thread(messageThreadID: 12))
    let anotherTopic = ConversationKey(account: accountA, chatID: 77, topic: .thread(messageThreadID: 13))
    #expect(a != sameChatOtherAccount)
    #expect(a != anotherTopic)
    #expect(MessageKey(conversation: a, messageID: 10) != MessageKey(conversation: anotherTopic, messageID: 10))
}

@Test func accountSearchResultsAreDeduplicatedAndBoundedPerAccount() {
    let first = AccountUUID()
    let second = AccountUUID()
    let mainConversation = ConversationKey(account: first, chatID: 77)
    let topicConversation = ConversationKey(account: first, chatID: 77, topic: .forum(topicID: 4))
    var results = AccountSearchResults(maximumPerAccount: 2)

    let firstAccepted = results.append(AccountSearchResult(account: first, conversation: mainConversation, title: "Чат", excerpt: "совпадение"))
    let duplicateAccepted = results.append(AccountSearchResult(account: first, conversation: mainConversation, title: "Чат", excerpt: "дубликат"))
    let topicAccepted = results.append(AccountSearchResult(account: first, conversation: topicConversation, messageID: 9, title: "Форум", excerpt: "сообщение"))
    let overLimitAccepted = results.append(AccountSearchResult(account: first, conversation: topicConversation, messageID: 10, title: "Форум", excerpt: "за пределом лимита"))
    let otherAccountAccepted = results.append(AccountSearchResult(account: second, conversation: mainConversationFor(second), title: "Чат", excerpt: "другой аккаунт"))
    let misroutedAccountAccepted = results.append(AccountSearchResult(account: second, conversation: mainConversation, title: "Чат", excerpt: "неверный профиль"))
    #expect(firstAccepted)
    #expect(!duplicateAccepted)
    #expect(topicAccepted)
    #expect(!overLimitAccepted)
    #expect(otherAccountAccepted)
    #expect(!misroutedAccountAccepted)
    #expect(results.values.count == 3)
    #expect(results.values.map(\.account) == [first, first, second])
}

@Test func messageActionsUseOnlyServerReportedPermissions() {
    let permissions = MessageActionPermissions(tdlibObject: [
        "can_be_edited": true,
        "can_be_deleted_only_for_self": false,
        "can_be_deleted_for_all_users": true,
    ])
    #expect(permissions.canEdit)
    #expect(permissions.deleteModes == [.forEveryone])
    #expect(permissions.deleteModes.first?.revoke == true)

    let unknown = MessageActionPermissions(tdlibObject: [:])
    #expect(!unknown.hasActions)
    #expect(unknown.deleteModes.isEmpty)
}

private func mainConversationFor(_ account: AccountUUID) -> ConversationKey {
    ConversationKey(account: account, chatID: 77)
}

@Test func encryptedDraftStoreRoundTripsCiphertextPerAccountAndTopic() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let account = AccountUUID()
    let key = Data(repeating: 0xA7, count: 32)
    let store = try EncryptedDraftStore(account: account, stateDirectory: root, key: key)
    let conversation = ConversationKey(account: account, chatID: -100123, topic: .forum(topicID: 9))
    try store.save([conversation: "private draft"])

    let encrypted = try Data(contentsOf: root.appendingPathComponent("drafts.aesgcm"))
    #expect(!String(decoding: encrypted, as: UTF8.self).contains("private draft"))
    #expect(try store.load() == [conversation: "private draft"])
    let mode = try FileManager.default.attributesOfItem(atPath: root.appendingPathComponent("drafts.aesgcm").path)[.posixPermissions] as? NSNumber
    #expect(mode?.intValue == 0o600)
}

@Test func encryptedDraftStoreFailsClosedOnWrongKeyAndCrossAccountData() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let accountA = AccountUUID()
    let accountB = AccountUUID()
    let storeA = try EncryptedDraftStore(account: accountA, stateDirectory: root, key: Data(repeating: 1, count: 32))
    let conversationA = ConversationKey(account: accountA, chatID: 1)
    try storeA.save([conversationA: "do not overwrite"])

    let wrongKeyStore = try EncryptedDraftStore(account: accountA, stateDirectory: root, key: Data(repeating: 2, count: 32))
    #expect(throws: EncryptedDraftStoreError.corruptOrUnauthenticatedData) { try wrongKeyStore.load() }
    let storeB = try EncryptedDraftStore(account: accountB, stateDirectory: root.appendingPathComponent("other", isDirectory: true), key: Data(repeating: 3, count: 32))
    #expect(throws: EncryptedDraftStoreError.accountMismatch) { try storeB.save([conversationA: "cross-account"]) }
}

@Test func encryptedDraftStoreReconcilesAcceptedSendAfterPresentationCachePurge() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let account = AccountUUID()
    let store = try EncryptedDraftStore(account: account, stateDirectory: root, key: Data(repeating: 0x2A, count: 32))
    let conversation = ConversationKey(account: account, chatID: 42)
    try store.save([conversation: "accepted text"])

    // The lock clears UI memory, but TDLib's later success still removes the
    // matching persisted draft so it cannot reappear on unlock.
    #expect(try store.removeDraftIfMatching(conversation, text: "accepted text"))
    #expect(try store.load().isEmpty)
}

@Test func encryptedDraftStoreKeepsNewerDraftWhenOldSendCompletes() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let account = AccountUUID()
    let store = try EncryptedDraftStore(account: account, stateDirectory: root, key: Data(repeating: 0x2B, count: 32))
    let conversation = ConversationKey(account: account, chatID: 43)
    try store.save([conversation: "newer unsent text"])

    #expect(!(try store.removeDraftIfMatching(conversation, text: "older sent text")))
    #expect(try store.load() == [conversation: "newer unsent text"])
}

@Test func photoPipelineDownsamplesToViewportBoundAndCapsConcurrency() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let url = root.appendingPathComponent("large-fixture.png")
    let space = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(data: nil, width: 512, height: 384, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    context?.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1))
    context?.fill(CGRect(x: 0, y: 0, width: 512, height: 384))
    let sourceData = NSMutableData()
    let sourceImage = try #require(context?.makeImage())
    let destination = try #require(CGImageDestinationCreateWithData(sourceData, "public.png" as CFString, 1, nil))
    CGImageDestinationAddImage(destination, sourceImage, nil)
    #expect(CGImageDestinationFinalize(destination))
    try (sourceData as Data).write(to: url)

    let previewData = try #require(PhotoPipeline.downsample(fileURL: url, maxPixelSize: 96))
    let previewSource = try #require(CGImageSourceCreateWithData(previewData as CFData, nil))
    let properties = try #require(CGImageSourceCopyPropertiesAtIndex(previewSource, 0, nil) as? [CFString: Any])
    let width = try #require((properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue)
    let height = try #require((properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue)
    #expect(max(width, height) <= 96)

    let staged = try OutgoingPhotoStager.stage(url, accountFilesDirectory: root.appendingPathComponent("account-files", isDirectory: true))
    defer { try? FileManager.default.removeItem(at: staged.deletingLastPathComponent()) }
    #expect(FileManager.default.fileExists(atPath: staged.path))
    let mode = try FileManager.default.attributesOfItem(atPath: staged.path)[.posixPermissions] as? NSNumber
    #expect(mode?.intValue == 0o600)

    let pipeline = PhotoPipeline(maxConcurrentDecodes: 2, cacheCostLimit: 1024 * 1024)
    #expect(pipeline.maxConcurrentDecodes == 2)
}

@Test func outgoingPhotoManifestSurvivesRestartAndReleasesOnlyOwnedFiles() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let state = root.appendingPathComponent("state", isDirectory: true)
    let files = root.appendingPathComponent("files", isDirectory: true)
    let outgoing = files.appendingPathComponent("Outgoing", isDirectory: true)
    try FileManager.default.createDirectory(at: outgoing, withIntermediateDirectories: true)
    let staged = outgoing.appendingPathComponent("pending.jpg")
    try Data([0x01, 0x02, 0x03]).write(to: staged)

    let firstProcess = OutgoingPhotoManifestStore(stateDirectory: state, accountFilesDirectory: files)
    try firstProcess.register(staged)
    let manifestURL = state.appendingPathComponent("outgoing-photos.json")
    let mode = try FileManager.default.attributesOfItem(atPath: manifestURL.path)[.posixPermissions] as? NSNumber
    #expect(mode?.intValue == 0o600)

    // A fresh store represents a relaunch. Recovery tracks ownership without
    // resending, so TDLib can finish an upload that it persisted in its DB.
    let relaunched = OutgoingPhotoManifestStore(stateDirectory: state, accountFilesDirectory: files)
    #expect(try relaunched.load() == [staged.standardizedFileURL])
    try relaunched.remove(staged)
    #expect(try relaunched.load().isEmpty)
    #expect(FileManager.default.fileExists(atPath: staged.path))

    let outside = root.appendingPathComponent("unowned.jpg")
    try Data([0x04]).write(to: outside)
    #expect(throws: OutgoingPhotoManifestError.fileOutsideOutgoingDirectory) {
        try relaunched.register(outside)
    }
}

@Test func outgoingPhotoManifestRefusesToReplaceCorruptState() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let state = root.appendingPathComponent("state", isDirectory: true)
    let files = root.appendingPathComponent("files", isDirectory: true)
    let outgoing = files.appendingPathComponent("Outgoing", isDirectory: true)
    try FileManager.default.createDirectory(at: outgoing, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: state, withIntermediateDirectories: true)
    let manifestURL = state.appendingPathComponent("outgoing-photos.json")
    let corrupt = Data("not-json".utf8)
    try corrupt.write(to: manifestURL)
    let staged = outgoing.appendingPathComponent("pending.jpg")
    try Data([0x01]).write(to: staged)

    let store = OutgoingPhotoManifestStore(stateDirectory: state, accountFilesDirectory: files)
    #expect(throws: OutgoingPhotoManifestError.invalidManifest) { try store.register(staged) }
    #expect(try Data(contentsOf: manifestURL) == corrupt)
    #expect(FileManager.default.fileExists(atPath: staged.path))
}

@Test func sendLifecycleMatchesTerminalResultToPendingIntent() {
    let account = AccountUUID()
    let key = SendMessageKey(account: account, generation: RuntimeGeneration(1), chatID: 50, temporaryMessageID: -10)
    var lifecycle = SendMessageLifecycle<String>()

    #expect(lifecycle.register("caption and photo", for: key) == nil)
    #expect(lifecycle.resolve(.failed(canRetry: true), for: key, bufferIfUnregistered: true) == "caption and photo")
    #expect(lifecycle.resolve(.succeeded, for: key, bufferIfUnregistered: true) == nil)
}

@Test func sendLifecycleCorrelatesOutcomeArrivingBeforeSendResponse() {
    let key = SendMessageKey(account: AccountUUID(), generation: RuntimeGeneration(1), chatID: 77, temporaryMessageID: -11)
    var lifecycle = SendMessageLifecycle<String>(earlyOutcomeLimit: 2)

    #expect(lifecycle.resolve(.succeeded, for: key, bufferIfUnregistered: true) == nil)
    #expect(lifecycle.register("draft", for: key) == .succeeded)
    #expect(lifecycle.register("next send", for: key) == nil)
    #expect(lifecycle.resolve(.deleted, for: key, bufferIfUnregistered: false) == "next send")
}

@Test func sendLifecycleCanMoveRetryToTDLibReturnedTemporaryID() {
    let account = AccountUUID()
    let oldKey = SendMessageKey(account: account, generation: RuntimeGeneration(1), chatID: 77, temporaryMessageID: -11)
    let newKey = SendMessageKey(account: account, generation: RuntimeGeneration(1), chatID: 77, temporaryMessageID: -12)
    var lifecycle = SendMessageLifecycle<String>()

    #expect(lifecycle.register("original text", for: oldKey) == nil)
    let pending = lifecycle.take(for: oldKey)
    #expect(pending == "original text")
    #expect(lifecycle.register(pending!, for: newKey) == nil)
    #expect(lifecycle.resolve(.succeeded, for: newKey, bufferIfUnregistered: false) == "original text")
}

@Test func sendLifecycleKeepsAccountsAndEarlyOutcomesIsolatedAndBounded() {
    let accountA = AccountUUID()
    let accountB = AccountUUID()
    let a = SendMessageKey(account: accountA, generation: RuntimeGeneration(1), chatID: 7, temporaryMessageID: -1)
    let b = SendMessageKey(account: accountB, generation: RuntimeGeneration(1), chatID: 7, temporaryMessageID: -1)
    var lifecycle = SendMessageLifecycle<String>(earlyOutcomeLimit: 1)

    #expect(lifecycle.resolve(.failed(canRetry: false), for: a, bufferIfUnregistered: true) == nil)
    #expect(lifecycle.register("account B", for: b) == nil)
    #expect(lifecycle.register("account A", for: a) == .failed(canRetry: false))
    lifecycle.removeAll(for: accountB)
    #expect(lifecycle.resolve(.deleted, for: b, bufferIfUnregistered: false) == nil)
}

@Test func sendDeletionIsTerminalOnlyWhenPermanentAndNotFromCache() {
    #expect(SendMessageDeletionClassification.classify(isPermanent: true, fromCache: false) == .permanent)
    #expect(SendMessageDeletionClassification.classify(isPermanent: true, fromCache: true) == .cacheEviction)
    #expect(SendMessageDeletionClassification.classify(isPermanent: false, fromCache: false) == .nonPermanent)
    #expect(SendMessageDeletionClassification.classify(isPermanent: nil, fromCache: false) == .nonPermanent)
    #expect(SendMessageDeletionClassification.classify(isPermanent: true, fromCache: nil) == .unknown)
}

@Test func stagedPhotoDeletionWaitsForKnownInactiveUpload() {
    #expect(StagedPhotoDeletionPolicy.mayReleaseSource(isTerminalDelete: false, uploadIsActive: false) == false)
    #expect(StagedPhotoDeletionPolicy.mayReleaseSource(isTerminalDelete: true, uploadIsActive: nil) == false)
    #expect(StagedPhotoDeletionPolicy.mayReleaseSource(isTerminalDelete: true, uploadIsActive: true) == false)
    #expect(StagedPhotoDeletionPolicy.mayReleaseSource(isTerminalDelete: true, uploadIsActive: false) == true)
}

@Test func photoDecodeAdmissionReservesBoundedCapacityForAnotherAccount() async {
    let accountA = AccountUUID()
    let accountB = AccountUUID()
    let firstDecodeStarted = LockedTestValue(false)
    let decodeCalls = LockedTestValue(0)
    let releaseFirstDecode = DispatchSemaphore(value: 0)
    let completionCount = LockedTestValue(0)
    let successfulCompletionCount = LockedTestValue(0)
    let allCompletionsFinished = LockedTestValue(false)
    let pipeline = PhotoPipeline(maxConcurrentDecodes: 1, maxQueuedDecodes: 2, decoder: { _, _ in
        let call = decodeCalls.get() + 1
        decodeCalls.set(call)
        if call == 1 {
            firstDecodeStarted.set(true)
            releaseFirstDecode.wait()
        }
        return Data([0x01])
    })
    defer { releaseFirstDecode.signal() }

    let completed: @Sendable (PhotoPreviewToken, Data?) -> Void = { _, data in
        completionCount.set(completionCount.get() + 1)
        if data != nil { successfulCompletionCount.set(successfulCompletionCount.get() + 1) }
        if completionCount.get() == 4 { allCompletionsFinished.set(true) }
    }
    let url = URL(fileURLWithPath: "/unused-by-injected-decoder")
    _ = pipeline.requestPreview(account: accountA, messageID: 1, fileID: 1, fileURL: url, maxPixelSize: 64, completion: completed)
    #expect(await waitForTrue(firstDecodeStarted, timeout: .seconds(2)))

    _ = pipeline.requestPreview(account: accountA, messageID: 2, fileID: 2, fileURL: url, maxPixelSize: 64, completion: completed)
    _ = pipeline.requestPreview(account: accountA, messageID: 3, fileID: 3, fileURL: url, maxPixelSize: 64, completion: completed)
    #expect(pipeline.outstandingDecodeCount(for: accountA) == 2)

    _ = pipeline.requestPreview(account: accountB, messageID: 4, fileID: 4, fileURL: url, maxPixelSize: 64, completion: completed)
    #expect(pipeline.outstandingDecodeCount(for: accountB) == 1)
    #expect(pipeline.outstandingDecodeCount(for: accountA) + pipeline.outstandingDecodeCount(for: accountB) == 3)

    releaseFirstDecode.signal()
    #expect(await waitForTrue(allCompletionsFinished, timeout: .seconds(3)))
    #expect(successfulCompletionCount.get() == 3)
    #expect(pipeline.outstandingDecodeCount(for: accountA) == 0)
    #expect(pipeline.outstandingDecodeCount(for: accountB) == 0)
}

@Test func mediaAlbumGroupingKeepsAdjacentAlbumsAndOrdinaryMessagesInOrder() {
    let runs = MediaAlbumGrouping.runs(albumIDs: [0, 44, 44, 0, 0, 91, 91, 91, 0])
    #expect(runs == [
        MediaAlbumRun(albumID: nil, messageIndices: 0..<1),
        MediaAlbumRun(albumID: 44, messageIndices: 1..<3),
        MediaAlbumRun(albumID: nil, messageIndices: 3..<5),
        MediaAlbumRun(albumID: 91, messageIndices: 5..<8),
        MediaAlbumRun(albumID: nil, messageIndices: 8..<9),
    ])
    #expect(MediaAlbumGrouping.runs(albumIDs: []).isEmpty)
}

@Test func photoSizeCatalogSeparatesPreviewFromExplicitOriginalVariant() {
    let sizes: [[String: Any]] = [
        ["type": "s", "width": 160, "height": 120, "photo": ["id": 1, "size": 4000]],
        ["type": "m", "width": 640, "height": 480, "photo": ["id": 2, "size": 24000]],
        ["type": "x", "width": 1280, "height": 960, "photo": ["id": 3, "size": 80000]],
        ["type": "y", "width": 2560, "height": 1920, "photo": ["id": 4, "size": 220000]],
        ["type": "bad", "width": 0, "height": 400, "photo": ["id": 5]],
    ]
    #expect(PhotoSizeCatalog.preview(from: sizes)?.fileID == 3)
    #expect(PhotoSizeCatalog.original(from: sizes)?.fileID == 4)
    #expect(PhotoSizeCatalog.preview(from: Array(sizes.prefix(2)))?.fileID == 2)
    #expect(PhotoSizeCatalog.original(from: []) == nil)
}

@Test func authorizationStepCountsEmailRegistrationAndQrAsNeedingUserInput() {
    #expect(AuthorizationStep(tdlibType: "authorizationStateWaitPhoneNumber") == .phoneNumber)
    #expect(AuthorizationStep(tdlibType: "authorizationStateWaitCode").awaitsUserInput)
    #expect(AuthorizationStep(tdlibType: "authorizationStateWaitPassword").awaitsUserInput)
    #expect(AuthorizationStep(tdlibType: "authorizationStateWaitEmailAddress").awaitsUserInput)
    #expect(AuthorizationStep(tdlibType: "authorizationStateWaitEmailCode").awaitsUserInput)
    #expect(AuthorizationStep(tdlibType: "authorizationStateWaitRegistration").awaitsUserInput)
    #expect(AuthorizationStep(tdlibType: "authorizationStateWaitOtherDeviceConfirmation").awaitsUserInput)
    #expect(!AuthorizationStep(tdlibType: "authorizationStateReady").awaitsUserInput)
    #expect(!AuthorizationStep(tdlibType: "unrecognizedAuthorizationState").awaitsUserInput)
    #expect(AuthorizationStep(tdlibType: "authorizationStateWaitPhoneNumber").uiAvailability == .interactive)
    #expect(AuthorizationStep(tdlibType: "authorizationStateWaitOtherDeviceConfirmation").uiAvailability == .interactive)
    #expect(AuthorizationStep(tdlibType: "authorizationStateWaitPremiumPurchase").uiAvailability == .purchaseNotAvailable)
    #expect(AuthorizationStep(tdlibType: "unrecognizedAuthorizationState").uiAvailability == .unsupported)
    // The pinned TDLib 1.8.68 schema does not define this legacy state; fail
    // closed instead of leaving a stale login form interactive if it appears.
    #expect(AuthorizationStep(tdlibType: "authorizationStateWaitEncryptionKey").uiAvailability == .unsupported)
    #expect(AccountReducer.reduce(
        current: .starting,
        authorizationState: "authorizationStateWaitEncryptionKey",
        telegramUserID: nil
    ) == .failed("Unsupported TDLib authorization state"))
    #expect(AuthorizationStep(tdlibType: "authorizationStateReady").uiAvailability == .nonInteractive)
}

@Test func forumTopicCatalogKeepsTypedIDsAndPlacesGeneralFirst() {
    let topics: [[String: Any]] = [
        ["info": ["forum_topic_id": 8, "name": "Работа"]],
        ["info": ["forum_topic_id": 41, "name": "Общие", "is_general": true]],
        ["info": ["forum_topic_id": 4, "name": "Архив"]],
        ["info": ["forum_topic_id": 8, "name": "Дубликат"]],
        ["info": ["forum_topic_id": 9, "name": "  "]],
        ["info": ["forum_topic_id": -2, "name": "Некорректная"]],
    ]
    #expect(ForumTopicCatalog.parse(topics) == [
        ForumTopicDescriptor(id: 41, title: "Общие", isGeneral: true),
        ForumTopicDescriptor(id: 4, title: "Архив"),
        ForumTopicDescriptor(id: 8, title: "Работа"),
    ])
}

@Test func tdlibNotificationsKeepAccountChatAndForumTopicIdentity() throws {
    let accountA = AccountUUID()
    let accountB = AccountUUID()
    let notification: [String: Any] = [
        "id": 9,
        "date": 123,
        "is_silent": true,
        "type": [
            "@type": "notificationTypeNewMessage",
            "show_preview": true,
            "message": [
                "id": 77,
                "chat_id": -44,
                "topic_id": ["@type": "messageTopicForum", "forum_topic_id": 12],
                "content": ["@type": "messageText", "text": ["text": "Привет"]],
            ],
        ],
    ]

    let routedA = try #require(TDLibNotificationRouter.route(account: accountA, groupID: 3, groupChatID: 1, notification: notification))
    let routedB = try #require(TDLibNotificationRouter.route(account: accountB, groupID: 3, groupChatID: 1, notification: notification))
    #expect(routedA.conversation == ConversationKey(account: accountA, chatID: -44, topic: .forum(topicID: 12)))
    #expect(routedA.messageID == 77)
    #expect(routedA.preview == "Привет")
    #expect(routedA.isSilent)
    #expect(routedA.systemIdentifier != routedB.systemIdentifier)
}

@Test func privacyLockKeepsActiveNotificationRouteWithGenericContent() throws {
    let account = AccountUUID()
    let raw: [String: Any] = [
        "id": 9,
        "is_silent": false,
        "type": [
            "@type": "notificationTypeNewMessage",
            "show_preview": true,
            "message": [
                "id": 77,
                "chat_id": 44,
                "content": ["@type": "messageText", "text": ["text": "Sensitive message text"]],
            ],
        ],
    ]
    let routed = try #require(TDLibNotificationRouter.route(account: account, groupID: 3, groupChatID: 44, notification: raw))
    let identifier = routed.systemIdentifier
    let locked = TDLibNotificationRouter.presentation(for: routed, isPrivacyLocked: true, chatTitle: "Private chat", isReconciliation: true)
    let unlocked = TDLibNotificationRouter.presentation(for: routed, isPrivacyLocked: false, chatTitle: "Alice")

    #expect(locked == TDLibNotificationPresentation(title: "NeTelegram", body: "Новое сообщение", playsSound: false))
    #expect(!locked.title.contains("Private chat"))
    #expect(!locked.body.contains("Sensitive message text"))
    #expect(unlocked == TDLibNotificationPresentation(title: "Alice", body: "Sensitive message text", playsSound: true))
    #expect(routed.systemIdentifier == identifier)
    #expect(routed.conversation == ConversationKey(account: account, chatID: 44, topic: .main))
}

@Test func lockedNotificationHandoffOpensExactCurrentTopicAfterVerifiedUnlock() {
    let account = AccountUUID()
    let notification = RoutedTDLibNotification(
        account: account,
        groupID: 3,
        notificationID: 9,
        conversation: ConversationKey(account: account, chatID: -44, topic: .forum(topicID: 12)),
        messageID: 77,
        date: 123,
        isSilent: true,
        showsPreview: false,
        preview: nil
    )
    var handoff = NotificationUnlockHandoff()
    handoff.stage(notification, runtimeGeneration: RuntimeGeneration(4), expectedTelegramUserID: 701)

    let opened = handoff.resolve(
        unlockSucceeded: true,
        account: account,
        runtimeGeneration: RuntimeGeneration(4),
        telegramUserID: 701,
        authorizationState: "authorizationStateReady",
        notificationIsCurrent: true
    )

    #expect(opened == notification)
    #expect(opened?.conversation.chatID == -44)
    #expect(opened?.conversation.topic == .forum(topicID: 12))
    #expect(opened?.messageID == 77)
    #expect(handoff.pending == nil)
}

@Test func lockedNotificationHandoffClearsOnCancelOrStaleIdentity() {
    let account = AccountUUID()
    let notification = RoutedTDLibNotification(
        account: account,
        groupID: 3,
        notificationID: 9,
        conversation: ConversationKey(account: account, chatID: 55, topic: .main),
        messageID: 77,
        date: 123,
        isSilent: true,
        showsPreview: false,
        preview: nil
    )

    var cancelled = NotificationUnlockHandoff()
    cancelled.stage(notification, runtimeGeneration: RuntimeGeneration(4), expectedTelegramUserID: 701)
    let cancelledRoute = cancelled.resolve(
        unlockSucceeded: false,
        account: account,
        runtimeGeneration: RuntimeGeneration(4),
        telegramUserID: 701,
        authorizationState: "authorizationStateReady",
        notificationIsCurrent: true
    )
    #expect(cancelledRoute == nil)
    #expect(cancelled.pending == nil)

    var replaced = NotificationUnlockHandoff()
    replaced.stage(notification, runtimeGeneration: RuntimeGeneration(4), expectedTelegramUserID: 701)
    let staleRoute = replaced.resolve(
        unlockSucceeded: true,
        account: account,
        runtimeGeneration: RuntimeGeneration(5),
        telegramUserID: 701,
        authorizationState: "authorizationStateReady",
        notificationIsCurrent: true
    )
    #expect(staleRoute == nil)
    #expect(replaced.pending == nil)

    var loggedOut = NotificationUnlockHandoff()
    loggedOut.stage(notification, runtimeGeneration: RuntimeGeneration(4), expectedTelegramUserID: 701)
    let changedIdentity = loggedOut.resolve(
        unlockSucceeded: true,
        account: account,
        runtimeGeneration: RuntimeGeneration(4),
        telegramUserID: 702,
        authorizationState: "authorizationStateReady",
        notificationIsCurrent: true
    )
    #expect(changedIdentity == nil)
    #expect(loggedOut.pending == nil)
}

@Test func lockedNotificationHandoffRejectsRemovedNotificationOrAccount() {
    let account = AccountUUID()
    let notification = RoutedTDLibNotification(
        account: account,
        groupID: 3,
        notificationID: 9,
        conversation: ConversationKey(account: account, chatID: 55, topic: .main),
        messageID: 77,
        date: 123,
        isSilent: true,
        showsPreview: false,
        preview: nil
    )
    var handoff = NotificationUnlockHandoff()
    handoff.stage(notification, runtimeGeneration: RuntimeGeneration(4), expectedTelegramUserID: 701)
    let removed = handoff.resolve(
        unlockSucceeded: true,
        account: account,
        runtimeGeneration: RuntimeGeneration(4),
        telegramUserID: 701,
        authorizationState: "authorizationStateReady",
        notificationIsCurrent: false
    )
    #expect(removed == nil)

    handoff.stage(notification, runtimeGeneration: RuntimeGeneration(4), expectedTelegramUserID: 701)
    handoff.clear(account: account)
    #expect(handoff.pending == nil)
}

@Test func tdlibNotificationRouterDoesNotInventRoutesForUnknownKindsOrTopics() {
    let account = AccountUUID()
    let call: [String: Any] = [
        "id": 1,
        "type": ["@type": "notificationTypeNewCall", "call_id": 2],
    ]
    #expect(TDLibNotificationRouter.route(account: account, groupID: 1, groupChatID: 5, notification: call) == nil)

    let pushWithoutConversation: [String: Any] = [
        "id": 3,
        "type": ["@type": "notificationTypeNewPushMessage", "message_id": 89, "content": ["@type": "pushMessageContentHidden"]],
    ]
    #expect(TDLibNotificationRouter.route(account: account, groupID: 1, groupChatID: 5, notification: pushWithoutConversation) == nil)

    let unknownTopic: [String: Any] = [
        "id": 2,
        "type": [
            "@type": "notificationTypeNewMessage",
            "show_preview": false,
            "message": [
                "id": 88,
                "chat_id": 5,
                "topic_id": ["@type": "messageTopicFuture"],
            ],
        ],
    ]
    #expect(TDLibNotificationRouter.route(account: account, groupID: 1, groupChatID: 5, notification: unknownTopic) == nil)
}

@Test func conversationHistoryRequestsPreserveEveryTypedTopic() {
    let account = AccountUUID()
    let targets: [(ConversationTopicKey, String, String, Int64)] = [
        (.main, "getChatHistory", "chat_id", 41),
        (.thread(messageThreadID: 17), "getMessageThreadHistory", "message_id", 17),
        (.forum(topicID: 12), "getForumTopicHistory", "forum_topic_id", 12),
        (.directMessages(topicID: 23), "getDirectMessagesChatTopicHistory", "topic_id", 23),
        (.savedMessages(topicID: 29), "getSavedMessagesTopicHistory", "saved_messages_topic_id", 29),
    ]

    for (topic, expectedType, topicField, topicID) in targets {
        let request = ConversationHistoryRequest.make(
            for: ConversationKey(account: account, chatID: 41, topic: topic),
            fromMessageID: 99,
            limit: 37
        )
        #expect(request["@type"] as? String == expectedType)
        let hasChatID = (request["chat_id"] as? NSNumber)?.int64Value == 41
        #expect(hasChatID == (topic != .savedMessages(topicID: 29)))
        #expect((request[topicField] as? NSNumber)?.int64Value == topicID)
        #expect((request["from_message_id"] as? NSNumber)?.int64Value == 99)
        #expect((request["limit"] as? NSNumber)?.int32Value == 37)
    }
}

@Test func textSendPermissionRejectsChannelsUnknownSendersTopicsAndPaidOptions() {
    let ordinaryGroup = ChatSendPermission(canSendBasicMessages: true, isChannel: false, defaultSenderTelegramUserID: 123)
    #expect(ordinaryGroup.permitsTextSend(as: 123, topic: .main, paidStars: 0))
    #expect(ordinaryGroup.permitsTextSend(as: 123, topic: .forum(topicID: 7), paidStars: 0))
    #expect(!ordinaryGroup.permitsTextSend(as: 123, topic: .thread(messageThreadID: 8), paidStars: 0))
    #expect(!ordinaryGroup.permitsTextSend(as: 123, topic: .main, paidStars: 1))
    #expect(!ordinaryGroup.permitsTextSend(as: 999, topic: .main, paidStars: 0))
    #expect(!ChatSendPermission(canSendBasicMessages: false, isChannel: false, defaultSenderTelegramUserID: 123).permitsTextSend(as: 123, topic: .main))
    #expect(!ChatSendPermission(canSendBasicMessages: true, isChannel: true, defaultSenderTelegramUserID: 123).permitsTextSend(as: 123, topic: .main))
    #expect(!ChatSendPermission(canSendBasicMessages: true, isChannel: false, defaultSenderTelegramUserID: nil).permitsTextSend(as: 123, topic: .main))
}

@Test func urlEntitiesUseTDLibUTF16OffsetsAndPreserveSourceText() {
    let text = "👍 Open https://example.com/path, then http://example.org."
    let entities = TextEntityParser.entities(in: text)
    #expect(entities == [
        TextEntitySpan(offsetUTF16: 8, lengthUTF16: 24, type: "textEntityTypeUrl"),
        TextEntitySpan(offsetUTF16: 39, lengthUTF16: 18, type: "textEntityTypeUrl"),
    ])
    let nsText = text as NSString
    #expect(entities.map { nsText.substring(with: NSRange(location: Int($0.offsetUTF16), length: Int($0.lengthUTF16))) } == [
        "https://example.com/path", "http://example.org",
    ])
    #expect(TextEntityParser.entities(in: "http:// and https://valid.example").count == 1)
}
