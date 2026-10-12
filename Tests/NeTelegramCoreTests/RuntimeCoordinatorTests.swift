import Foundation
import CoreGraphics
import ImageIO
import Testing
@testable import NeTelegramCore

private final class LockedTestValue<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Value

    init(_ value: Value) { stored = value }

    func set(_ value: Value) {
        lock.lock()
        stored = value
        lock.unlock()
    }

    func get() -> Value {
        lock.lock()
        defer { lock.unlock() }
        return stored
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

@Test func networkTypePolicyDropsDuplicatePathEventsButAllowsWakeRefresh() {
    #expect(NetworkTypeUpdatePolicy.tdlibType(isSatisfied: false, usesWiFi: false, usesCellular: false) == "networkTypeNone")
    #expect(NetworkTypeUpdatePolicy.tdlibType(isSatisfied: true, usesWiFi: true, usesCellular: false) == "networkTypeWiFi")
    #expect(NetworkTypeUpdatePolicy.tdlibType(isSatisfied: true, usesWiFi: false, usesCellular: true) == "networkTypeMobile")
    #expect(NetworkTypeUpdatePolicy.tdlibType(isSatisfied: true, usesWiFi: false, usesCellular: false) == "networkTypeOther")
    #expect(NetworkTypeUpdatePolicy.tdlibType(isSatisfied: true, usesWiFi: true, usesCellular: true) == "networkTypeWiFi")
    #expect(!NetworkTypeUpdatePolicy.shouldApply(current: "networkTypeWiFi", next: "networkTypeWiFi"))
    #expect(NetworkTypeUpdatePolicy.shouldApply(current: "networkTypeWiFi", next: "networkTypeNone"))
    #expect(NetworkTypeUpdatePolicy.shouldApply(current: "networkTypeWiFi", next: "networkTypeWiFi", force: true))
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
    #expect(buffer.take() == first)
    #expect(await producer.value)
    #expect(buffer.count == 1)
    #expect(buffer.queuedByteCount == second.count)
    #expect(buffer.blockedProducerCount == 0)
    #expect(buffer.take() == second)
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
    #expect(buffer.take() == accepted)
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
    #expect(buffer.take() == first)
    #expect(await producer.value)
    #expect(buffer.queuedByteCount == 2)
    #expect(buffer.take() == second)
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
    #expect(buffer.take() == oversized)
    #expect(await following.value)
    #expect(buffer.take() == Data("x".utf8))
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

    DispatchQueue.global().async {
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

    DispatchQueue.global().async {
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
            _ = releaseFirstDecode.wait(timeout: .now() + 3)
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
