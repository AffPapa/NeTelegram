import Foundation
import CoreGraphics
import ImageIO
import LocalAuthentication
import Security
import Testing
@testable import NeTelegramCore

private final class RuntimeOwnershipProbe {}

@Test func authReturnDoesNotSubmitDuringMarkedIMEComposition() {
    #expect(AuthTextFieldKeyboardPolicy.shouldSubmit(
        isAuthenticationField: true,
        isReturnCommand: true,
        hasMarkedText: false
    ))
    #expect(!AuthTextFieldKeyboardPolicy.shouldSubmit(
        isAuthenticationField: true,
        isReturnCommand: true,
        hasMarkedText: true
    ))
    #expect(!AuthTextFieldKeyboardPolicy.shouldSubmit(
        isAuthenticationField: true,
        isReturnCommand: false,
        hasMarkedText: false
    ))
    #expect(!AuthTextFieldKeyboardPolicy.shouldSubmit(
        isAuthenticationField: false,
        isReturnCommand: true,
        hasMarkedText: false
    ))
}

@Test func composerKeyboardSendRequiresSafeFocusedCommandReturn() {
    #expect(ComposerKeyboardCommandPolicy.shouldSend(isCommandReturn: true, composerIsFocused: true, isLocked: false, hasMarkedText: false, sendIsEnabled: true))
    #expect(!ComposerKeyboardCommandPolicy.shouldSend(isCommandReturn: false, composerIsFocused: true, isLocked: false, hasMarkedText: false, sendIsEnabled: true))
    #expect(!ComposerKeyboardCommandPolicy.shouldSend(isCommandReturn: true, composerIsFocused: false, isLocked: false, hasMarkedText: false, sendIsEnabled: true))
    #expect(!ComposerKeyboardCommandPolicy.shouldSend(isCommandReturn: true, composerIsFocused: true, isLocked: true, hasMarkedText: false, sendIsEnabled: true))
    #expect(!ComposerKeyboardCommandPolicy.shouldSend(isCommandReturn: true, composerIsFocused: true, isLocked: false, hasMarkedText: true, sendIsEnabled: true))
    #expect(!ComposerKeyboardCommandPolicy.shouldSend(isCommandReturn: true, composerIsFocused: true, isLocked: false, hasMarkedText: false, sendIsEnabled: false))
}

@Test func loginItemPreferencePolicyOnlyRegistersAfterExplicitOptIn() {
    #expect(LoginItemPreferencePolicy.action(for: .notRegistered, requestedEnabled: false) == .noChange)
    #expect(LoginItemPreferencePolicy.action(for: .notRegistered, requestedEnabled: true) == .register)
    #expect(LoginItemPreferencePolicy.action(for: .requiresApproval, requestedEnabled: true) == .openLoginItemsSettings)
    #expect(LoginItemPreferencePolicy.action(for: .requiresApproval, requestedEnabled: false) == .unregister)
    #expect(LoginItemPreferencePolicy.action(for: .enabled, requestedEnabled: true) == .noChange)
    #expect(LoginItemPreferencePolicy.action(for: .enabled, requestedEnabled: false) == .unregister)
    #expect(LoginItemPreferencePolicy.action(for: .unavailable, requestedEnabled: false) == .showUnavailable)
    #expect(LoginItemPreferencePolicy.action(for: .unavailable, requestedEnabled: true) == .showUnavailable)
}

@Test func accountNotificationCleanupRemovesOnlyClosedAccountsRoutes() {
    let closedAccount = AccountUUID()
    let activeAccount = AccountUUID()
    let closedNotification = RoutedTDLibNotification(
        account: closedAccount,
        groupID: 1,
        notificationID: 10,
        conversation: ConversationKey(account: closedAccount, chatID: 100),
        messageID: 11,
        date: 12,
        isSilent: false,
        showsPreview: true,
        preview: "closed account preview"
    )
    let activeNotification = RoutedTDLibNotification(
        account: activeAccount,
        groupID: 2,
        notificationID: 20,
        conversation: ConversationKey(account: activeAccount, chatID: 200),
        messageID: 21,
        date: 22,
        isSilent: false,
        showsPreview: true,
        preview: "active account preview"
    )
    var identifiersByAccount = [
        closedAccount: Set([closedNotification.systemIdentifier]),
        activeAccount: Set([activeNotification.systemIdentifier]),
    ]
    var targetsByIdentifier = [
        closedNotification.systemIdentifier: closedNotification,
        activeNotification.systemIdentifier: activeNotification,
    ]

    let removed = AccountNotificationCleanup.remove(
        account: closedAccount,
        identifiersByAccount: &identifiersByAccount,
        targetsByIdentifier: &targetsByIdentifier
    )

    #expect(removed == [closedNotification.systemIdentifier])
    #expect(identifiersByAccount[closedAccount] == nil)
    #expect(identifiersByAccount[activeAccount] == [activeNotification.systemIdentifier])
    #expect(targetsByIdentifier[closedNotification.systemIdentifier] == nil)
    #expect(targetsByIdentifier[activeNotification.systemIdentifier] == activeNotification)
}

@Test func accountNotificationCleanupRemovesOnlyExactDeletedMessages() {
    let accountA = AccountUUID()
    let accountB = AccountUUID()
    func notification(account: AccountUUID, chatID: Int64, messageID: Int64, groupID: Int32) -> RoutedTDLibNotification {
        RoutedTDLibNotification(
            account: account,
            groupID: groupID,
            notificationID: Int32(messageID),
            conversation: ConversationKey(account: account, chatID: chatID, topic: .forum(topicID: 3)),
            messageID: messageID,
            date: 1,
            isSilent: true,
            showsPreview: true,
            preview: "private preview"
        )
    }
    let deleted = notification(account: accountA, chatID: 90, messageID: 4, groupID: 1)
    let sameChatOtherMessage = notification(account: accountA, chatID: 90, messageID: 5, groupID: 1)
    let otherChatSameID = notification(account: accountA, chatID: 91, messageID: 4, groupID: 2)
    let otherAccountSameIDs = notification(account: accountB, chatID: 90, messageID: 4, groupID: 3)
    var identifiersByAccount = [
        accountA: Set([deleted.systemIdentifier, sameChatOtherMessage.systemIdentifier, otherChatSameID.systemIdentifier]),
        accountB: Set([otherAccountSameIDs.systemIdentifier]),
    ]
    var targets = Dictionary(uniqueKeysWithValues: [deleted, sameChatOtherMessage, otherChatSameID, otherAccountSameIDs].map { ($0.systemIdentifier, $0) })

    let removed = AccountNotificationCleanup.removeMessages(
        account: accountA,
        chatID: 90,
        messageIDs: [4],
        identifiersByAccount: &identifiersByAccount,
        targetsByIdentifier: &targets
    )

    #expect(removed == [deleted.systemIdentifier])
    #expect(targets[deleted.systemIdentifier] == nil)
    #expect(targets[sameChatOtherMessage.systemIdentifier] == sameChatOtherMessage)
    #expect(targets[otherChatSameID.systemIdentifier] == otherChatSameID)
    #expect(targets[otherAccountSameIDs.systemIdentifier] == otherAccountSameIDs)
    #expect(identifiersByAccount[accountA] == [sameChatOtherMessage.systemIdentifier, otherChatSameID.systemIdentifier])
    #expect(identifiersByAccount[accountB] == [otherAccountSameIDs.systemIdentifier])
}

@Test func privacyLockPurgesPresentationDraftsButRetainsDirtyRecoveryUntilUnlock() {
    let dirtyAccount = AccountUUID()
    let persistedAccount = AccountUUID()
    let dirtyConversation = ConversationKey(account: dirtyAccount, chatID: 10)
    let persistedConversation = ConversationKey(account: persistedAccount, chatID: 20)
    var presentationDrafts = [
        dirtyConversation: "unsaved sensitive draft",
        persistedConversation: "already persisted draft",
    ]

    var lockedDirtyDrafts = DraftPrivacyCache.lock(
        presentationDrafts: &presentationDrafts,
        dirtyAccounts: [dirtyAccount]
    )

    #expect(presentationDrafts.isEmpty)
    #expect(lockedDirtyDrafts == [dirtyConversation: "unsaved sensitive draft"])

    DraftPrivacyCache.unlock(
        presentationDrafts: &presentationDrafts,
        lockedDirtyDrafts: &lockedDirtyDrafts
    )

    #expect(presentationDrafts == [dirtyConversation: "unsaved sensitive draft"])
    #expect(lockedDirtyDrafts.isEmpty)
}

@Test func dirtyDraftRecoveryRemainsInQuitSnapshotAfterLockClearsPresentationCache() {
    let account = AccountUUID()
    let otherAccount = AccountUUID()
    let conversation = ConversationKey(account: account, chatID: 10)
    let otherConversation = ConversationKey(account: otherAccount, chatID: 20)
    var presentationDrafts = [conversation: "last unsaved copy", otherConversation: "other account"]
    let recovery = DraftPrivacyCache.lock(presentationDrafts: &presentationDrafts, dirtyAccounts: [account])

    #expect(presentationDrafts.isEmpty)
    #expect(recovery == [conversation: "last unsaved copy"])
    #expect(DraftPrivacyCache.draftsForPersistence(
        account: account,
        presentationDrafts: presentationDrafts,
        lockedDirtyDrafts: recovery
    ) == [conversation: "last unsaved copy"])
}

@Test func acceptedSendRemovesOnlyMatchingDraftFromLockedDirtyRecovery() {
    let account = AccountUUID()
    let sentConversation = ConversationKey(account: account, chatID: 30)
    let newerConversation = ConversationKey(account: account, chatID: 31)
    var presentationDrafts: [ConversationKey: String] = [:]
    var lockedDirtyDrafts = [
        sentConversation: "accepted text",
        newerConversation: "another unsaved draft",
    ]

    #expect(DraftPrivacyCache.removeIfMatching(
        sentConversation,
        text: "accepted text",
        presentationDrafts: &presentationDrafts,
        lockedDirtyDrafts: &lockedDirtyDrafts
    ))
    #expect(lockedDirtyDrafts == [newerConversation: "another unsaved draft"])
    #expect(DraftPrivacyCache.draftsForPersistence(
        account: account,
        presentationDrafts: presentationDrafts,
        lockedDirtyDrafts: lockedDirtyDrafts
    ) == [newerConversation: "another unsaved draft"])

    #expect(!DraftPrivacyCache.removeIfMatching(
        newerConversation,
        text: "older accepted text",
        presentationDrafts: &presentationDrafts,
        lockedDirtyDrafts: &lockedDirtyDrafts
    ))
    #expect(lockedDirtyDrafts[newerConversation] == "another unsaved draft")
}

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
    #expect(PhoneNumberInputPolicy.validate("+66 81 234 5678", selectedCallingCode: "") == .accepted("+66812345678"))
    #expect(PhoneNumberInputPolicy.validate("0812345678", selectedCallingCode: "") == .invalidCountryCode)
}

@Test func phoneNumberContinueRequiresAValidNumberAndExplicitCountryWhenLocal() {
    #expect(!PhoneNumberInputPolicy.canContinue("", selectedCallingCode: "", countryCatalogAvailable: true))
    #expect(!PhoneNumberInputPolicy.canContinue("812345678", selectedCallingCode: "", countryCatalogAvailable: true))
    #expect(!PhoneNumberInputPolicy.canContinue("abc", selectedCallingCode: "66", countryCatalogAvailable: true))
    #expect(!PhoneNumberInputPolicy.canContinue("8", selectedCallingCode: "66", countryCatalogAvailable: true))
    #expect(PhoneNumberInputPolicy.canContinue("812345678", selectedCallingCode: "66", countryCatalogAvailable: true))
    #expect(PhoneNumberInputPolicy.canContinue("+66 81 234 5678", selectedCallingCode: "", countryCatalogAvailable: false))
    #expect(!PhoneNumberInputPolicy.canContinue("0812345678", selectedCallingCode: "", countryCatalogAvailable: false))
}

@Test func macOSCountrySuggestionDoesNotSelectCallingCodeForPhoneLogin() {
    var selection = PhoneCountrySelectionState(suggestedRegionCode: "TH")
    #expect(selection.suggestedRegionCode == "TH")
    #expect(selection.selectedRegionCode == nil)
    #expect(selection.selectedCallingCode.isEmpty)
    #expect(PhoneNumberInputPolicy.validate("812345678", selectedCallingCode: selection.selectedCallingCode) == .invalidCountryCode)
    #expect(PhoneNumberInputPolicy.validate("+66 81 234 5678", selectedCallingCode: selection.selectedCallingCode) == .accepted("+66812345678"))

    selection.select(regionCode: "TH", callingCode: "66")
    #expect(selection.selectedRegionCode == "TH")
    #expect(PhoneNumberInputPolicy.validate("812345678", selectedCallingCode: selection.selectedCallingCode) == .accepted("+66812345678"))

    selection.clearSelection()
    #expect(selection.suggestedRegionCode == "TH")
    #expect(selection.selectedRegionCode == nil)
    #expect(selection.selectedCallingCode.isEmpty)
}

@Test func countryPickerSearchFiltersNamesCodesAndKeepsSharedCallingCodeRegionsDistinct() {
    let countries = [
        CountryPickerSearchEntry(regionCode: "US", name: "United States", callingCode: "1"),
        CountryPickerSearchEntry(regionCode: "CA", name: "Канада", callingCode: "1", alternateNames: ["Canada"]),
        CountryPickerSearchEntry(regionCode: "GB", name: "United Kingdom", callingCode: "44"),
        CountryPickerSearchEntry(regionCode: "ES", name: "España", callingCode: "34"),
    ]

    #expect(CountryPickerSearch.filter(countries, query: "can").map(\.regionCode) == ["CA"])
    #expect(CountryPickerSearch.filter(countries, query: "канада").map(\.regionCode) == ["CA"])
    #expect(CountryPickerSearch.filter(countries, query: "GB").map(\.regionCode) == ["GB"])
    #expect(Set(CountryPickerSearch.filter(countries, query: "+1").map(\.regionCode)) == Set(["US", "CA"]))
    #expect(CountryPickerSearch.filter(countries, query: "espana").map(\.regionCode) == ["ES"])
    #expect(CountryPickerSearch.filter(countries, query: "  ") == countries)
}

@Test func bundledCountryCallingCodeCatalogIsCompleteAndWellFormed() {
    let entries = CountryCallingCodeCatalog.entries
    #expect(entries.count >= 240)
    #expect(Set(entries.map(\.regionCode)).count == entries.count)
    #expect(entries.allSatisfy { $0.regionCode.count == 2 && $0.regionCode.allSatisfy(\.isASCII) })
    #expect(entries.allSatisfy { !$0.callingCode.isEmpty && $0.callingCode.allSatisfy(\.isNumber) })
    #expect(entries.contains(.init(regionCode: "US", callingCode: "1")))
    #expect(entries.contains(.init(regionCode: "CA", callingCode: "1")))
}

@Test func incomingTextEntitiesPreserveUTF16RangesAndResolveOnlySafeLinks() {
    let text = "😀 visit t.me/example and read this label"
    let source = text as NSString
    let urlRange = source.range(of: "t.me/example")
    let labelRange = source.range(of: "this label")
    let spans = IncomingTextEntityPresentation.spans(in: [
        "text": text,
        "entities": [
            [
                "offset": urlRange.location,
                "length": urlRange.length,
                "type": ["@type": "textEntityTypeUrl"],
            ],
            [
                "offset": labelRange.location,
                "length": labelRange.length,
                "type": ["@type": "textEntityTypeTextUrl", "url": "https://example.org/read"],
            ],
            [
                "offset": Int32.max,
                "length": 1,
                "type": ["@type": "textEntityTypeBold"],
            ],
            [
                "offset": 0,
                "length": source.length + 1,
                "type": ["@type": "textEntityTypeUrl"],
            ],
        ],
    ])

    #expect(spans.count == 2)
    #expect(spans[0].offsetUTF16 == urlRange.location)
    #expect(IncomingTextEntityPresentation.destination(for: spans[0], in: text)?.absoluteString == "https://t.me/example")
    #expect(IncomingTextEntityPresentation.destination(for: spans[1], in: text)?.absoluteString == "https://example.org/read")
}

@Test func incomingTextEntityRejectsUnsafeTextUrlSchemes() {
    let text = "open this"
    let span = IncomingTextEntitySpan(
        offsetUTF16: 0,
        lengthUTF16: (text as NSString).length,
        type: "textEntityTypeTextUrl",
        argument: "file:///private/secret"
    )
    #expect(IncomingTextEntityPresentation.destination(for: span, in: text) == nil)
}

@Test func developmentWindowTitleIdentifiesTheExactDevCommitButLeavesReleaseBrandingAlone() {
    #expect(DevelopmentBuildIdentity.windowTitle("NeTelegram", bundleIdentifier: "org.affpapa.netelegram.dev", sourceCommit: "ABCDEF123456") == "NeTelegram · dev abcdef12")
    #expect(DevelopmentBuildIdentity.windowTitle("NeTelegram", bundleIdentifier: "org.affpapa.netelegram.dev", sourceCommit: "abcdef123456", hasUncommittedChanges: true) == "NeTelegram · dev abcdef12+dirty")
    #expect(DevelopmentBuildIdentity.windowTitle("NeTelegram", bundleIdentifier: "org.affpapa.netelegram.dev", sourceCommit: nil) == "NeTelegram · dev unknown")
    #expect(DevelopmentBuildIdentity.windowTitle("NeTelegram", bundleIdentifier: "org.affpapa.netelegram", sourceCommit: "abcdef1234567890") == "NeTelegram")
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

@Test func sponsoredMessageViewsRequireFullyVisibleSupportedCards() {
    func card(_ id: Int64, _ type: String) -> SponsoredMessageCard {
        SponsoredMessageCard(tdlibObject: [
            "message_id": id,
            "title": "Ad",
            "content": ["@type": type, "text": ["text": "Ad text"]],
            "sponsor": ["url": "https://example.org/"],
        ])!
    }
    let cards = [
        card(17, "messageText"),
        card(18, "messagePhoto"),
        card(19, "messageVideo"),
        card(17, "messageText"),
    ]
    #expect(SponsoredMessagesPolicy.viewableMessageIDs(cards: cards, fullyVisibleIDs: [17, 18, 19]) == [17, 18])
    #expect(SponsoredMessagesPolicy.viewableMessageIDs(cards: cards, fullyVisibleIDs: [18, 19]) == [18])
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


@Test func terminationCancellationReportsCauseAndPreservesBarrier() {
    var shutdown = RuntimeShutdownCoordinator()
    let clients: Set<Int32> = [11, 12]
    #expect(shutdown.beginReportingRejection(clients: clients) == .began)

    let duplicate = shutdown.beginReportingRejection(clients: [])
    #expect(duplicate == .rejected(.alreadyPending))
    #expect(shutdown.pendingClientIDs == clients)
    #expect(RuntimeShutdownRejection.alreadyPending.userMessage.contains("дождитесь подтверждения"))
    #expect(RuntimeShutdownRejection.alreadyPending.userMessage.contains("не отправлена"))

    let closedFirst = shutdown.acknowledgeClosed(clientID: 11)
    let closedSecond = shutdown.acknowledgeClosed(clientID: 12)
    #expect(closedFirst)
    #expect(closedSecond)
    let drainBegan = shutdown.beginReceiverDrain()
    #expect(drainBegan)
    let drainFinished = shutdown.finishReceiverDrain()
    #expect(drainFinished)

    #expect(shutdown.beginReportingRejection(clients: clients) == .rejected(.alreadyFinished))
    #expect(RuntimeShutdownRejection.alreadyFinished.userMessage.contains("уже подтверждено"))
    #expect(shutdown.pendingClientIDs.isEmpty)
}

@Test func runtimeShutdownCoordinatorWaitsForAllTwentyClientsAndReceiverDrain() {
    var shutdown = RuntimeShutdownCoordinator()
    let clients = Set((0..<20).map(Int32.init))
    #expect(shutdown.terminationRequestDisposition == .beginNewShutdown)
    let began = shutdown.begin(clients: clients)
    #expect(began)
    #expect(shutdown.terminationRequestDisposition == .rejectWhilePending)
    #expect(shutdown.pendingClientIDs == clients)
    let prematureDrain = shutdown.beginReceiverDrain()
    #expect(!prematureDrain)

    let unknownAcknowledgement = shutdown.acknowledgeClosed(clientID: 99)
    #expect(!unknownAcknowledgement)
    for client in clients.sorted() {
        let acknowledged = shutdown.acknowledgeClosed(clientID: client)
        #expect(acknowledged)
    }
    #expect(shutdown.canDrainReceiver)
    let duplicateAcknowledgement = shutdown.acknowledgeClosed(clientID: clients.first!)
    #expect(!duplicateAcknowledgement)
    let beganDrain = shutdown.beginReceiverDrain()
    #expect(beganDrain)
    #expect(shutdown.terminationRequestDisposition == .rejectWhilePending)
    let finishedDrain = shutdown.finishReceiverDrain()
    #expect(finishedDrain)
    #expect(shutdown.isFinished)
    #expect(shutdown.terminationRequestDisposition == .terminateAfterFinished)
    let duplicateBegin = shutdown.begin(clients: clients)
    #expect(!duplicateBegin)
}

@Test func runtimeShutdownCoordinatorCancelsQuitWhenOneCloseIsRejected() {
    var shutdown = RuntimeShutdownCoordinator()
    let began = shutdown.begin(clients: [11, 12, 13])
    #expect(began)

    // AppKit cancels quit when any close is rejected; already-accepted closes
    // are tracked by the general profile lifecycle until their Closed updates.
    let cancelled = shutdown.cancelAfterCloseRejection(clientID: 12)
    #expect(cancelled)
    #expect(!shutdown.isPending)
    #expect(shutdown.pendingClientIDs.isEmpty)
    let staleAcknowledgement = shutdown.acknowledgeClosed(clientID: 11)
    #expect(!staleAcknowledgement)
    let drainAfterCancel = shutdown.beginReceiverDrain()
    #expect(!drainAfterCancel)
    let duplicateCancellation = shutdown.cancelAfterCloseRejection(clientID: 12)
    #expect(!duplicateCancellation)
    let retryBegan = shutdown.begin(clients: [11, 12, 13])
    #expect(retryBegan)
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

private actor AsyncStringGate {
    private var continuation: CheckedContinuation<String, Never>?
    private var storedValue: String?

    func wait() async -> String {
        if let storedValue { return storedValue }
        return await withCheckedContinuation { continuation = $0 }
    }

    func open(_ value: String) {
        storedValue = value
        continuation?.resume(returning: value)
        continuation = nil
    }
}

private struct FakeKeychainCoordinate: Hashable {
    let account: String
    let service: String
}

private final class FakeKeychainItemBackend: KeychainItemBackend, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [FakeKeychainCoordinate: Data]
    private var deleted: [FakeKeychainCoordinate] = []
    private var reads = 0
    private var interactiveReads = 0
    private var adds = 0
    private var updates = 0
    private var readFailure: OSStatus?
    private var updateFailure: OSStatus?
    private var addFailure: OSStatus?
    private var deleteFailure: OSStatus?

    init(
        values: [FakeKeychainCoordinate: Data] = [:],
        readFailure: OSStatus? = nil,
        updateFailure: OSStatus? = nil,
        addFailure: OSStatus? = nil,
        deleteFailure: OSStatus? = nil
    ) {
        self.values = values
        self.readFailure = readFailure
        self.updateFailure = updateFailure
        self.addFailure = addFailure
        self.deleteFailure = deleteFailure
    }

    func read(account: String, service: String) -> (status: OSStatus, data: Data?) {
        readValue(account: account, service: service, interactive: false)
    }

    func readInteractively(account: String, service: String) -> (status: OSStatus, data: Data?) {
        readValue(account: account, service: service, interactive: true)
    }

    private func readValue(account: String, service: String, interactive: Bool) -> (status: OSStatus, data: Data?) {
        lock.lock()
        defer { lock.unlock() }
        reads += 1
        if interactive { interactiveReads += 1 }
        if let readFailure { return (readFailure, nil) }
        guard let data = values[FakeKeychainCoordinate(account: account, service: service)] else {
            return (errSecItemNotFound, nil)
        }
        return (errSecSuccess, data)
    }

    func add(data: Data, account: String, service: String) -> OSStatus {
        lock.lock()
        defer { lock.unlock() }
        adds += 1
        if let addFailure { return addFailure }
        let coordinate = FakeKeychainCoordinate(account: account, service: service)
        guard values[coordinate] == nil else { return errSecDuplicateItem }
        values[coordinate] = data
        return errSecSuccess
    }

    func update(data: Data, account: String, service: String) -> OSStatus {
        lock.lock()
        defer { lock.unlock() }
        updates += 1
        if let updateFailure { return updateFailure }
        let coordinate = FakeKeychainCoordinate(account: account, service: service)
        guard values[coordinate] != nil else { return errSecItemNotFound }
        values[coordinate] = data
        return errSecSuccess
    }

    func delete(account: String, service: String) -> OSStatus {
        lock.lock()
        defer { lock.unlock() }
        if let deleteFailure { return deleteFailure }
        let coordinate = FakeKeychainCoordinate(account: account, service: service)
        deleted.append(coordinate)
        return values.removeValue(forKey: coordinate) == nil ? errSecItemNotFound : errSecSuccess
    }

    var operationCounts: (reads: Int, interactiveReads: Int, adds: Int, updates: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (reads, interactiveReads, adds, updates)
    }

    var deletedCoordinates: [FakeKeychainCoordinate] {
        lock.lock()
        defer { lock.unlock() }
        return deleted
    }

    func storedData(account: String, service: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return values[FakeKeychainCoordinate(account: account, service: service)]
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

private func waitForCount(_ value: LockedTestValue<Int>, atLeast target: Int, timeout: Duration) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while clock.now < deadline {
        if value.get() >= target { return true }
        try? await Task.sleep(for: .milliseconds(1))
    }
    return value.get() >= target
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

@Test func accountPresentationReopensRememberedChatOnlyForCurrentVerifiedIdentity() {
    #expect(AccountPresentation.conversationRestoration(
        telegramUserID: 441,
        authorizationState: "authorizationStateReady",
        selectedChatID: 77
    ) == .reopen(chatID: 77))
    #expect(AccountPresentation.conversationRestoration(
        telegramUserID: 441,
        authorizationState: nil,
        selectedChatID: nil
    ) == .emptyConversation)
    #expect(AccountPresentation.conversationRestoration(
        telegramUserID: nil,
        authorizationState: "authorizationStateReady",
        selectedChatID: 77
    ) == .authorization)
    #expect(AccountPresentation.conversationRestoration(
        telegramUserID: 441,
        authorizationState: "authorizationStateWaitCode",
        selectedChatID: 77
    ) == .authorization)
}

@Test func accountConversationSnapshotRestoresCorrectAccountTopicAndDraftAcrossABA() {
    let accountA = AccountUUID()
    let accountB = AccountUUID()
    let generationA = RuntimeGeneration(4)
    let generationB = RuntimeGeneration(9)
    let conversationA = ConversationKey(account: accountA, chatID: 77, topic: .forum(topicID: 11))
    let otherTopicA = ConversationKey(account: accountA, chatID: 77, topic: .forum(topicID: 12))
    let conversationB = ConversationKey(account: accountB, chatID: 77, topic: .forum(topicID: 22))
    let snapshots = [
        accountA: AccountConversationSnapshot(
            account: accountA,
            generation: generationA,
            conversation: conversationA,
            draft: "draft belonging to A"
        ),
        accountB: AccountConversationSnapshot(
            account: accountB,
            generation: generationB,
            conversation: conversationB,
            draft: "draft belonging to B"
        ),
    ]

    // Exercise the exact snapshot policy called by AppKit for repeated
    // A -> B -> A transitions. Equal server chat IDs must not blur account or
    // typed forum-topic identity, and each runtime generation stays stable.
    let runtimeGenerations = [accountA: generationA, accountB: generationB]
    let expectedDrafts = [accountA: "draft belonging to A", accountB: "draft belonging to B"]
    let expectedConversations = [accountA: conversationA, accountB: conversationB]
    for transition in 0..<1_000 {
        let selectedAccount = transition.isMultiple(of: 2) ? accountA : accountB
        let snapshot = snapshots[selectedAccount]!
        let selectedConversation = expectedConversations[selectedAccount]!
        #expect(snapshot.restoredDraft(
            account: selectedAccount,
            generation: runtimeGenerations[selectedAccount]!,
            conversation: selectedConversation
        ) == expectedDrafts[selectedAccount])
        #expect(snapshot.account == selectedAccount)
        #expect(snapshot.generation == runtimeGenerations[selectedAccount])
        #expect(snapshot.conversation == selectedConversation)
    }
    let restoredA = snapshots[accountA]!
    #expect(AccountPresentation.conversationRestoration(
        telegramUserID: 501,
        authorizationState: "authorizationStateReady",
        snapshot: restoredA,
        expectedAccount: accountA,
        expectedGeneration: generationA
    ) == .reopen(chatID: 77))
    #expect(restoredA.restoredDraft(
        account: accountA,
        generation: generationA,
        conversation: conversationA
    ) == "draft belonging to A")
    #expect(restoredA.restoredDraft(
        account: accountB,
        generation: generationB,
        conversation: conversationB
    ) == nil)
    #expect(restoredA.restoredDraft(
        account: accountA,
        generation: generationA,
        conversation: otherTopicA
    ) == nil)
    #expect(conversationA != conversationB)
    #expect(AccountPresentation.conversationRestoration(
        telegramUserID: 501,
        authorizationState: "authorizationStateReady",
        snapshot: restoredA,
        expectedAccount: accountA,
        expectedGeneration: generationB
    ) == .authorization)
}

@Test func tdlibReceiveCopyFailureDrainsAcceptedEventsThenFailsClosed() async throws {
    let coordinator = RuntimeCoordinator(startupParallelism: 2)
    let account = AccountUUID()
    let route = RuntimeRoute(account: account, generation: RuntimeGeneration(1), client: ClientID(17))
    try await coordinator.registerBeforeFirstRequest(route)

    let pollCount = LockedTestValue(0)
    let gateway = TDLibGateway { _ in
        let current = pollCount.get()
        pollCount.set(current + 1)
        if current == 0 {
            return .update(Data(#"{"@client_id":17,"@type":"updateConnectionState"}"#.utf8))
        }
        return .copyFailure
    }
    let pipeline = TDLibUpdatePipeline(gateway: gateway, coordinator: coordinator)
    let events = LockedTestValue<[String]>([])
    let failed = LockedTestValue(false)
    pipeline.start(
        onEvent: { event in
            if case .routed = event { events.mutate { $0.append("update") } }
        },
        onReceiveFailure: { error in
            if error == .receiveCopyFailed { events.mutate { $0.append("failure") } }
            failed.set(true)
        }
    )

    #expect(await waitForTrue(failed, timeout: .seconds(2)))
    #expect(events.get() == ["update", "failure"])
    #expect(gateway.receiveWorkerHasExited)
    do {
        try gateway.send("{}", to: route.client)
        Issue.record("Gateway must reject sends after receive-copy failure")
    } catch let error as TDLibGatewayError {
        #expect(error == .receiveCopyFailed)
    } catch {
        Issue.record("Unexpected gateway error: \(error)")
    }
}

@Test func receiveWorkerExitWaitersResumeOnlyAfterExitCallbackCompletes() async {
    let exitCallbackEntered = LockedTestValue(false)
    let waiterReturned = LockedTestValue(false)
    let releaseExitCallback = DispatchSemaphore(value: 0)
    let gateway = TDLibGateway { _ in .timeout }
    gateway.startSingleReceiveWorker(
        timeoutSeconds: 0.01,
        onUpdate: { _ in .accepted },
        onExit: {
            exitCallbackEntered.set(true)
            releaseExitCallback.wait()
        }
    )
    gateway.requestWorkerStop()

    let waiter = Task {
        await gateway.waitForReceiveWorkerExit()
        waiterReturned.set(true)
    }
    #expect(await waitForTrue(exitCallbackEntered, timeout: .seconds(2)))
    #expect(!waiterReturned.get(), "The exit barrier must include the pipeline's onExit callback")

    releaseExitCallback.signal()
    #expect(await waitForTrue(waiterReturned, timeout: .seconds(2)))
    await waiter.value
    #expect(gateway.receiveWorkerHasExited)
}

@Test func unknownClientUpdateFailsSharedReceiverAfterDrainingAcceptedEvents() async throws {
    let coordinator = RuntimeCoordinator(startupParallelism: 2)
    let account = AccountUUID()
    let route = RuntimeRoute(account: account, generation: RuntimeGeneration(1), client: ClientID(17))
    try await coordinator.registerBeforeFirstRequest(route)

    let pollCount = LockedTestValue(0)
    let gateway = TDLibGateway { _ in
        let current = pollCount.get()
        pollCount.set(current + 1)
        switch current {
        case 0:
            return .update(Data(#"{"@client_id":17,"@type":"updateConnectionState"}"#.utf8))
        case 1:
            return .update(Data(#"{"@client_id":99,"@type":"updateDeleteMessages"}"#.utf8))
        default:
            return .timeout
        }
    }
    let pipeline = TDLibUpdatePipeline(gateway: gateway, coordinator: coordinator)
    let events = LockedTestValue<[String]>([])
    let failed = LockedTestValue(false)
    pipeline.start(
        onEvent: { event in
            switch event {
            case .routed(let update):
                events.mutate { $0.append("routed-\(update.route.client.value)") }
            case .routingFailure(.unregisteredClientID(let client)):
                events.mutate { $0.append("unknown-\(client.value)") }
            case .routingFailure:
                events.mutate { $0.append("other-routing-failure") }
            }
        },
        onReceiveFailure: { error in
            if error == .routingFailure(.unregisteredClientID(ClientID(99))) {
                events.mutate { $0.append("terminal") }
            }
            failed.set(true)
        }
    )

    #expect(await waitForTrue(failed, timeout: .seconds(2)))
    let delivered = events.get()
    #expect(delivered.contains("routed-17"))
    #expect(delivered.contains("unknown-99"))
    #expect(delivered.last == "terminal")
    let workerDeadline = ContinuousClock.now.advanced(by: .seconds(2))
    while !gateway.receiveWorkerHasExited && ContinuousClock.now < workerDeadline {
        try await Task.sleep(for: .milliseconds(1))
    }
    #expect(gateway.receiveWorkerHasExited)
    do {
        try gateway.send("{}", to: route.client)
        Issue.record("Gateway must reject every account send after an unrouteable update")
    } catch let error as TDLibGatewayError {
        #expect(error == .routingFailure(.unregisteredClientID(ClientID(99))))
    } catch {
        Issue.record("Unexpected gateway error: \(error)")
    }
}

@Test func accountPickerUsesHumanLocalLabelsAndExplicitAuthorizationStatus() {
    #expect(AccountPresentation.pickerStatus(
        telegramUserID: 123,
        authorizationState: nil,
        runtimeIsOpen: true,
        hasError: false
    ) == .starting)

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
    let networkUpdatePending = AccountPresentation.pickerTitle(
        localOrdinal: 3,
        telegramUserID: 123,
        candidate: "Test User",
        authorizationState: "authorizationStateReady",
        runtimeIsOpen: true,
        hasError: false,
        networkUpdatePending: true
    )
    let closedBackgroundProfile = AccountPresentation.pickerTitle(
        localOrdinal: 3,
        telegramUserID: 123,
        candidate: "Test User",
        authorizationState: nil,
        runtimeIsOpen: false,
        hasError: true
    )
    let logoutCleanup = AccountPresentation.pickerTitle(
        localOrdinal: 4,
        telegramUserID: 123,
        candidate: "Test User",
        authorizationState: nil,
        runtimeIsOpen: false,
        hasError: true,
        logoutCleanupPending: true
    )
    let removalCleanup = AccountPresentation.pickerTitle(
        localOrdinal: 5,
        telegramUserID: nil,
        candidate: nil,
        authorizationState: nil,
        runtimeIsOpen: false,
        hasError: true,
        unverifiedRemovalPending: true
    )

    #expect(firstPending == "Вход NeTelegram 1 — ожидает номер")
    #expect(secondPending == "Вход NeTelegram 2 — ожидает код")
    #expect(verified == "Test User · аккаунт 3 — подключён")
    #expect(networkUpdatePending == "Test User · аккаунт 3 — подключён · ожидает обновление сети")
    #expect(closedBackgroundProfile == "Test User · аккаунт 3 — ошибка")
    #expect(logoutCleanup == "Test User · аккаунт 4 — очистка после выхода ожидает")
    #expect(removalCleanup == "Вход NeTelegram 5 — удаление незавершённого входа ожидает")
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

@Test func unfinishedAccountSelectionExplainsItsLocalOriginWithoutShowingUUID() {
    let localUUID = "6BFF7C49-92B1-4883-8262-BF1E56906A42"
    let pending = AccountPresentation.selectionStatus(
        localOrdinal: 2,
        telegramUserID: nil,
        candidate: localUUID
    )
    #expect(pending.contains("Локальный вход NeTelegram 2"))
    #expect(pending.contains("запись создана в этом приложении"))
    #expect(pending.contains("Сессии других приложений не импортируются"))
    #expect(!pending.contains(localUUID))

    let verified = AccountPresentation.selectionStatus(
        localOrdinal: 2,
        telegramUserID: 123,
        candidate: "Test User"
    )
    #expect(verified == "Выбран аккаунт Test User. Остальные авторизованные аккаунты продолжают работу.")
}

@Test func statusMenuKeepsClosedBackgroundProfileInFailureCount() {
    let active = AccountUUID()
    let waiting = AccountUUID()
    let closedBackground = AccountUUID()
    let summary = AccountStatusMenuSummary.make(
        runtimes: [
            AccountStatusMenuRuntime(
                account: active,
                telegramUserID: 441,
                authorizationState: "authorizationStateReady",
                hasError: false
            ),
            AccountStatusMenuRuntime(
                account: waiting,
                telegramUserID: nil,
                authorizationState: "authorizationStateWaitCode",
                hasError: false
            ),
        ],
        startupFailures: [closedBackground]
    )

    #expect(summary.authorizedCount == 1)
    #expect(summary.awaitingInputCount == 1)
    #expect(summary.failedCount == 1)
}

@Test func unsupportedIncomingContentKeepsHumanReadableContextWithoutLeakingConstructors() {
    #expect(IncomingMessagePresentation.cardText(for: "messageVoiceNote") == "Голосовое сообщение · воспроизведение не поддерживается")
    #expect(IncomingMessagePresentation.chatPreview(for: "messagePaidMedia") == "Платный контент")
    #expect(IncomingMessagePresentation.cardText(for: "messageFutureType").contains("Вложение или новый тип сообщения"))
    #expect(!IncomingMessagePresentation.cardText(for: "messageFutureType").contains("messageFutureType"))
    #expect(IncomingMessagePresentation.cardText(for: "messagePaidMedia").contains("не выполняет оплату"))
}

@Test func unsupportedMessageCardsKeepAvailableCaptionMetadataAndTime() {
    let message: [String: Any] = [
        "id": 42,
        "chat_id": 9001,
        "sender_id": ["@type": "messageSenderUser", "user_id": 17],
        "date": 1_700_000_000,
        "content": [
            "@type": "messageDocument",
            "caption": ["@type": "formattedText", "text": "  Квитанция за поездку  ", "entities": []],
            "document": ["file_name": "receipt.pdf", "local": ["path": "/private/account/secret.pdf"]],
        ],
    ]

    let details = IncomingMessagePresentation.contextLines(for: message)
    #expect(details.first == "Квитанция за поездку")
    #expect(details.contains("receipt.pdf"))
    #expect(details.contains(where: { $0.hasPrefix("Дата сообщения:") }))
    #expect(!details.contains(where: { $0.contains("9001") || $0.contains("17") || $0.contains("/private/account") }))
}

@Test func unsupportedMessageCardsPreserveAudioAndPollContextWithoutConstructorNames() {
    let audio: [String: Any] = [
        "content": ["@type": "messageAudio", "audio": ["title": "Трек", "performer": "Исполнитель"]],
    ]
    let poll: [String: Any] = [
        "content": ["@type": "messagePoll", "poll": ["question": "Куда поедем?"]],
    ]
    let future: [String: Any] = [
        "content": ["@type": "messageFutureType", "caption": ["text": "Контекст будущего типа"]],
    ]

    #expect(IncomingMessagePresentation.contextLines(for: audio) == ["Исполнитель — Трек"])
    #expect(IncomingMessagePresentation.contextLines(for: poll) == ["Куда поедем?"])
    #expect(IncomingMessagePresentation.contextLines(for: future) == ["Контекст будущего типа"])
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

@Test func secretsStoreReadQueryDisallowsImplicitKeychainAuthenticationUI() {
    let query = SecretsStore.keychainReadQuery(account: "test-account", service: "test-service")
    let context = query[kSecUseAuthenticationContext as String] as? LAContext

    #expect(query[kSecAttrAccount as String] as? String == "test-account")
    #expect(query[kSecAttrService as String] as? String == "test-service")
    #expect(context != nil)
    #expect(context?.interactionNotAllowed == true)
    #expect(query[kSecUseAuthenticationUI as String] == nil)
}

@Test func secretsStoreInteractiveReadIsExplicitAndDoesNotReuseNoninteractiveContext() {
    let query = SecretsStore.keychainReadQuery(
        account: "test-account",
        service: "test-service",
        allowingInteraction: true
    )
    #expect(query[kSecAttrAccount as String] as? String == "test-account")
    #expect(query[kSecAttrService as String] as? String == "test-service")
    #expect(query[kSecUseAuthenticationContext as String] == nil)
    #expect(query[kSecUseAuthenticationUI as String] == nil)
}

@Test func telegramAPIHashUsesInteractiveKeychainReadOnlyWhenExplicitlyRequested() throws {
    let value = "0123456789abcdef0123456789ABCDEF"
    let backend = FakeKeychainItemBackend(values: [
        FakeKeychainCoordinate(
            account: TelegramApplicationIdentity.keychainAccount,
            service: TelegramApplicationIdentity.keychainService
        ): Data(value.utf8)
    ])

    #expect(try SecretsStore(backend: backend).telegramAPIHash(allowingUserInteraction: true) == value)
    #expect(backend.operationCounts.reads == 1)
    #expect(backend.operationCounts.interactiveReads == 1)
}

@Test func telegramAPIHashAcceptsOnlyThirtyTwoAsciiHexCharacters() {
    #expect(SecretsStore.isValidTelegramAPIHash("0123456789abcdef0123456789ABCDEF"))
    #expect(!SecretsStore.isValidTelegramAPIHash("0123456789abcdef0123456789ABCDE"))
    #expect(!SecretsStore.isValidTelegramAPIHash("0123456789abcdef0123456789ABCDEG"))
    #expect(!SecretsStore.isValidTelegramAPIHash("0123456789abcdef0123456789ABCDEＦ"))
    #expect(!SecretsStore.isValidTelegramAPIHash(" 0123456789abcdef0123456789ABCDEF "))
}

@Test func telegramAPIHashReadUsesOnlyTheConfiguredItemAndRejectsInvalidStoredValues() throws {
    let service = TelegramApplicationIdentity.keychainService
    let account = TelegramApplicationIdentity.keychainAccount
    let validValue = "0123456789abcdef0123456789ABCDEF"
    let validBackend = FakeKeychainItemBackend(values: [
        FakeKeychainCoordinate(account: account, service: service): Data(validValue.utf8),
        FakeKeychainCoordinate(account: account, service: "unrelated-service"): Data(validValue.utf8),
    ])
    #expect(try SecretsStore(backend: validBackend).telegramAPIHash() == validValue)
    #expect(validBackend.operationCounts.reads == 1)

    let missingBackend = FakeKeychainItemBackend(values: [
        FakeKeychainCoordinate(account: account, service: "unrelated-service"): Data(validValue.utf8),
    ])
    #expect(throws: SecretsStoreError.missing("Telegram API hash")) {
        try SecretsStore(backend: missingBackend).telegramAPIHash()
    }
    #expect(missingBackend.operationCounts.reads == 1)

    let failedBackend = FakeKeychainItemBackend(readFailure: errSecInteractionNotAllowed)
    #expect(throws: SecretsStoreError.keychain(errSecInteractionNotAllowed)) {
        try SecretsStore(backend: failedBackend).telegramAPIHash()
    }
    #expect(failedBackend.operationCounts.reads == 1)

    for invalidValue in [Data(), Data("not-a-hash".utf8), Data(repeating: 0xff, count: 32)] {
        let invalidBackend = FakeKeychainItemBackend(values: [
            FakeKeychainCoordinate(account: account, service: service): invalidValue,
        ])
        #expect(throws: SecretsStoreError.invalidTelegramAPIHash) {
            try SecretsStore(backend: invalidBackend).telegramAPIHash()
        }
        #expect(invalidBackend.operationCounts.reads == 1)
    }
}

@Test func secretsStoreCreatesKeysOnlyAfterExplicitKeychainNotFound() {
    #expect(SecretsStore.keyLookupDecision(status: errSecItemNotFound, data: nil, createIfMissing: true) == .create)
    #expect(SecretsStore.keyLookupDecision(status: errSecItemNotFound, data: nil, createIfMissing: false) == .missing)
    #expect(SecretsStore.keyLookupDecision(status: errSecInteractionNotAllowed, data: nil, createIfMissing: true) == .failure(errSecInteractionNotAllowed))
    #expect(SecretsStore.keyLookupDecision(status: errSecAuthFailed, data: nil, createIfMissing: true) == .failure(errSecAuthFailed))
}

@Test func secretsStoreRejectsMalformedExistingKeyWithoutReplacement() {
    #expect(SecretsStore.keyLookupDecision(status: errSecSuccess, data: Data(repeating: 7, count: 32), createIfMissing: true) == .use(Data(repeating: 7, count: 32)))
    #expect(SecretsStore.keyLookupDecision(status: errSecSuccess, data: Data(repeating: 7, count: 31), createIfMissing: true) == .failure(errSecDecode))
    #expect(SecretsStore.keyLookupDecision(status: errSecSuccess, data: nil, createIfMissing: true) == .failure(errSecDecode))
}

@Test func secretsStoreUsesInjectedKeychainCRUDAndFailsClosed() throws {
    let account = AccountUUID()
    let accountName = account.id.uuidString.lowercased()
    let databaseService = "org.affpapa.netelegram.database-key"

    let failedReadBackend = FakeKeychainItemBackend(readFailure: errSecInteractionNotAllowed)
    let failedReadStore = SecretsStore(backend: failedReadBackend)
    #expect(throws: SecretsStoreError.keychain(errSecInteractionNotAllowed)) {
        try failedReadStore.databaseKey(for: account)
    }
    #expect(failedReadBackend.operationCounts.adds == 0)

    let createBackend = FakeKeychainItemBackend()
    let createStore = SecretsStore(backend: createBackend)
    let createdKey = try createStore.databaseKey(for: account)
    #expect(createdKey.count == 32)
    #expect(createBackend.operationCounts.adds == 1)
    #expect(try createStore.databaseKey(for: account) == createdKey)
    #expect(createBackend.operationCounts.adds == 1)
    #expect(createBackend.storedData(account: accountName, service: databaseService) == createdKey)

    let readOnlyBackend = FakeKeychainItemBackend()
    let readOnlyStore = SecretsStore(backend: readOnlyBackend)
    #expect(throws: SecretsStoreError.missing("Existing key for \(databaseService)")) {
        try readOnlyStore.databaseKey(for: account, createIfMissing: false)
    }
    #expect(readOnlyBackend.operationCounts.adds == 0)

    let apiHash = "0123456789abcdef0123456789ABCDEF"
    let updateFailureBackend = FakeKeychainItemBackend(updateFailure: errSecInteractionNotAllowed)
    let updateFailureStore = SecretsStore(backend: updateFailureBackend)
    #expect(throws: SecretsStoreError.keychain(errSecInteractionNotAllowed)) {
        try updateFailureStore.storeTelegramAPIHash(apiHash)
    }
    #expect(updateFailureBackend.operationCounts.updates == 1)
    #expect(updateFailureBackend.operationCounts.adds == 0)
}

@Test func secretsStoreDeletesOnlyTheRequestedAccountsKeyNamespaces() throws {
    let account = AccountUUID()
    let otherAccount = AccountUUID()
    let accountName = account.id.uuidString.lowercased()
    let otherAccountName = otherAccount.id.uuidString.lowercased()
    let database = "org.affpapa.netelegram.database-key"
    let appState = "org.affpapa.netelegram.app-state-key"
    let apiHashService = TelegramApplicationIdentity.keychainService
    let backend = FakeKeychainItemBackend(values: [
        FakeKeychainCoordinate(account: accountName, service: database): Data(repeating: 1, count: 32),
        FakeKeychainCoordinate(account: accountName, service: appState): Data(repeating: 2, count: 32),
        FakeKeychainCoordinate(account: otherAccountName, service: database): Data(repeating: 3, count: 32),
        FakeKeychainCoordinate(account: otherAccountName, service: appState): Data(repeating: 4, count: 32),
        FakeKeychainCoordinate(account: TelegramApplicationIdentity.keychainAccount, service: apiHashService): Data("0123456789abcdef0123456789ABCDEF".utf8),
    ])

    try SecretsStore(backend: backend).removeAccountKeys(for: account)

    #expect(Set(backend.deletedCoordinates) == Set([
        FakeKeychainCoordinate(account: accountName, service: database),
        FakeKeychainCoordinate(account: accountName, service: appState),
    ]))
    #expect(backend.storedData(account: otherAccountName, service: database) == Data(repeating: 3, count: 32))
    #expect(backend.storedData(account: otherAccountName, service: appState) == Data(repeating: 4, count: 32))
    #expect(backend.storedData(account: TelegramApplicationIdentity.keychainAccount, service: apiHashService) != nil)
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
    #expect(firstLoad != nil)
    #expect(state.state == .loading)
    let duplicateLoad = state.beginLoad()
    #expect(duplicateLoad == nil)

    let firstCompleted = state.completeLoad(requestID: firstLoad!)
    #expect(firstCompleted)
    #expect(state.state == .loaded)
    let alreadyLoaded = state.beginLoad()
    #expect(alreadyLoaded == nil)

    let nextPage = state.beginNextPage()
    #expect(nextPage != nil)
    #expect(state.state == .loading)
    let nextPageCompleted = state.completeLoad(requestID: nextPage!)
    #expect(nextPageCompleted)
    #expect(state.state == .loaded)

    let finalPage = state.beginNextPage()
    #expect(finalPage != nil)
    let exhausted = state.finishNoMoreChats(requestID: finalPage!)
    #expect(exhausted)
    #expect(state.state == .exhausted)
    #expect(state.beginNextPage() == nil)

    state.invalidate()
    #expect(state.state == .needsLoad)
    let privacyReload = state.beginLoad()
    #expect(privacyReload != nil)
    let failed = state.failLoad(requestID: privacyReload!)
    #expect(failed)
    #expect(state.state == .failed)
    let retryAfterFailure = state.beginLoad()
    #expect(retryAfterFailure != nil)
    let retryCompleted = state.completeLoad(requestID: retryAfterFailure!)
    #expect(retryCompleted)
    #expect(state.state == .loaded)

    let forcedReload = state.beginLoad(reload: true)
    #expect(forcedReload != nil)
    #expect(state.state == .loading)
}

@Test func staleChatListPageResponseCannotCompleteReplacementSnapshot() {
    var state = ChatListLoadState()
    let first = state.beginLoad()
    #expect(first != nil)

    state.invalidate()
    let replacement = state.beginLoad()
    #expect(replacement != nil)
    #expect(replacement != first)
    let staleResponseAccepted = state.completeLoad(requestID: first!)
    #expect(!staleResponseAccepted)
    #expect(state.state == .loading)
    let replacementCompleted = state.completeLoad(requestID: replacement!)
    #expect(replacementCompleted)
    #expect(state.state == .loaded)
}

@Test func chatListPaginationWaitsForLoadedPageAndDoesNotLeakAcrossAccounts() {
    var policy = ChatListPaginationPolicy()
    let accountA = AccountUUID()
    let accountB = AccountUUID()

    let loadingPageRequested = policy.shouldRequestPage(account: accountA, isNearEnd: true, loadState: .loading)
    #expect(!loadingPageRequested)
    let firstPageRequested = policy.shouldRequestPage(account: accountA, isNearEnd: true, loadState: .loaded)
    #expect(firstPageRequested)
    let duplicatePageRequested = policy.shouldRequestPage(account: accountA, isNearEnd: true, loadState: .loaded)
    #expect(!duplicatePageRequested)

    // Selecting another account at the bottom can request its own page; A's
    // in-flight/recent trigger must not suppress it.
    let accountBPageRequested = policy.shouldRequestPage(account: accountB, isNearEnd: true, loadState: .loaded)
    #expect(accountBPageRequested)
    policy.pageDidComplete(for: accountA)
    let accountAContinuationRequested = policy.shouldRequestPage(account: accountA, isNearEnd: true, loadState: .loaded)
    #expect(accountAContinuationRequested)

    _ = policy.shouldRequestPage(account: accountA, isNearEnd: false, loadState: .loaded)
    let retryAfterLeavingEndRequested = policy.shouldRequestPage(account: accountA, isNearEnd: true, loadState: .loaded)
    #expect(retryAfterLeavingEndRequested)
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
    #expect(AccountRestorePlanner.pendingStartupProfiles(
        candidates: plan,
        running: [],
        starting: []
    ) == profiles)

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

@Test func pendingStartupSelectionKeepsTwentyCandidatesAndExcludesOnlyRunningOrStartingProfiles() {
    let profiles = (1...20).map { n in
        AccountProfile(
            id: AccountUUID(UUID(uuidString: String(format: "70000000-0000-0000-0000-%012d", n))!),
            telegramUserID: Int64(70_000 + n)
        )
    }
    let pending = AccountRestorePlanner.pendingStartupProfiles(
        candidates: profiles,
        running: [profiles[4].id],
        starting: [profiles[11].id]
    )
    #expect(pending.count == 18)
    #expect(pending == profiles.enumerated().compactMap { index, profile in
        index == 4 || index == 11 ? nil : profile
    })
}

@Test func startupDispatchQueuesAllFreeProfilesWhileFirstStartupIsStalled() async {
    let profiles = (1...20).map { n in
        AccountProfile(
            id: AccountUUID(UUID(uuidString: String(format: "71000000-0000-0000-0000-%012d", n))!),
            telegramUserID: Int64(71_000 + n)
        )
    }
    let running = profiles[1].id
    let starting = profiles[3].id
    let gate = AsyncTestGate()
    let firstStartupWaiting = LockedTestValue(false)
    let stalledStartup = LockedTestValue<Task<Void, Never>?>(nil)
    var enqueued: [AccountUUID] = []

    let enqueuedIDs = AccountRestorePlanner.enqueueStartupProfiles(
        candidates: profiles,
        running: [running],
        starting: [starting]
    ) { profile in
        enqueued.append(profile.id)
        if profile.id == profiles[0].id {
            stalledStartup.set(Task {
                firstStartupWaiting.set(true)
                await gate.wait()
            })
        }
        return true
    }

    #expect(enqueuedIDs.queued == enqueued)
    #expect(enqueuedIDs.rejected.isEmpty)
    #expect(enqueued.count == 18)
    #expect(!enqueued.contains(running))
    #expect(!enqueued.contains(starting))
    #expect(await waitForTrue(firstStartupWaiting, timeout: .seconds(2)))
    #expect(enqueued == profiles.compactMap { profile in
        profile.id == running || profile.id == starting ? nil : profile.id
    })

    await gate.open()
    await stalledStartup.get()?.value
}

@Test func restoreEnqueueReportsOneRejectedProfileWithoutDroppingOtherEligibleProfiles() {
    let profiles = (1...20).map { n in
        AccountProfile(
            id: AccountUUID(UUID(uuidString: String(format: "72000000-0000-0000-0000-%012d", n))!),
            telegramUserID: Int64(72_000 + n)
        )
    }
    let alreadyRunning = profiles[1].id
    let alreadyStarting = profiles[3].id
    let rejected = profiles[12].id
    var accepted: [AccountUUID] = []

    let result = AccountRestorePlanner.enqueueStartupProfiles(
        candidates: profiles,
        running: [alreadyRunning],
        starting: [alreadyStarting]
    ) { profile in
        guard profile.id != rejected else { return false }
        accepted.append(profile.id)
        return true
    }

    #expect(result.rejected == [rejected])
    #expect(result.queued == accepted)
    #expect(result.queued.count == 17)
    #expect(!result.queued.contains(alreadyRunning))
    #expect(!result.queued.contains(alreadyStarting))
    #expect(result.queued.contains(profiles[19].id))
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

@Test func staleRuntimeStatusWriteCannotOverwriteNewGeneration() async throws {
    let coordinator = RuntimeCoordinator()
    let account = AccountUUID()
    let oldRoute = RuntimeRoute(account: account, generation: RuntimeGeneration(1), client: ClientID(191))
    #expect(await coordinator.setState(.failed("pre-client startup failure"), for: account))
    try await coordinator.registerBeforeFirstRequest(oldRoute)
    #expect(await coordinator.setState(.waitingForAuthorization, from: oldRoute))
    #expect(await coordinator.applyAuthorizationState("authorizationStateClosed", telegramUserID: nil, from: oldRoute))

    let newRoute = RuntimeRoute(account: account, generation: RuntimeGeneration(2), client: ClientID(192))
    try await coordinator.registerBeforeFirstRequest(newRoute)
    #expect(!(await coordinator.setState(.failed("late old-generation error"), from: oldRoute)))
    #expect(await coordinator.state(for: account) == .starting)

    #expect(await coordinator.applyAuthorizationState("authorizationStateReady", telegramUserID: 842, from: newRoute))
    #expect(!(await coordinator.setState(.failed("route-less stale error"), for: account)))
    #expect(await coordinator.state(for: account) == .active(telegramUserID: 842))
    #expect(await coordinator.setState(.closing, from: newRoute))
    #expect(await coordinator.state(for: account) == .closing)
}

@Test func asyncCallbackRouteOwnershipChangesAfterRuntimeReplacement() async throws {
    let coordinator = RuntimeCoordinator()
    let account = AccountUUID()
    let oldRoute = RuntimeRoute(account: account, generation: RuntimeGeneration(1), client: ClientID(193))
    try await coordinator.registerBeforeFirstRequest(oldRoute)
    #expect(await coordinator.isCurrent(oldRoute))

    #expect(await coordinator.applyAuthorizationState("authorizationStateClosed", telegramUserID: nil, from: oldRoute))
    let newRoute = RuntimeRoute(account: account, generation: RuntimeGeneration(2), client: ClientID(194))
    try await coordinator.registerBeforeFirstRequest(newRoute)

    #expect(!(await coordinator.isCurrent(oldRoute)))
    #expect(await coordinator.isCurrent(newRoute))
}

@MainActor @Test func callbackAfterSuspendedIdentityPersistenceCannotApplyToReplacementRuntime() async throws {
    let coordinator = RuntimeCoordinator()
    let account = AccountUUID()
    let oldRoute = RuntimeRoute(account: account, generation: RuntimeGeneration(1), client: ClientID(195))
    try await coordinator.registerBeforeFirstRequest(oldRoute)

    let consumeGate = AsyncTestGate()
    let coordinatorCheckGate = AsyncTestGate()
    let callbackStarted = LockedTestValue(false)
    let coordinatorCheckStarted = LockedTestValue(false)
    let localRoute = LockedTestValue(oldRoute)
    let sideEffectsApplied = LockedTestValue(false)
    let callback = Task { @MainActor in
        // Represents LocalAccountRuntime.consume suspending while the
        // verified Telegram identity is persisted.
        callbackStarted.set(true)
        let stillOwnsRoute = await RuntimeUpdateOwnership.consumeThenCheck(
            oldRoute,
            consume: { await consumeGate.wait() },
            coordinatorRouteIsCurrent: {
                let wasCurrentBeforeSuspension = await coordinator.isCurrent(oldRoute)
                coordinatorCheckStarted.set(true)
                await coordinatorCheckGate.wait()
                return wasCurrentBeforeSuspension
            },
            localOwnerIsCurrent: { localRoute.get() == oldRoute }
        )
        if stillOwnsRoute { sideEffectsApplied.set(true) }
        return stillOwnsRoute
    }
    #expect(await waitForTrue(callbackStarted, timeout: .seconds(1)))
    await consumeGate.open()
    #expect(await waitForTrue(coordinatorCheckStarted, timeout: .seconds(1)))

    #expect(await coordinator.applyAuthorizationState("authorizationStateClosed", telegramUserID: nil, from: oldRoute))
    let replacement = RuntimeRoute(account: account, generation: RuntimeGeneration(2), client: ClientID(196))
    try await coordinator.registerBeforeFirstRequest(replacement)
    localRoute.set(replacement)
    await coordinatorCheckGate.open()

    #expect(!(await callback.value))
    #expect(!sideEffectsApplied.get())
    #expect(await coordinator.isCurrent(replacement))
}

@MainActor @Test func terminalClosedUpdatePassesOnlyForItsStillOwnedLocalRuntime() async throws {
    let coordinator = RuntimeCoordinator()
    let account = AccountUUID()
    let closedRoute = RuntimeRoute(account: account, generation: RuntimeGeneration(1), client: ClientID(197))
    try await coordinator.registerBeforeFirstRequest(closedRoute)
    #expect(await coordinator.applyAuthorizationState("authorizationStateClosed", telegramUserID: nil, from: closedRoute))

    let localRoute = LockedTestValue<RuntimeRoute?>(closedRoute)
    let cleanupCanRun = await RuntimeUpdateOwnership.isCurrentOrTerminalClose(
        closedRoute,
        isTerminalClose: true,
        coordinatorRouteIsCurrent: { await coordinator.isCurrent(closedRoute) },
        localOwnerIsCurrent: { localRoute.get() == closedRoute }
    )
    #expect(cleanupCanRun)

    let replacement = RuntimeRoute(account: account, generation: RuntimeGeneration(2), client: ClientID(198))
    try await coordinator.registerBeforeFirstRequest(replacement)
    localRoute.set(replacement)
    let staleCloseCanRun = await RuntimeUpdateOwnership.isCurrentOrTerminalClose(
        closedRoute,
        isTerminalClose: true,
        coordinatorRouteIsCurrent: { await coordinator.isCurrent(closedRoute) },
        localOwnerIsCurrent: { localRoute.get() == closedRoute }
    )
    #expect(!staleCloseCanRun)

    let staleOrdinaryEventCanRun = await RuntimeUpdateOwnership.isCurrentOrTerminalClose(
        closedRoute,
        isTerminalClose: false,
        coordinatorRouteIsCurrent: { await coordinator.isCurrent(closedRoute) },
        localOwnerIsCurrent: { localRoute.get() == closedRoute }
    )
    #expect(!staleOrdinaryEventCanRun)
    #expect(await coordinator.isCurrent(replacement))
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

@Test func startupSchedulerReleasesPermitsAfterFailureAndContinuesAllTwentyProfiles() async {
    let scheduler = RuntimeStartupScheduler(parallelism: 2)
    let active = LockedTestValue(0)
    let maximumActive = LockedTestValue(0)
    let successes = LockedTestValue(0)
    let failures = LockedTestValue(0)

    let starts = (0..<20).map { index in
        Task {
            do {
                try await scheduler.withPermit {
                    active.mutate { count in
                        count += 1
                        maximumActive.mutate { $0 = max($0, count) }
                    }
                    defer { active.mutate { $0 -= 1 } }
                    try await Task.sleep(for: .milliseconds(2))
                    if index == 0 { throw CocoaError(.fileReadUnknown) }
                    successes.mutate { $0 += 1 }
                }
            } catch {
                failures.mutate { $0 += 1 }
            }
        }
    }
    for start in starts { await start.value }

    #expect(successes.get() == 19)
    #expect(failures.get() == 1)
    #expect(maximumActive.get() == 2)
    #expect(active.get() == 0)
    #expect(await scheduler.activeStarts() == 0)
    #expect(await scheduler.queuedStarts() == 0)
}

@Test func oneStalledStartupDoesNotBlockTheOtherNineteenProfiles() async {
    let scheduler = RuntimeStartupScheduler(parallelism: 2)
    let stalledStartup = AsyncTestGate()
    let stalledIsHoldingPermit = LockedTestValue(false)
    let completedProfiles = LockedTestValue(0)

    let stalled = Task {
        await scheduler.withPermit {
            stalledIsHoldingPermit.set(true)
            await stalledStartup.wait()
        }
    }
    #expect(await waitForTrue(stalledIsHoldingPermit, timeout: .seconds(2)))

    let otherProfiles = (0..<19).map { _ in
        Task {
            await scheduler.withPermit {
                completedProfiles.mutate { $0 += 1 }
            }
        }
    }

    var allOthersCompleted = false
    // Observe the live counter while the first profile still holds its permit
    // indefinitely (as during a stalled startup operation).
    for _ in 0..<2_000 {
        if completedProfiles.get() == 19 {
            allOthersCompleted = true
            break
        }
        try? await Task.sleep(for: .milliseconds(1))
    }
    #expect(allOthersCompleted, "One stalled profile must not block the other nineteen startup attempts")
    #expect(stalledIsHoldingPermit.get())

    await stalledStartup.open()
    await stalled.value
    for profile in otherProfiles { await profile.value }
    #expect(await scheduler.activeStarts() == 0)
    #expect(await scheduler.queuedStarts() == 0)
}

@Test func verifiedIdentityGateKeepsProfileBoundAcrossReauthorization() {
    var gate = VerifiedIdentityGate(expectedUserID: 7101)
    #expect(gate.verify(7101) == .accepted(7101))
    #expect(gate.verifiedUserID == 7101)

    gate.beginAuthorizationCycle()
    #expect(gate.verifiedUserID == nil)
    #expect(gate.expectedUserID == 7101)
    #expect(gate.verify(8202) == .mismatch(expected: 7101, actual: 8202))
    #expect(gate.verifiedUserID == nil)
    #expect(gate.expectedUserID == 7101)
    #expect(gate.verify(7101) == .accepted(7101))
}

@Test func verifiedIdentityGateBindsNewProfileOnlyToPositiveServerIdentity() {
    var gate = VerifiedIdentityGate(expectedUserID: nil)
    #expect(gate.verify(0) == .invalid)
    #expect(gate.expectedUserID == nil)
    #expect(gate.verify(9103) == .accepted(9103))
    gate.beginAuthorizationCycle()
    #expect(gate.verify(9103) == .accepted(9103))
    #expect(gate.verify(9104) == .mismatch(expected: 9103, actual: 9104))
}

@MainActor
@Test func twentyProfileRestoreStartupRegistrationSurvivesStallFailureRetryAndSelectionChanges() async throws {
    let profiles = (1...20).map { n in
        AccountProfile(
            id: AccountUUID(UUID(uuidString: String(format: "50000000-0000-0000-0000-%012d", n))!),
            telegramUserID: Int64(20_000 + n)
        )
    }
    let plan = AccountRestorePlanner.profilesToRestore(
        authorized: profiles,
        pending: [],
        pendingWithStoredDatabase: []
    )
    #expect(plan == profiles)

    let coordinator = RuntimeCoordinator(startupParallelism: 2)
    let scheduler = RuntimeStartupScheduler(parallelism: 2)
    let startupTasks = AccountStartupTaskRegistry()
    let stalledOpen = AsyncTestGate()
    let stalledOpenEntered = LockedTestValue(false)
    let routesByProfile = LockedTestValue<[AccountUUID: RuntimeRoute]>([:])
    let failedProfiles = LockedTestValue<Set<AccountUUID>>([])

    let registerAndQueueFirstRequest: @Sendable (AccountProfile, RuntimeGeneration) async -> Void = { profile, generation in
        let suffix = Int32(profile.telegramUserID! - 20_000)
        let client = ClientID(suffix + Int32(generation.value - 1) * 100)
        let route = RuntimeRoute(account: profile.id, generation: generation, client: client)
        do {
            try await coordinator.registerBeforeFirstRequest(route)
            if profile.telegramUserID == 20_002, generation == RuntimeGeneration(1) {
                // The injected TDLib first-request rejection removes only this
                // uninitialized route; it does not strand the startup permit.
                if await coordinator.removeRouteAfterInitializationRequestRejected(route) {
                    failedProfiles.mutate { $0.insert(profile.id) }
                }
                return
            }
            await coordinator.setState(.waitingForAuthorization, for: profile.id)
            routesByProfile.mutate { $0[profile.id] = route }
        } catch {
            Issue.record("Synthetic runtime route registration unexpectedly failed: \(error)")
        }
    }

    // Exercise the same synchronous fan-out helper that restoreProfiles uses.
    // Each accepted profile must immediately become an independent startup
    // task; the scheduler limits only simultaneous opens, never the task count.
    var startsByAccount: [AccountUUID: Task<Void, Never>] = [:]
    let enqueueResult = AccountRestorePlanner.enqueueStartupProfiles(
        candidates: plan,
        running: [],
        starting: []
    ) { profile in
        let task = startupTasks.start(
            account: profile.id,
            scheduler: scheduler,
            operation: {
                if profile.id == profiles[0].id {
                    stalledOpenEntered.set(true)
                    await stalledOpen.wait()
                }
                let generation = await coordinator.nextGeneration(for: profile.id)
                await registerAndQueueFirstRequest(profile, generation)
            }
        )
        startsByAccount[profile.id] = task
        return true
    }
    #expect(enqueueResult.queued == profiles.map(\.id))
    #expect(enqueueResult.rejected.isEmpty)
    #expect(startsByAccount.count == 20)

    #expect(await waitForTrue(stalledOpenEntered, timeout: .seconds(2)))
    for profile in profiles.dropFirst() {
        await startsByAccount[profile.id]?.value
    }
    #expect(await coordinator.startupParallelism == 2)
    #expect(await scheduler.activeStarts() == 1)
    #expect(await scheduler.queuedStarts() == 0)
    #expect(startupTasks.startingAccounts == Set([profiles[0].id]))
    #expect(routesByProfile.get().count == 18)
    #expect(failedProfiles.get() == [profiles[1].id])

    // The stalled profile completes after the other startup attempts have
    // made progress. The failed profile is retried with a fresh generation.
    await stalledOpen.open()
    await startsByAccount[profiles[0].id]?.value
    #expect(routesByProfile.get().count == 19)
    let retry = startupTasks.start(
        account: profiles[1].id,
        scheduler: scheduler,
        operation: {
            let generation = await coordinator.nextGeneration(for: profiles[1].id)
            await registerAndQueueFirstRequest(profiles[1], generation)
        }
    )
    await retry.value
    #expect(routesByProfile.get().count == 20)
    #expect(failedProfiles.get() == [profiles[1].id])
    #expect(await scheduler.activeStarts() == 0)
    #expect(await scheduler.queuedStarts() == 0)

    let routes = profiles.compactMap { routesByProfile.get()[$0.id] }
    #expect(routes.count == 20)
    for (index, route) in routes.enumerated() {
        let expectedIdentity = profiles[index].telegramUserID!
        #expect(await coordinator.applyAuthorizationState(
            "authorizationStateReady",
            telegramUserID: expectedIdentity,
            from: route
        ))
        #expect(await coordinator.state(for: route.account) == .active(telegramUserID: expectedIdentity))
    }

    let first = routes[0]
    let second = routes[1]
    var selectedAccount = first.account
    selectedAccount = second.account
    let updateA = Data("{\"@client_id\":\(first.client.value),\"@type\":\"updateDeleteMessages\"}".utf8)
    #expect(try await coordinator.routeUpdate(updateA).route == first,
            "An update for A must stay routed to A while B is selected")
    selectedAccount = first.account
    #expect(selectedAccount == first.account, "Selection may return to A without replacing runtime identity")

    for route in routes {
        let update = Data("{\"@client_id\":\(route.client.value),\"@type\":\"updateConnectionState\"}".utf8)
        #expect(try await coordinator.routeUpdate(update).route == route)
    }
    let rejectedFirstClient = ClientID(2)
    await #expect(throws: TDLibRoutingError.unregisteredClientID(rejectedFirstClient)) {
        try await coordinator.routeUpdate(Data("{\"@client_id\":2,\"@type\":\"updateAuthorizationState\"}".utf8))
    }

    // Carry the same twenty restored routes through the shared production
    // receive/reducer/delivery pipeline. A delayed callback for one account
    // must not strand the other accounts, and selection changes cannot alter
    // the client identity attached to their updates.
    let updatePayloads = [1, 2].flatMap { sequence in
        routes.map { route in
            Data("{\"@client_id\":\(route.client.value),\"@type\":\"updateConnectionState\",\"sequence\":\(sequence)}".utf8)
        }
    }
    let pollIndex = LockedTestValue(0)
    let gateway = TDLibGateway { _ in
        let index = pollIndex.get()
        pollIndex.set(index + 1)
        guard updatePayloads.indices.contains(index) else { return .timeout }
        return .update(updatePayloads[index])
    }
    let pipeline = TDLibUpdatePipeline(gateway: gateway, coordinator: coordinator)
    let stalledDelivery = AsyncTestGate()
    let stalledDeliveryEntered = LockedTestValue(false)
    let completedUpdates = LockedTestValue<[Int32: [Int]]>([:])
    let completedCount = LockedTestValue(0)
    let pipelineFailed = LockedTestValue(false)
    let stalledClient = first.client.value
    var selectedAccountForPipeline = first.account

    pipeline.start(
        onEvent: { event in
            guard case .routed(let update) = event,
                  let object = try? JSONSerialization.jsonObject(with: update.json) as? [String: Any],
                  let sequence = object["sequence"] as? Int else { return }
            if update.route.client.value == stalledClient, sequence == 1 {
                stalledDeliveryEntered.set(true)
                await stalledDelivery.wait()
            }
            completedUpdates.mutate { $0[update.route.client.value, default: []].append(sequence) }
            completedCount.mutate { $0 += 1 }
        },
        onReceiveFailure: { _ in pipelineFailed.set(true) }
    )

    let firstLaneEntered = await waitForTrue(stalledDeliveryEntered, timeout: .seconds(2))
    #expect(firstLaneEntered, "The injected first account update must enter its delayed delivery lane")
    guard firstLaneEntered else {
        pipeline.requestInputStop()
        await gateway.waitForReceiveWorkerExit()
        await pipeline.finishInputAndDrain()
        return
    }
    selectedAccountForPipeline = second.account
    let otherRoutes = Set(routes.dropFirst().map { $0.client.value })
    let otherLanesAdvanced = await waitForCount(completedCount, atLeast: 38, timeout: .seconds(3))
    #expect(otherLanesAdvanced, "All nineteen background clients must deliver both updates while account one is delayed")
    #expect(Set(completedUpdates.get().keys).isSuperset(of: otherRoutes))
    #expect(selectedAccountForPipeline == second.account)

    await stalledDelivery.open()
    let everyUpdateDelivered = await waitForCount(completedCount, atLeast: updatePayloads.count, timeout: .seconds(3))
    #expect(everyUpdateDelivered)
    pipeline.requestInputStop()
    await gateway.waitForReceiveWorkerExit()
    await pipeline.finishInputAndDrain()

    let expectedSequences = Dictionary(uniqueKeysWithValues: routes.map { ($0.client.value, [1, 2]) })
    #expect(completedUpdates.get() == expectedSequences, "Each restored route must receive its own ordered update sequence")
    #expect(!pipelineFailed.get(), "Synthetic valid client updates must not fail-stop the shared receiver")
    for route in routes {
        #expect(await coordinator.isCurrent(route), "UI selection and background updates must not replace a runtime route")
    }
}

@MainActor @Test func runtimeOwnershipRegistryRetainsAllTwentyAndReleasesOnlyExactGeneration() {
    let registry = RuntimeOwnershipRegistry<RuntimeOwnershipProbe>()
    let routes = (1...20).map { index in
        RuntimeRoute(
            account: AccountUUID(UUID(uuidString: String(format: "72000000-0000-0000-0000-%012d", index))!),
            generation: RuntimeGeneration(1),
            client: ClientID(Int32(index))
        )
    }
    weak var firstRuntime: RuntimeOwnershipProbe?

    for (index, route) in routes.enumerated() {
        let runtime = RuntimeOwnershipProbe()
        if index == 0 { firstRuntime = runtime }
        #expect(registry.retain(runtime, for: route))
    }

    #expect(firstRuntime != nil, "The registry, rather than a local startup variable, must strongly own each open runtime")
    #expect(registry.accounts.count == 20)
    #expect(registry.clients.count == 20)
    var selectedAccount = routes[0].account
    selectedAccount = routes[19].account
    #expect(selectedAccount == routes[19].account)
    for route in routes {
        #expect(registry[account: route.account] != nil)
        #expect(registry[client: route.client.value] === registry[account: route.account])
    }

    let duplicateAccount = RuntimeRoute(
        account: routes[0].account,
        generation: RuntimeGeneration(2),
        client: ClientID(21)
    )
    #expect(!registry.retain(RuntimeOwnershipProbe(), for: duplicateAccount))
    let duplicateClient = RuntimeRoute(
        account: AccountUUID(),
        generation: RuntimeGeneration(1),
        client: routes[0].client
    )
    #expect(!registry.retain(RuntimeOwnershipProbe(), for: duplicateClient))

    #expect(registry.release(route: routes[0], ifOwnedBy: registry[account: routes[0].account]!))
    #expect(firstRuntime == nil, "A confirmed exact-generation release must relinquish the strong runtime owner")
    let replacementRoute = RuntimeRoute(
        account: routes[0].account,
        generation: RuntimeGeneration(2),
        client: ClientID(21)
    )
    let replacement = RuntimeOwnershipProbe()
    #expect(registry.retain(replacement, for: replacementRoute))
    #expect(!registry.release(route: routes[0], ifOwnedBy: replacement), "A stale close cannot release a replacement runtime")
    #expect(registry[account: replacementRoute.account] === replacement)
    #expect(registry[client: replacementRoute.client.value] === replacement)
    #expect(registry.accounts.count == 20)
    #expect(registry.clients.count == 20)
}

@MainActor @Test func lateBackgroundStartupCannotStealNewerAccountSelection() {
    let first = AccountUUID()
    let second = AccountUUID()
    let third = AccountUUID()
    let presentation = AccountStartupPresentationCoordinator()

    presentation.select(second)
    #expect(!presentation.shouldPresentStartupRuntime(
        account: first,
        explicitlySelected: false,
        hasPresentedRuntime: false
    ), "A finishing restore must leave the selected account's startup view in place")
    #expect(presentation.shouldPresentStartupRuntime(
        account: second,
        explicitlySelected: false,
        hasPresentedRuntime: false
    ), "The account currently selected while starting becomes the visible runtime")
    presentation.select(third)
    #expect(!presentation.shouldPresentStartupRuntime(
        account: first,
        explicitlySelected: true,
        hasPresentedRuntime: true
    ), "An older explicit startup request cannot override a later account selection")
    let initialWindowPresentation = AccountStartupPresentationCoordinator()
    #expect(initialWindowPresentation.shouldPresentStartupRuntime(
        account: first,
        explicitlySelected: false,
        hasPresentedRuntime: false
    ), "The first runtime may initialize the window when no account was selected")
    initialWindowPresentation.adoptStartupPresentationIfUnselected(first)
    let initialRuntimeCloseRevision = initialWindowPresentation.selectionRevision
    #expect(initialWindowPresentation.selectionIsCurrent(
        account: first,
        revision: initialRuntimeCloseRevision
    ), "The first auto-presented runtime becomes the current presentation intent")
    initialWindowPresentation.select(second)
    #expect(!initialWindowPresentation.selectionIsCurrent(
        account: first,
        revision: initialRuntimeCloseRevision
    ), "A later user choice invalidates first-runtime cleanup presentation")
    #expect(!initialWindowPresentation.shouldPresentStartupRuntime(
        account: first,
        explicitlySelected: false,
        hasPresentedRuntime: true
    ), "A background startup cannot replace an already visible runtime")
}

@MainActor @Test func delayedClosedAccountCleanupCannotOverrideNewerSelection() {
    let closedAccount = AccountUUID()
    let newlySelectedAccount = AccountUUID()
    let presentation = AccountStartupPresentationCoordinator()

    presentation.select(closedAccount)
    let cleanupRevision = presentation.selectionRevision
    #expect(presentation.selectionIsCurrent(account: closedAccount, revision: cleanupRevision))

    // Model the MainActor being suspended in profile/route cleanup while the
    // user selects another already-open runtime.
    presentation.select(newlySelectedAccount)
    #expect(!presentation.selectionIsCurrent(account: closedAccount, revision: cleanupRevision))
    #expect(presentation.selectionIsCurrent(
        account: newlySelectedAccount,
        revision: presentation.selectionRevision
    ))
}

@MainActor @Test func profileStartupRegistryIsolatesStallsFailuresAndRetries() async {
    enum StartupFailure: Error { case temporary }

    let registry = AccountStartupTaskRegistry()
    let presentation = AccountStartupPresentationCoordinator()
    let stalledAccount = AccountUUID()
    let failingAccount = AccountUUID()
    let stalledGate = AsyncTestGate()
    let stalledStarted = LockedTestValue(false)
    let stalledRuns = LockedTestValue(0)
    let duplicateRuns = LockedTestValue(0)
    let retryCount = LockedTestValue(0)
    let failureMessage = LockedTestValue("")

    let stalledTask = registry.start(account: stalledAccount) {
        stalledRuns.mutate { $0 += 1 }
        stalledStarted.set(true)
        await stalledGate.wait()
    }
    #expect(await waitForTrue(stalledStarted, timeout: .seconds(2)))

    _ = registry.start(account: stalledAccount) {
        duplicateRuns.mutate { $0 += 1 }
    }
    #expect(registry.startingAccounts == Set([stalledAccount]), "Duplicate opens for one account reuse its in-flight task")

    let failedTask = registry.start(
        account: failingAccount,
        operation: { throw StartupFailure.temporary },
        onCompletion: { result in
            if case .failure(let error) = result { failureMessage.set(String(describing: error)) }
        }
    )
    await failedTask.value
    #expect(failureMessage.get().contains("temporary"), "The failing account receives its own startup failure")
    #expect(registry.contains(stalledAccount), "A stalled profile remains registered while the other profile fails")
    #expect(!registry.contains(failingAccount), "A completed failure releases only its own startup registration")

    presentation.select(failingAccount)
    #expect(!presentation.shouldPresentStartupRuntime(
        account: stalledAccount,
        explicitlySelected: false,
        hasPresentedRuntime: false
    ), "The stalled background profile cannot replace the selected profile")

    let retryTask = registry.start(account: failingAccount) {
        retryCount.mutate { $0 += 1 }
    }
    await retryTask.value
    #expect(registry.contains(stalledAccount))
    #expect(!registry.contains(failingAccount))

    await stalledGate.open()
    await stalledTask.value
    #expect(registry.startingAccounts.isEmpty)
    #expect(stalledRuns.get() == 1)
    #expect(duplicateRuns.get() == 0)
    #expect(retryCount.get() == 1)
}

@Test func cancelledQueuedStartupDoesNotRunAfterItsPermitBecomesAvailable() async {
    let scheduler = RuntimeStartupScheduler(parallelism: 1)
    let activeStartup = AsyncTestGate()
    let activeHasPermit = LockedTestValue(false)
    let cancelledOperationRan = LockedTestValue(false)

    let active = Task {
        await scheduler.withPermit {
            activeHasPermit.set(true)
            await activeStartup.wait()
        }
    }
    #expect(await waitForTrue(activeHasPermit, timeout: .seconds(2)))

    let queued = Task {
        await scheduler.withPermit {
            guard !Task.isCancelled else { return }
            cancelledOperationRan.set(true)
        }
    }
    var isQueued = false
    for _ in 0..<2_000 {
        if await scheduler.queuedStarts() == 1 {
            isQueued = true
            break
        }
        try? await Task.sleep(for: .milliseconds(1))
    }
    #expect(isQueued)

    queued.cancel()
    await activeStartup.open()
    await active.value
    await queued.value

    #expect(!cancelledOperationRan.get())
    #expect(await scheduler.activeStarts() == 0)
    #expect(await scheduler.queuedStarts() == 0)
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

@MainActor
@Test func networkTypeFanoutReconcilesAllTwentyRuntimesAndRejectsStaleWork() {
    let accounts = (1...20).map { index in
        AccountUUID(UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!)
    }
    var coordinator = NetworkTypeFanoutCoordinator()
    var applied: [AccountUUID: [String]] = [:]
    let generations = Dictionary(uniqueKeysWithValues: accounts.map { ($0, RuntimeGeneration(7)) })

    let acceptedPathA = coordinator.accept(revision: 1) // Initial path A.
    let appliedPathA = coordinator.applyIfCurrent(type: "networkTypeWiFi", revision: 1, accounts: accounts) {
        applied[$0, default: []].append($1)
        return true
    }
    #expect(acceptedPathA)
    #expect(appliedPathA)

    let acceptedPathB = coordinator.accept(revision: 2) // Route B, still Wi-Fi.
    let rejectedSupersededPathA = !coordinator.applyIfCurrent(type: "networkTypeWiFi", revision: 1, accounts: accounts) {
        applied[$0, default: []].append($1)
        return true
    } // Debounced path A was superseded.
    let appliedPathB = coordinator.applyIfCurrent(type: "networkTypeWiFi", revision: 2, accounts: accounts) {
        applied[$0, default: []].append($1)
        return true
    }
    let rejectedDuplicate = !coordinator.accept(revision: 2) // Duplicate observation.
    let rejectedLatePath = !coordinator.accept(revision: 1) // Late older observation.
    #expect(acceptedPathB)
    #expect(rejectedSupersededPathA)
    #expect(appliedPathB)
    #expect(rejectedDuplicate)
    #expect(rejectedLatePath)

    let acceptedWake = coordinator.accept(revision: 3, force: true) // Wake: reapply current path.
    let appliedWake = coordinator.applyIfCurrent(type: "networkTypeWiFi", revision: 3, force: true, accounts: accounts) {
        applied[$0, default: []].append($1)
        return true
    }
    #expect(acceptedWake)
    #expect(appliedWake)

    #expect(applied.count == 20)
    #expect(applied.values.allSatisfy { $0 == ["networkTypeWiFi", "networkTypeWiFi", "networkTypeWiFi"] })
    #expect(generations.count == 20)
    #expect(generations.values.allSatisfy { $0 == RuntimeGeneration(7) })
}

@MainActor
@Test func networkTypeFanoutKeepsLatestFailedAccountUpdateAndRecoversWithoutOtherAccountRetries() {
    let accounts = (1...20).map { index in
        AccountUUID(UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!)
    }
    let failedAccount = accounts[6]
    var coordinator = NetworkTypeFanoutCoordinator()
    var applied: [AccountUUID: [String]] = [:]

    let acceptedFirst = coordinator.accept(revision: 1)
    #expect(acceptedFirst)
    let appliedFirst = coordinator.applyIfCurrent(type: "networkTypeWiFi", revision: 1, accounts: accounts) { account, type in
        applied[account, default: []].append(type)
        return account != failedAccount
    }
    #expect(appliedFirst)
    #expect(coordinator.pendingAccounts == Set([failedAccount]))
    #expect(coordinator.pendingUpdate(for: failedAccount) == .init(type: "networkTypeWiFi", revision: 1))
    #expect(applied.count == 20)

    // A newer path observation replaces the failed account's desired state.
    let acceptedSecond = coordinator.accept(revision: 2)
    #expect(acceptedSecond)
    let appliedSecond = coordinator.applyIfCurrent(type: "networkTypeMobile", revision: 2, accounts: accounts) { account, type in
        applied[account, default: []].append(type)
        return account != failedAccount
    }
    #expect(appliedSecond)
    #expect(coordinator.pendingUpdate(for: failedAccount) == .init(type: "networkTypeMobile", revision: 2))

    // A later wake retries every live account once, using only the latest state.
    let acceptedWake = coordinator.accept(revision: 3, force: true)
    #expect(acceptedWake)
    let appliedWake = coordinator.applyIfCurrent(type: "networkTypeOther", revision: 3, force: true, accounts: accounts) { account, type in
        applied[account, default: []].append(type)
        return true
    }
    #expect(appliedWake)
    #expect(coordinator.pendingAccounts.isEmpty)
    #expect(coordinator.pendingUpdate(for: failedAccount) == nil)
    #expect(applied[failedAccount] == ["networkTypeWiFi", "networkTypeMobile", "networkTypeOther"])
    #expect(applied.count == 20)
}

@Test func typingActionIsRateLimitedAndStoppedWhenComposerClears() {
    let conversation = ConversationKey(account: AccountUUID(), chatID: 82, topic: .forum(topicID: 9))
    var policy = TypingActionPolicy()

    #expect(policy.update(conversation: conversation, hasText: true, now: 10) == [.typing(conversation)])
    #expect(policy.update(conversation: conversation, hasText: true, now: 12) == [])
    #expect(policy.update(conversation: conversation, hasText: true, now: 14) == [.typing(conversation)])
    #expect(policy.update(conversation: conversation, hasText: false, now: 15) == [.cancel(conversation)])
    #expect(policy.update(conversation: conversation, hasText: false, now: 16) == [])
}

@Test func typingActionCancelsThePreviousTypedTopicBeforeStartingAnother() {
    let account = AccountUUID()
    let first = ConversationKey(account: account, chatID: 82, topic: .forum(topicID: 9))
    let second = ConversationKey(account: account, chatID: 82, topic: .forum(topicID: 10))
    var policy = TypingActionPolicy()

    #expect(policy.update(conversation: first, hasText: true, now: 10) == [.typing(first)])
    #expect(policy.update(conversation: second, hasText: true, now: 11) == [.cancel(first), .typing(second)])
    #expect(policy.stop() == .cancel(second))
    #expect(policy.stop() == nil)
}

@Test func typingActionRetriesAfterDispatchFailureAndHandlesMonotonicClockReset() {
    let conversation = ConversationKey(account: AccountUUID(), chatID: 82)
    var policy = TypingActionPolicy()

    #expect(policy.update(conversation: conversation, hasText: true, now: 10) == [.typing(conversation)])
    policy.retryTypingAction(for: conversation)
    #expect(policy.update(conversation: conversation, hasText: true, now: 10.5) == [.typing(conversation)])
    #expect(policy.update(conversation: conversation, hasText: true, now: 2) == [.typing(conversation)])
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

@Test func updateBufferShutdownPreservesCriticalInFlightDeleteAndRejectsLaterInput() async {
    let buffer = TDLibUpdateBuffer(capacity: 1)
    let accepted = Data("{\"@client_id\":7,\"@type\":\"updateAuthorizationState\",\"sequence\":1}".utf8)
    // Exercise a delete update with TDLib's documented fields as the final
    // result already returned by td_receive while shutdown closes a full queue.
    // This is queue-preservation coverage, not an expiry/TTL integration test.
    let inFlight = Data("{\"@client_id\":7,\"@type\":\"updateDeleteMessages\",\"chat_id\":42,\"message_ids\":[91],\"is_permanent\":true,\"from_cache\":false}".utf8)
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
    buffer.finishInput()
    #expect(buffer.take() == nil)
    #expect(buffer.count == 0)
}

@Test func updateBufferBackpressuresByBytesAndRejectsAnOversizedUpdateAlone() async {
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
    #expect(buffer.admit(oversized) == .oversized(maximumBytes: 5))
    #expect(buffer.queuedByteCount == 0)
    #expect(buffer.append(Data("x".utf8)))
    let followingUpdate = buffer.take()
    #expect(followingUpdate?.json == Data("x".utf8))
    if let followingUpdate { buffer.complete(followingUpdate) }
}

@Test func oversizedSoleReceiveUpdateFailsClosedWithoutEnteringTheReducerQueue() async throws {
    let coordinator = RuntimeCoordinator(startupParallelism: 2)
    let account = AccountUUID()
    let route = RuntimeRoute(account: account, generation: RuntimeGeneration(1), client: ClientID(17))
    try await coordinator.registerBeforeFirstRequest(route)

    let pollCount = LockedTestValue(0)
    let gateway = TDLibGateway { _ in
        let current = pollCount.get()
        pollCount.set(current + 1)
        return current == 0 ? .update(Data(repeating: 0x7f, count: 9)) : .timeout
    }
    let pipeline = TDLibUpdatePipeline(gateway: gateway, coordinator: coordinator, byteCapacity: 8)
    let failureReceived = LockedTestValue(false)
    let failure = LockedTestValue<TDLibGatewayError?>(nil)
    pipeline.start(onEvent: { _ in }, onReceiveFailure: { error in
        failure.set(error)
        failureReceived.set(true)
    })

    #expect(await waitForTrue(failureReceived, timeout: .seconds(2)))
    #expect(failure.get() == .updateTooLarge(maximumBytes: 8))
    #expect(gateway.receiveWorkerHasExited)
    do {
        try gateway.send("{}", to: route.client)
        Issue.record("Gateway must reject sends after an oversized update fails the receive pipeline")
    } catch let error as TDLibGatewayError {
        #expect(error == .updateTooLarge(maximumBytes: 8))
    } catch {
        Issue.record("Unexpected gateway error: \\(error)")
    }
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

@Test func saturatedHotLaneReservesBoundedProgressForAnotherAccount() async {
    let buffer = TDLibUpdateBuffer(capacity: 8, byteCapacity: 4_096)
    let criticalTypes = [
        2: "updateAuthorizationState",
        4: "updateDeleteMessages",
        6: "updateMessageContent",
    ]
    func update(client: Int, sequence: Int, type: String) -> Data {
        Data("{\"@client_id\":\(client),\"@type\":\"\(type)\",\"sequence\":\(sequence)}".utf8)
    }
    var hotSequences = [Int]()
    var observedCriticalTypes = Set<String>()
    func recordHot(_ item: BufferedTDLibUpdate?) {
        guard let item, item.clientID == ClientID(1),
              let object = (try? JSONSerialization.jsonObject(with: item.json)) as? [String: Any] else { return }
        hotSequences.append((object["sequence"] as? NSNumber)?.intValue ?? -1)
        if let type = object["@type"] as? String, criticalTypes.values.contains(type) {
            observedCriticalTypes.insert(type)
        }
    }
    for sequence in 1...8 {
        #expect(buffer.append(update(
            client: 1,
            sequence: sequence,
            type: criticalTypes[sequence] ?? "updateConnectionState"
        )))
    }

    // Simulate the hot account's first callback still being in flight while
    // the shared queue is full. Other account lanes receive only one bounded
    // reserved event at a time and can complete it to release their credit.
    let firstHot = buffer.take()
    #expect(firstHot?.clientID == ClientID(1))
    recordHot(firstHot)
    let otherOne = Task.detached { buffer.append(update(client: 2, sequence: 1, type: "updateConnectionState")) }
    #expect(await otherOne.value)
    #expect(buffer.count == 9)
    #expect(buffer.queuedByteCount <= 4_096 + 1_024)

    let secondHot = buffer.take()
    #expect(secondHot?.clientID == ClientID(1))
    recordHot(secondHot)
    let otherFirst = buffer.take()
    #expect(otherFirst?.clientID == ClientID(2))
    if let otherFirst { buffer.complete(otherFirst) }

    let otherTwo = Task.detached { buffer.append(update(client: 2, sequence: 2, type: "updateDeleteMessages")) }
    #expect(await otherTwo.value)
    let thirdHot = buffer.take()
    #expect(thirdHot?.clientID == ClientID(1))
    recordHot(thirdHot)
    let otherSecond = buffer.take()
    #expect(otherSecond?.clientID == ClientID(2))
    if let otherSecond { buffer.complete(otherSecond) }
    if let firstHot { buffer.complete(firstHot) }
    if let secondHot { buffer.complete(secondHot) }
    if let thirdHot { buffer.complete(thirdHot) }

    buffer.close()
    while let item = buffer.take() {
        recordHot(item)
        buffer.complete(item)
    }

    #expect(hotSequences == Array(1...8))
    #expect(observedCriticalTypes == Set(criticalTypes.values))
    #expect(buffer.count == 0)
    #expect(buffer.queuedByteCount == 0)
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

@Test func twentyClientPipelineKeepsOtherAccountsMovingWhenOneReducerCallbackStalls() async throws {
    let coordinator = RuntimeCoordinator(startupParallelism: 2)
    var routes: [RuntimeRoute] = []
    for value in 1...20 {
        let route = RuntimeRoute(
            account: AccountUUID(UUID(uuidString: String(format: "40000000-0000-0000-0000-%012d", value))!),
            generation: RuntimeGeneration(1),
            client: ClientID(Int32(value))
        )
        try await coordinator.registerBeforeFirstRequest(route)
        routes.append(route)
    }
    let clientIDs = routes.map(\.client)

    let pollIndex = LockedTestValue(0)
    let gateway = TDLibGateway { _ in
        let index = pollIndex.get()
        pollIndex.set(index + 1)
        guard clientIDs.indices.contains(index) else { return .copyFailure }
        let client = clientIDs[index].value
        let eventType = index == 1 ? "updateDeleteMessages" : "updateConnectionState"
        return .update(Data("{\"@client_id\":\(client),\"@type\":\"\(eventType)\"}".utf8))
    }
    let pipeline = TDLibUpdatePipeline(gateway: gateway, coordinator: coordinator)
    let stalledClient = ClientID(1)
    let stalledCallback = AsyncTestGate()
    let started = LockedTestValue<Set<Int32>>([])
    let completed = LockedTestValue<Set<Int32>>([])
    let failed = LockedTestValue(false)

    pipeline.start(
        onEvent: { event in
            guard case .routed(let update) = event else { return }
            started.mutate { $0.insert(update.route.client.value) }
            if update.route.client == stalledClient { await stalledCallback.wait() }
            completed.mutate { $0.insert(update.route.client.value) }
        },
        onReceiveFailure: { _ in failed.set(true) }
    )

    let otherClients = Set((2...20).map(Int32.init))
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(2))
    while !started.get().isSuperset(of: otherClients) && clock.now < deadline {
        try? await Task.sleep(for: .milliseconds(1))
    }
    let otherClientsProgressed = started.get().isSuperset(of: otherClients)
    #expect(otherClientsProgressed, "Every non-stalled client must be routed despite client 1's delayed callback")
    #expect(completed.get().isSuperset(of: otherClients), "One slow account callback must not stop the other 19 lanes")
    #expect(!failed.get(), "Receive failure is reported only after accepted updates are drained")

    await stalledCallback.open()
    #expect(await waitForTrue(failed, timeout: .seconds(2)))
    #expect(completed.get() == Set((1...20).map(Int32.init)))
    #expect(gateway.receiveWorkerHasExited)
}

@Test func twentyClientPipelineStopsBlockedReceiveAndDrainsAcceptedUpdates() async throws {
    let coordinator = RuntimeCoordinator(startupParallelism: 2)
    var routes: [RuntimeRoute] = []
    for value in 1...20 {
        let route = RuntimeRoute(
            account: AccountUUID(UUID(uuidString: String(format: "41000000-0000-0000-0000-%012d", value))!),
            generation: RuntimeGeneration(1),
            client: ClientID(Int32(value))
        )
        try await coordinator.registerBeforeFirstRequest(route)
        routes.append(route)
    }

    let clientIDs = routes.map(\.client)
    let pollIndex = LockedTestValue(0)
    let gateway = TDLibGateway { _ in
        let index = pollIndex.get()
        pollIndex.set(index + 1)
        if clientIDs.indices.contains(index) {
            let client = clientIDs[index].value
            return .update(Data("{\"@client_id\":\(client),\"sequence\":1}".utf8))
        }
        if index == clientIDs.count {
            return .update(Data("{\"@client_id\":1,\"sequence\":2}".utf8))
        }
        return .timeout
    }
    let pipeline = TDLibUpdatePipeline(gateway: gateway, coordinator: coordinator, capacity: 1, byteCapacity: 4_096)
    let stalledCallback = AsyncTestGate()
    let stalledCallbackEntered = LockedTestValue(false)
    let completed = LockedTestValue<[String]>([])
    let finishReturned = LockedTestValue(false)

    pipeline.start(onEvent: { event in
        guard case .routed(let update) = event,
              let object = try? JSONSerialization.jsonObject(with: update.json) as? [String: Any],
              let sequence = object["sequence"] as? Int else { return }
        let label = "\(update.route.client.value):\(sequence)"
        if label == "1:1" {
            stalledCallbackEntered.set(true)
            await stalledCallback.wait()
        }
        completed.mutate { $0.append(label) }
    })

    #expect(await waitForTrue(stalledCallbackEntered, timeout: .seconds(2)), "Account 1 must be inside the stalled callback before shutdown starts")
    let otherClients = Set((2...20).map { "\($0):1" })
    let clock = ContinuousClock()
    let blockedDeadline = clock.now.advanced(by: .seconds(3))
    while (pipeline.buffer.blockedProducerCount == 0 ||
           !Set(completed.get()).isSuperset(of: otherClients)) && clock.now < blockedDeadline {
        try? await Task.sleep(for: .milliseconds(1))
    }
    #expect(Set(completed.get()).isSuperset(of: otherClients), "All other account lanes must make progress while account 1 is stalled")
    #expect(pipeline.buffer.blockedProducerCount == 1, "The next account-1 update must backpressure the sole receive worker")
    #expect(pipeline.buffer.queuedByteCount <= 4_096 + 1_024)

    pipeline.requestInputStop()
    let exitDeadline = clock.now.advanced(by: .seconds(2))
    while !gateway.receiveWorkerHasExited && clock.now < exitDeadline {
        try? await Task.sleep(for: .milliseconds(1))
    }
    #expect(gateway.receiveWorkerHasExited, "Stopping input must wake the blocked receive append and let its thread exit")
    #expect(pipeline.buffer.count == 2, "The stalled callback and the one already-received final update remain accounted for")
    #expect(pipeline.buffer.admit(Data("{\"@client_id\":1,\"sequence\":3}".utf8)) == .stopped)

    let drain = Task {
        await pipeline.finishInputAndDrain()
        finishReturned.set(true)
    }
    let drainDeadline = clock.now.advanced(by: .seconds(2))
    while !pipeline.isDrainRequested && clock.now < drainDeadline {
        try? await Task.sleep(for: .milliseconds(1))
    }
    #expect(pipeline.isDrainRequested, "The drain worker must enter the pending shutdown barrier")
    #expect(!finishReturned.get(), "The shared drain must wait for the stalled accepted callback")

    await stalledCallback.open()
    let drainCompleted = await waitForTrue(finishReturned, timeout: .seconds(2))
    #expect(
        drainCompleted,
        "The receive drain must finish promptly after the stalled callback is released; workerExited=\(gateway.receiveWorkerHasExited), drainRequested=\(pipeline.isDrainRequested), bufferCount=\(pipeline.buffer.count), clientOneQueued=\(pipeline.buffer.queuedClientCount(for: ClientID(1))), queuedBytes=\(pipeline.buffer.queuedByteCount), blockedProducers=\(pipeline.buffer.blockedProducerCount), completed=\(completed.get())"
    )
    guard drainCompleted else { return }
    await drain.value
    #expect(completed.get().count == 21)
    #expect(Set(completed.get()) == Set((2...20).map { "\($0):1" } + ["1:1", "1:2"]))
    #expect(completed.get().filter { $0.hasPrefix("1:") } == ["1:1", "1:2"], "The final accepted update must follow account 1's earlier update")
    #expect(pipeline.buffer.count == 0)
    #expect(pipeline.buffer.queuedByteCount == 0)
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
    try await catalogue.markLogoutCleanupPending(account, expectedTelegramUserID: 123456789)

    let reopened = try AccountCatalogue(rootURL: root)
    let profiles = await reopened.allProfiles()
    #expect(profiles.count == 1)
    #expect(profiles[0].id == account)
    #expect(profiles[0].telegramUserID == 123456789)
    #expect(profiles[0].displayName == "Test User")
    #expect(profiles[0].logoutCleanupPending == true)
    let mode = try FileManager.default.attributesOfItem(atPath: root.appendingPathComponent("accounts.json").path)[.posixPermissions] as? NSNumber
    #expect(mode?.intValue == 0o600)
}

@Test func restorePlannerNeverReopensProfileWithPendingLogoutCleanup() {
    let cleanupPending = AccountProfile(
        id: AccountUUID(),
        telegramUserID: 777,
        displayName: "Former User",
        logoutCleanupPending: true
    )
    let ordinaryPending = AccountProfile(id: AccountUUID())
    let plan = AccountRestorePlanner.profilesToRestore(
        authorized: [cleanupPending],
        pending: [cleanupPending, ordinaryPending],
        pendingWithStoredDatabase: [cleanupPending.id, ordinaryPending.id]
    )
    #expect(plan == [ordinaryPending])
    #expect(AccountRestorePlanner.profilesToRestore(
        authorized: [],
        pending: [cleanupPending],
        pendingWithStoredDatabase: [cleanupPending.id]
    ).isEmpty)
}

@Test func restoreCleanupFanoutDoesNotWaitForOneBlockedProfileBeforeQueueingOthers() async {
    let logoutProfile = AccountProfile(id: AccountUUID(), telegramUserID: 901, logoutCleanupPending: true)
    let unverifiedProfile = AccountProfile(id: AccountUUID(), unverifiedRemovalPending: true)
    let cleanupGate = AsyncTestGate()
    let blockedCleanupEntered = LockedTestValue(false)
    var cleanupTasks: [Task<Void, Never>] = []

    let cleanupResult = AccountRestorePlanner.enqueuePendingCleanups([logoutProfile, unverifiedProfile]) { profile in
        let task = Task {
            if profile.id == logoutProfile.id {
                blockedCleanupEntered.set(true)
                await cleanupGate.wait()
            }
        }
        cleanupTasks.append(task)
        return true
    }

    let authorizedProfiles = (1...19).map { _ in AccountProfile(telegramUserID: 90_000) }
    let startupResult = AccountRestorePlanner.enqueueStartupProfiles(
        candidates: authorizedProfiles,
        running: [],
        starting: []
    ) { _ in true }

    #expect(cleanupResult.queued == [logoutProfile.id, unverifiedProfile.id])
    #expect(cleanupResult.rejected.isEmpty)
    #expect(startupResult.queued == authorizedProfiles.map(\.id))
    #expect(startupResult.rejected.isEmpty)
    #expect(await waitForTrue(blockedCleanupEntered, timeout: .seconds(2)))

    await cleanupGate.open()
    for task in cleanupTasks { await task.value }
}

@Test func pendingUnverifiedProfileRemovalCannotBeRestoredAndCanResumeAfterFailure() async throws {
    enum InjectedFailure: Error { case fileRemoval }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let account = AccountUUID()
    let catalogue = try AccountCatalogue(rootURL: root)
    _ = try await catalogue.addProfile(id: account)
    let accountRoot = root.appendingPathComponent(account.id.uuidString.lowercased(), isDirectory: true)
    try FileManager.default.createDirectory(at: accountRoot, withIntermediateDirectories: true)
    try await catalogue.markUnverifiedRemovalPending(account)

    let marked = try #require(await catalogue.allProfiles().first)
    #expect(marked.telegramUserID == nil)
    #expect(marked.unverifiedRemovalPending == true)
    #expect(AccountRestorePlanner.profilesToRestore(
        authorized: [],
        pending: [marked],
        pendingWithStoredDatabase: [account]
    ).isEmpty)

    let failOnce = LockedTestValue(true)
    await #expect(throws: InjectedFailure.self) {
        try await PendingUnverifiedProfileCleanup.resume(
            account: account,
            catalogue: catalogue,
            removeKeys: { _ in },
            removeFiles: { _ in
                if failOnce.get() {
                    failOnce.set(false)
                    throw InjectedFailure.fileRemoval
                }
                try FileManager.default.removeItem(at: accountRoot)
            }
        )
    }

    let retained = try #require(await catalogue.allProfiles().first)
    #expect(retained.unverifiedRemovalPending == true)
    #expect(AccountRestorePlanner.profilesToRestore(
        authorized: [],
        pending: [retained],
        pendingWithStoredDatabase: [account]
    ).isEmpty)

    try await PendingUnverifiedProfileCleanup.resume(
        account: account,
        catalogue: catalogue,
        removeKeys: { _ in },
        removeFiles: { _ in
            if FileManager.default.fileExists(atPath: accountRoot.path) {
                try FileManager.default.removeItem(at: accountRoot)
            }
        }
    )
    #expect(await catalogue.allProfiles().isEmpty)
    #expect(!FileManager.default.fileExists(atPath: accountRoot.path))
}

@Test func unverifiedRemovalCannotMarkOrDeleteVerifiedIdentity() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let account = AccountUUID()
    let catalogue = try AccountCatalogue(rootURL: root)
    _ = try await catalogue.addProfile(id: account)
    try await catalogue.associateVerifiedIdentity(42, with: account)

    await #expect(throws: AccountCatalogueError.verifiedProfileCannotBeRemoved) {
        try await catalogue.markUnverifiedRemovalPending(account)
    }
    await #expect(throws: AccountCatalogueError.verifiedProfileCannotBeRemoved) {
        try await catalogue.removeUnverifiedProfile(account)
    }
    let retained = try #require(await catalogue.allProfiles().first)
    #expect(retained.telegramUserID == 42)
    #expect(retained.unverifiedRemovalPending != true)
}

@Test func unverifiedRemovalKeepsProfileAndFilesWhenKeychainDeletionFails() async throws {
    enum InjectedFailure: Error { case keychain }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let account = AccountUUID()
    let catalogue = try AccountCatalogue(rootURL: root)
    _ = try await catalogue.addProfile(id: account)
    try await catalogue.markUnverifiedRemovalPending(account)
    let accountRoot = root.appendingPathComponent(account.id.uuidString.lowercased(), isDirectory: true)
    try FileManager.default.createDirectory(at: accountRoot, withIntermediateDirectories: true)
    let failOnce = LockedTestValue(true)
    let removedFiles = LockedTestValue(0)
    let removeKeys: @Sendable (AccountUUID) async throws -> Void = { _ in
        if failOnce.get() {
            failOnce.set(false)
            throw InjectedFailure.keychain
        }
    }
    let removeFiles: @Sendable (AccountUUID) async throws -> Void = { _ in
        removedFiles.mutate { $0 += 1 }
        try FileManager.default.removeItem(at: accountRoot)
    }

    await #expect(throws: InjectedFailure.self) {
        try await PendingUnverifiedProfileCleanup.resume(
            account: account,
            catalogue: catalogue,
            removeKeys: removeKeys,
            removeFiles: removeFiles
        )
    }
    #expect(await catalogue.allProfiles().first?.unverifiedRemovalPending == true)
    #expect(FileManager.default.fileExists(atPath: accountRoot.path))
    #expect(removedFiles.get() == 0)

    try await PendingUnverifiedProfileCleanup.resume(
        account: account,
        catalogue: catalogue,
        removeKeys: removeKeys,
        removeFiles: removeFiles
    )
    #expect(await catalogue.allProfiles().isEmpty)
    #expect(!FileManager.default.fileExists(atPath: accountRoot.path))
    #expect(removedFiles.get() == 1)
}

@Test func identityAssociationIsRejectedAfterUnverifiedRemovalBarrier() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let account = AccountUUID()
    let catalogue = try AccountCatalogue(rootURL: root)
    _ = try await catalogue.addProfile(id: account)
    try await catalogue.markUnverifiedRemovalPending(account)

    await #expect(throws: AccountCatalogueError.identityMismatch) {
        try await catalogue.associateVerifiedIdentity(42, with: account)
    }
    let retained = try #require(await catalogue.allProfiles().first)
    #expect(retained.telegramUserID == nil)
    #expect(retained.unverifiedRemovalPending == true)
}

@Test func pendingLogoutCleanupResumesAfterKeyFileAndCatalogueFailures() async throws {
    enum FailurePoint: Int, CaseIterable, Sendable {
        case keyRemoval
        case fileRemoval
        case cataloguePersistence
    }
    enum InjectedFailure: Error { case step }

    for failurePoint in FailurePoint.allCases {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let account = AccountUUID()
        let catalogue = try AccountCatalogue(rootURL: root)
        _ = try await catalogue.addProfile(id: account)
        try await catalogue.associateVerifiedIdentity(8001, displayName: "Former User", with: account)
        try await catalogue.markLogoutCleanupPending(account, expectedTelegramUserID: 8001)

        let catalogueURL = root.appendingPathComponent("accounts.json")
        let savedCatalogue = try Data(contentsOf: catalogueURL)
        if failurePoint == .cataloguePersistence {
            try FileManager.default.removeItem(at: catalogueURL)
            try FileManager.default.createDirectory(at: catalogueURL, withIntermediateDirectories: false)
        }
        let accountRoot = root.appendingPathComponent(account.id.uuidString.lowercased(), isDirectory: true)
        try FileManager.default.createDirectory(at: accountRoot, withIntermediateDirectories: true)
        let calls = LockedTestValue<[String]>([])
        let shouldFail = LockedTestValue(true)

        let removeKeys: @Sendable (AccountUUID) async throws -> Void = { _ in
            calls.mutate { $0.append("keys") }
            if failurePoint == .keyRemoval, shouldFail.get() {
                shouldFail.set(false)
                throw InjectedFailure.step
            }
        }
        let removeFiles: @Sendable (AccountUUID) async throws -> Void = { _ in
            calls.mutate { $0.append("files") }
            if FileManager.default.fileExists(atPath: accountRoot.path) {
                try FileManager.default.removeItem(at: accountRoot)
            }
            if failurePoint == .fileRemoval, shouldFail.get() {
                shouldFail.set(false)
                throw InjectedFailure.step
            }
        }

        if failurePoint == .cataloguePersistence {
            await #expect(throws: AccountCatalogueError.self) {
                try await PendingLogoutCleanup.resume(
                    account: account,
                    expectedTelegramUserID: 8001,
                    catalogue: catalogue,
                    removeKeys: removeKeys,
                    removeFiles: removeFiles
                )
            }
            try FileManager.default.removeItem(at: catalogueURL)
            try savedCatalogue.write(to: catalogueURL)
        } else {
            await #expect(throws: InjectedFailure.self) {
                try await PendingLogoutCleanup.resume(
                    account: account,
                    expectedTelegramUserID: 8001,
                    catalogue: catalogue,
                    removeKeys: removeKeys,
                    removeFiles: removeFiles
                )
            }
        }

        let retained = await catalogue.allProfiles()
        #expect(retained.count == 1)
        #expect(retained[0].telegramUserID == 8001)
        #expect(retained[0].logoutCleanupPending == true)
        #expect(AccountRestorePlanner.profilesToRestore(
            authorized: retained,
            pending: retained,
            pendingWithStoredDatabase: [account]
        ).isEmpty)

        try await PendingLogoutCleanup.resume(
            account: account,
            expectedTelegramUserID: 8001,
            catalogue: catalogue,
            removeKeys: removeKeys,
            removeFiles: removeFiles
        )
        #expect(await catalogue.allProfiles().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: accountRoot.path))
        switch failurePoint {
        case .keyRemoval:
            #expect(calls.get() == ["keys", "keys", "files"])
        case .fileRemoval, .cataloguePersistence:
            #expect(calls.get() == ["keys", "files", "keys", "files"])
        }
    }
}

@MainActor @Test func tdlibJSONDocumentDecodesOffMainActorWithoutChangingFields() async throws {
    let data = Data(#"{"@type":"updateMessageSendSucceeded","@client_id":17,"message":{"id":42,"content":{"@type":"messageText","text":{"text":"hello 😀"}}}}"#.utf8)
    let document = try await TDLibJSONDocument.decodeOffMainActor(data)
    #expect(!document.wasDecodedOnMainThread)
    #expect(document.object["@type"] as? String == "updateMessageSendSucceeded")
    #expect((document.object["message"] as? [String: Any])?["id"] as? Int == 42)
    let content = ((document.object["message"] as? [String: Any])?["content"] as? [String: Any])
    #expect(content?["@type"] as? String == "messageText")
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

@Test func sendIntentDispatchStaysOnAccountAAfterSelectionSwitchesToB() {
    let accountA = AccountUUID()
    let accountB = AccountUUID()
    let barrier = PrivacyDispatchBarrier()
    let intent = SendIntent(
        account: accountA,
        expectedTelegramUserID: 101,
        runtimeGeneration: RuntimeGeneration(4),
        conversation: ConversationKey(account: accountA, chatID: 9001, topic: .forum(topicID: 7)),
        replyToMessageID: 42,
        text: "captured for A",
        privacyEpoch: barrier.currentEpoch()
    )

    // The UI may change while a send is queued. The dispatch authority is the
    // captured runtime identity, not the subsequently selected account.
    var selectedAccount = accountA
    selectedAccount = accountB
    var sentAccounts: [AccountUUID] = []
    let accepted = barrier.dispatch(
        intent,
        currentAccount: accountA,
        currentTelegramUserID: 101,
        currentGeneration: RuntimeGeneration(4)
    ) {
        sentAccounts.append(intent.account)
    }

    #expect(selectedAccount == accountB)
    #expect(accepted)
    #expect(sentAccounts == [accountA])
    #expect(intent.conversation.account == accountA)
    #expect(intent.conversation.chatID == 9001)
    #expect(intent.conversation.topic == .forum(topicID: 7))
    #expect(intent.replyToMessageID == 42)
}

@Test func photoSendRevalidatesLiveTargetAfterAsyncStaging() {
    let account = AccountUUID()
    let intent = SendIntent(
        account: account,
        expectedTelegramUserID: 101,
        runtimeGeneration: RuntimeGeneration(4),
        conversation: ConversationKey(account: account, chatID: 9001, topic: .forum(topicID: 7)),
        sendAsUserID: 101,
        text: "caption",
        privacyEpoch: 12
    )
    let permission = ChatSendPermission(canSendBasicMessages: true, isChannel: false, defaultSenderTelegramUserID: 101)
    func allows(
        userID: Int64? = 101,
        generation: RuntimeGeneration = RuntimeGeneration(4),
        registered: Bool = true,
        ready: Bool = true,
        unlocked: Bool = true,
        epoch: UInt64 = 12,
        currentPermission: ChatSendPermission? = permission
    ) -> Bool {
        PhotoSendDispatchGuard.allows(
            intent,
            currentAccount: account,
            currentTelegramUserID: userID,
            currentGeneration: generation,
            runtimeIsRegistered: registered,
            authorizationReady: ready,
            privacyUnlocked: unlocked,
            currentPrivacyEpoch: epoch,
            permission: currentPermission
        )
    }

    #expect(allows())
    #expect(!allows(currentPermission: ChatSendPermission(canSendBasicMessages: false, isChannel: false, defaultSenderTelegramUserID: 101)))
    #expect(!allows(currentPermission: nil))
    #expect(!allows(userID: 202))
    #expect(!allows(generation: RuntimeGeneration(5)))
    #expect(!allows(registered: false))
    #expect(!allows(ready: false))
    #expect(!allows(unlocked: false))
    #expect(!allows(epoch: 13))
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

@Test func privacyBarrierRejectsQueuedAuthenticationAfterLockAndUnlock() throws {
    let account = AccountUUID()
    let otherAccount = AccountUUID()
    let generation = RuntimeGeneration(3)
    let barrier = PrivacyDispatchBarrier()
    let queuedEpoch = barrier.currentEpoch()
    var dispatched = 0

    #expect(barrier.dispatchAuthenticationCommand(
        account: account,
        runtimeGeneration: generation,
        privacyEpoch: queuedEpoch,
        currentAccount: account,
        currentGeneration: generation
    ) { dispatched += 1 })
    #expect(!barrier.dispatchAuthenticationCommand(
        account: account,
        runtimeGeneration: generation,
        privacyEpoch: queuedEpoch,
        currentAccount: otherAccount,
        currentGeneration: generation
    ) { dispatched += 1 })
    #expect(!barrier.dispatchAuthenticationCommand(
        account: account,
        runtimeGeneration: generation,
        privacyEpoch: queuedEpoch,
        currentAccount: account,
        currentGeneration: RuntimeGeneration(4)
    ) { dispatched += 1 })

    _ = barrier.setLocked(true)
    _ = barrier.setLocked(false)
    #expect(!barrier.dispatchAuthenticationCommand(
        account: account,
        runtimeGeneration: generation,
        privacyEpoch: queuedEpoch,
        currentAccount: account,
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

@Test func notificationPermissionIsRequestedOnceAcrossAccountStartup() {
    var gate = NotificationAuthorizationRequestGate()
    let first = gate.claimRequest()
    let second = gate.claimRequest()
    let third = gate.claimRequest()
    #expect(first)
    #expect(!second)
    #expect(!third)
}

@Test func keychainReadsRunOutsideTheMainThread() async throws {
    let executionContext = try await SecretsStore.performKeychainOperation {
        (Thread.isMainThread, SecretsStore.isExecutingOnKeychainReadQueue)
    }
    #expect(!executionContext.0)
    #expect(executionContext.1)
}

@Test func apiHashReadTimeoutRetriesJoinOneLookupAndCacheItsLateResult() async throws {
    let readiness = TelegramAPIHashReadiness()
    let gate = AsyncStringGate()
    let loadCount = LockedTestValue(0)

    let first = Task {
        try await readiness.value(timeout: 0.04) {
            loadCount.mutate { $0 += 1 }
            return await gate.wait()
        }
    }
    do {
        _ = try await first.value
        Issue.record("The first waiter should time out while the Keychain lookup is stalled")
    } catch TelegramAPIHashReadinessError.timedOut {
        #expect(true)
    }

    let retry = Task {
        try await readiness.value(timeout: 2) {
            loadCount.mutate { $0 += 1 }
            return "duplicate lookup"
        }
    }
    try await Task.sleep(for: .milliseconds(30))
    await gate.open("late-value")
    #expect(try await retry.value == "late-value")
    #expect(loadCount.get() == 1)

    #expect(try await readiness.value {
        loadCount.mutate { $0 += 1 }
        return "unexpected second lookup"
    } == "late-value")
    #expect(loadCount.get() == 1)

    readiness.invalidate()
    #expect(try await readiness.value {
        loadCount.mutate { $0 += 1 }
        return "replacement-value"
    } == "replacement-value")
    #expect(loadCount.get() == 2)
}

@Test func userAuthorizedAPIHashSupersedesStalledNoninteractiveLookup() async throws {
    let readiness = TelegramAPIHashReadiness()
    let gate = AsyncStringGate()
    let lookupStarted = LockedTestValue(false)
    let staleWaiter = Task {
        try await readiness.value(timeout: 2) {
            lookupStarted.set(true)
            return await gate.wait()
        }
    }

    #expect(await waitForTrue(lookupStarted, timeout: .seconds(1)))
    readiness.acceptVerifiedValue("synthetic-authorized-value")
    do {
        _ = try await staleWaiter.value
        Issue.record("The superseded noninteractive waiter should be invalidated")
    } catch TelegramAPIHashReadinessError.invalidated {
        #expect(true)
    }
    #expect(try await readiness.value { "unexpected replacement read" } == "synthetic-authorized-value")

    await gate.open("late stale value")
    #expect(try await readiness.value { "unexpected third read" } == "synthetic-authorized-value")
}

@Test func replacingAPIHashDiscardsOldInFlightLookupBeforeStartingProfiles() async throws {
    let readiness = TelegramAPIHashReadiness()
    let oldGate = AsyncStringGate()
    let loadCount = LockedTestValue(0)
    let oldWaiter = Task {
        try await readiness.value(timeout: 2) {
            loadCount.mutate { $0 += 1 }
            return await oldGate.wait()
        }
    }
    #expect(await waitForCount(loadCount, atLeast: 1, timeout: .seconds(2)))

    readiness.beginReplacement()
    do {
        _ = try await oldWaiter.value
        Issue.record("A waiter for the previous API hash must be invalidated")
    } catch TelegramAPIHashReadinessError.invalidated {
        #expect(true)
    }

    let freshWaiter = Task {
        try await readiness.value(timeout: 2) {
            loadCount.mutate { $0 += 1 }
            return "current-api-hash"
        }
    }
    await oldGate.open("stale-api-hash")
    try await Task.sleep(for: .milliseconds(30))
    #expect(loadCount.get() == 1)
    readiness.finishReplacement()
    #expect(try await freshWaiter.value == "current-api-hash")
    #expect(loadCount.get() == 2)
    #expect(try await readiness.value { "unexpected-third-lookup" } == "current-api-hash")
    #expect(loadCount.get() == 2)
}

@Test func blockedKeychainOperationDoesNotBlockSwiftCooperativeTasks() async throws {
    let keychainEntered = LockedTestValue(false)
    let releaseKeychain = DispatchSemaphore(value: 0)
    let blockedOperation = Task {
        try await SecretsStore.performKeychainOperation {
            keychainEntered.set(true)
            releaseKeychain.wait()
            return true
        }
    }
    defer { releaseKeychain.signal() }
    let didEnterKeychain = await waitForTrue(keychainEntered, timeout: .seconds(2))
    #expect(didEnterKeychain)

    let unrelatedTaskCompleted = LockedTestValue(false)
    let unrelatedTask = Task.detached {
        unrelatedTaskCompleted.set(true)
    }
    let didCompleteUnrelatedTask = await waitForTrue(unrelatedTaskCompleted, timeout: .seconds(1))
    #expect(didCompleteUnrelatedTask)
    releaseKeychain.signal()
    #expect(try await blockedOperation.value)
    await unrelatedTask.value
}

@Test func injectedKeychainReadFailurePropagatesWithoutFallback() async {
    await #expect(throws: SecretsStoreError.keychain(errSecInteractionNotAllowed)) {
        try await SecretsStore.performKeychainOperation { () throws -> String in
            throw SecretsStoreError.keychain(errSecInteractionNotAllowed)
        }
    }
}

@Test func stalledKeychainOperationDoesNotBlockOtherAccountsAndRemainsBounded() async throws {
    let firstEntered = LockedTestValue(false)
    let secondEntered = LockedTestValue(false)
    let thirdEntered = LockedTestValue(false)
    let releaseFirst = DispatchSemaphore(value: 0)
    let releaseSecond = DispatchSemaphore(value: 0)
    defer {
        releaseFirst.signal()
        releaseSecond.signal()
    }

    let first = Task {
        try await SecretsStore.performKeychainOperation {
            firstEntered.set(true)
            releaseFirst.wait()
            return 1
        }
    }
    #expect(await waitForTrue(firstEntered, timeout: .seconds(2)))

    let second = Task {
        try await SecretsStore.performKeychainOperation {
            secondEntered.set(true)
            releaseSecond.wait()
            return 2
        }
    }
    #expect(await waitForTrue(secondEntered, timeout: .seconds(2)), "The second account must proceed while the first Keychain call is stalled")

    let third = Task {
        try await SecretsStore.performKeychainOperation {
            thirdEntered.set(true)
            return 3
        }
    }
    try await Task.sleep(for: .milliseconds(100))
    #expect(!thirdEntered.get(), "Keychain blocking work must stay within its two-operation bound")

    releaseFirst.signal()
    #expect(try await first.value == 1)
    #expect(await waitForTrue(thirdEntered, timeout: .seconds(2)), "A queued account must advance when one bounded slot becomes free")
    releaseSecond.signal()
    #expect(try await second.value == 2)
    #expect(try await third.value == 3)
}

@Test func oneProfileStorageKeychainFailurePreservesItsDataAndDoesNotBlockOtherProfiles() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let scheduler = RuntimeStartupScheduler(parallelism: 2)
    let failedAccount = AccountUUID()
    let failedPaths = try AccountStoragePaths(rootURL: root, account: failedAccount)
    let databaseMarker = failedPaths.database.appendingPathComponent("existing.db")
    let draftMarker = failedPaths.appState.appendingPathComponent("drafts.aesgcm")
    try Data("database remains".utf8).write(to: databaseMarker)
    try Data("drafts remain".utf8).write(to: draftMarker)
    let failedBackend = FakeKeychainItemBackend(readFailure: errSecInteractionNotAllowed)

    let accounts = [failedAccount] + (0..<19).map { _ in AccountUUID() }
    let tasks = accounts.map { account in
        Task {
            await scheduler.withPermit {
                let backend: FakeKeychainItemBackend
                if account == failedAccount {
                    backend = failedBackend
                } else {
                    let accountName = account.id.uuidString.lowercased()
                    backend = FakeKeychainItemBackend(values: [
                        FakeKeychainCoordinate(account: accountName, service: "org.affpapa.netelegram.database-key"): Data(repeating: 1, count: 32),
                        FakeKeychainCoordinate(account: accountName, service: "org.affpapa.netelegram.app-state-key"): Data(repeating: 2, count: 32),
                    ])
                }
                do {
                    _ = try await SecretsStore.performKeychainOperation {
                        try ProfileStoragePreparer.prepare(
                            account: account,
                            rootURL: root,
                            secrets: SecretsStore(backend: backend)
                        )
                    }
                    return true
                } catch {
                    return false
                }
            }
        }
    }

    var successes: [Bool] = []
    for task in tasks { successes.append(await task.value) }
    #expect(successes.filter { $0 }.count == 19)
    #expect(!successes[0])
    #expect(try Data(contentsOf: databaseMarker) == Data("database remains".utf8))
    #expect(try Data(contentsOf: draftMarker) == Data("drafts remain".utf8))
    #expect(failedBackend.operationCounts.adds == 0)
    #expect(await scheduler.activeStarts() == 0)
    #expect(await scheduler.queuedStarts() == 0)
}

@Test func oneStalledProfileKeychainPreparationDoesNotBlockTheOtherNineteen() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let scheduler = RuntimeStartupScheduler(parallelism: 2)
    let accounts = (0..<20).map { _ in AccountUUID() }
    let blockedEntered = LockedTestValue(false)
    let blockedCompleted = LockedTestValue(false)
    let completedProfiles = LockedTestValue(0)
    let releaseBlockedKeychain = DispatchSemaphore(value: 0)
    defer { releaseBlockedKeychain.signal() }

    let blockedBackend = FakeKeychainItemBackend()
    let blockedProfile = Task {
        await scheduler.withPermit {
            try? await SecretsStore.performKeychainOperation {
                blockedEntered.set(true)
                releaseBlockedKeychain.wait()
                _ = try ProfileStoragePreparer.prepare(
                    account: accounts[0],
                    rootURL: root,
                    secrets: SecretsStore(backend: blockedBackend)
                )
            }
            blockedCompleted.set(true)
        }
    }

    #expect(await waitForTrue(blockedEntered, timeout: .seconds(2)))

    let otherProfiles = accounts.dropFirst().map { account in
        Task {
            await scheduler.withPermit {
                let accountName = account.id.uuidString.lowercased()
                let backend = FakeKeychainItemBackend(values: [
                    FakeKeychainCoordinate(account: accountName, service: "org.affpapa.netelegram.database-key"): Data(repeating: 1, count: 32),
                    FakeKeychainCoordinate(account: accountName, service: "org.affpapa.netelegram.app-state-key"): Data(repeating: 2, count: 32),
                ])
                do {
                    _ = try await SecretsStore.performKeychainOperation {
                        try ProfileStoragePreparer.prepare(
                            account: account,
                            rootURL: root,
                            secrets: SecretsStore(backend: backend)
                        )
                    }
                    completedProfiles.mutate { $0 += 1 }
                } catch {
                    Issue.record("An unrelated profile failed while one Keychain preparation was stalled: \(error)")
                }
            }
        }
    }

    #expect(
        await waitForCount(completedProfiles, atLeast: 19, timeout: .seconds(5)),
        "A single stalled profile must not retain the only path for the other 19 profiles"
    )
    #expect(!blockedCompleted.get(), "The injected Keychain stall must still be active during the assertion")
    #expect(await scheduler.activeStarts() == 1)

    releaseBlockedKeychain.signal()
    await blockedProfile.value
    for task in otherProfiles { await task.value }

    #expect(blockedCompleted.get())
    #expect(completedProfiles.get() == 19)
    #expect(await scheduler.activeStarts() == 0)
    #expect(await scheduler.queuedStarts() == 0)
}

@MainActor
@Test func restorePlannerAndStartupRegistryDeduplicateWhileOneKeychainPreparationStalls() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let profiles = (1...20).map { index in
        AccountProfile(
            id: AccountUUID(UUID(uuidString: String(format: "42000000-0000-0000-0000-%012d", index))!),
            telegramUserID: Int64(42_000 + index)
        )
    }
    let candidates = AccountRestorePlanner.profilesToRestore(
        authorized: profiles,
        pending: [],
        pendingWithStoredDatabase: []
    )
    let scheduler = RuntimeStartupScheduler(parallelism: 2)
    let startupTasks = AccountStartupTaskRegistry()
    let beginPreparation = AsyncTestGate()
    let stalledAccount = profiles[0].id
    let failedAccount = profiles[1].id
    let stalledKeychainEntered = LockedTestValue(false)
    let releaseStalledKeychain = DispatchSemaphore(value: 0)
    defer { releaseStalledKeychain.signal() }
    let preparedAccounts = LockedTestValue<Set<AccountUUID>>([])
    let preparedCount = LockedTestValue(0)
    let failedAccounts = LockedTestValue<Set<AccountUUID>>([])

    let failedPaths = try AccountStoragePaths(rootURL: root, account: failedAccount)
    let databaseMarker = failedPaths.database.appendingPathComponent("existing.db")
    let draftMarker = failedPaths.appState.appendingPathComponent("drafts.aesgcm")
    try Data("preserve database".utf8).write(to: databaseMarker)
    try Data("preserve draft".utf8).write(to: draftMarker)

    var tasksByAccount: [AccountUUID: Task<Void, Never>] = [:]
    let firstPass = AccountRestorePlanner.enqueueStartupProfiles(
        candidates: candidates,
        running: [],
        starting: startupTasks.startingAccounts
    ) { profile in
        let account = profile.id
        let accountName = account.id.uuidString.lowercased()
        let backend = FakeKeychainItemBackend(
            values: [
                FakeKeychainCoordinate(account: accountName, service: "org.affpapa.netelegram.database-key"): Data(repeating: 1, count: 32),
                FakeKeychainCoordinate(account: accountName, service: "org.affpapa.netelegram.app-state-key"): Data(repeating: 2, count: 32),
            ],
            readFailure: account == failedAccount ? errSecInteractionNotAllowed : nil
        )
        let task = startupTasks.start(
            account: account,
            scheduler: scheduler,
            operation: {
                await beginPreparation.wait()
                try await SecretsStore.performKeychainOperation {
                    if account == stalledAccount {
                        stalledKeychainEntered.set(true)
                        releaseStalledKeychain.wait()
                    }
                    _ = try ProfileStoragePreparer.prepare(
                        account: account,
                        rootURL: root,
                        secrets: SecretsStore(backend: backend)
                    )
                }
                preparedAccounts.mutate { $0.insert(account) }
                preparedCount.mutate { $0 += 1 }
            },
            onCompletion: { result in
                if case .failure = result { failedAccounts.mutate { $0.insert(account) } }
            }
        )
        tasksByAccount[account] = task
        return true
    }

    #expect(firstPass.queued == profiles.map(\.id))
    #expect(firstPass.rejected.isEmpty)
    #expect(startupTasks.startingAccounts == Set(profiles.map(\.id)))

    // A second restore pass must observe registered in-flight starts and must
    // not create another database preparation/owner for any of those profiles.
    var duplicateEnqueueCalls = 0
    let secondPass = AccountRestorePlanner.enqueueStartupProfiles(
        candidates: candidates,
        running: [],
        starting: startupTasks.startingAccounts
    ) { _ in
        duplicateEnqueueCalls += 1
        return false
    }
    #expect(secondPass.queued.isEmpty)
    #expect(secondPass.rejected.isEmpty)
    #expect(duplicateEnqueueCalls == 0)
    #expect(tasksByAccount.count == 20)

    await beginPreparation.open()
    #expect(await waitForTrue(stalledKeychainEntered, timeout: .seconds(2)))
    #expect(await waitForCount(preparedCount, atLeast: 18, timeout: .seconds(5)))
    #expect(failedAccounts.get() == [failedAccount])
    #expect(preparedAccounts.get().count == 18)
    #expect(startupTasks.startingAccounts == [stalledAccount])

    releaseStalledKeychain.signal()
    for task in tasksByAccount.values { await task.value }

    #expect(preparedAccounts.get().count == 19)
    #expect(failedAccounts.get() == [failedAccount])
    #expect(try Data(contentsOf: databaseMarker) == Data("preserve database".utf8))
    #expect(try Data(contentsOf: draftMarker) == Data("preserve draft".utf8))
    #expect(startupTasks.startingAccounts.isEmpty)
    #expect(await scheduler.activeStarts() == 0)
    #expect(await scheduler.queuedStarts() == 0)
}

@Test func quittingInvalidatesAProfileRestoreThatMayResumeLate() {
    var gate = ProfileRestoreGenerationGate()
    let firstRestore = gate.begin()
    #expect(gate.isCurrent(firstRestore))
    gate.invalidate()
    #expect(!gate.isCurrent(firstRestore))
    let retry = gate.begin()
    #expect(gate.isCurrent(retry))
    #expect(!gate.isCurrent(firstRestore))
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

@Test func conversationHistoryRequestsRejectStaleRuntimeAndOutOfOrderResponses() {
    let first = AccountUUID()
    let second = AccountUUID()
    let conversation = ConversationKey(account: first, chatID: 77, topic: .forum(topicID: 12))
    let old = ConversationHistoryRequestContext(
        conversation: conversation,
        runtimeGeneration: RuntimeGeneration(4),
        requestGeneration: 8
    )
    #expect(old.acceptsResponse(from: first, runtimeGeneration: RuntimeGeneration(4), requestGeneration: 8, isLocked: false))
    #expect(!old.acceptsResponse(from: first, runtimeGeneration: RuntimeGeneration(5), requestGeneration: 8, isLocked: false))
    #expect(!old.acceptsResponse(from: first, runtimeGeneration: RuntimeGeneration(4), requestGeneration: 9, isLocked: false))
    #expect(!old.acceptsResponse(from: second, runtimeGeneration: RuntimeGeneration(4), requestGeneration: 8, isLocked: false))
    #expect(!old.acceptsResponse(from: first, runtimeGeneration: RuntimeGeneration(4), requestGeneration: 8, isLocked: true))

    var pending = ConversationHistoryRequestRegistry()
    pending.register(old, for: "history-old")
    pending.register(
        ConversationHistoryRequestContext(conversation: conversation, runtimeGeneration: RuntimeGeneration(4), requestGeneration: 9),
        for: "history-new"
    )
    pending.register(
        ConversationHistoryRequestContext(conversation: ConversationKey(account: second, chatID: 77), runtimeGeneration: RuntimeGeneration(1), requestGeneration: 1),
        for: "history-other"
    )
    let removed = pending.remove(account: first, runtimeGeneration: RuntimeGeneration(4))
    let oldRequest = pending.take(for: "history-old")
    let newRequest = pending.take(for: "history-new")
    let otherRequest = pending.take(for: "history-other")
    #expect(removed == 2)
    #expect(oldRequest == nil)
    #expect(newRequest == nil)
    #expect(otherRequest?.conversation.account == second)
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

@Test func accountSearchResultsAndPendingRequestsAreScopedToRuntimeGeneration() {
    let first = AccountUUID()
    let second = AccountUUID()
    let oldGeneration = RuntimeGeneration(1)
    let newGeneration = RuntimeGeneration(2)
    let oldContext = AccountSearchRequestContext(account: first, runtimeGeneration: oldGeneration, searchGeneration: 9)
    #expect(oldContext.acceptsResponse(from: first, runtimeGeneration: oldGeneration, searchGeneration: 9, isLocked: false))
    #expect(!oldContext.acceptsResponse(from: first, runtimeGeneration: newGeneration, searchGeneration: 9, isLocked: false))
    #expect(!oldContext.acceptsResponse(from: first, runtimeGeneration: oldGeneration, searchGeneration: 10, isLocked: false))
    #expect(!oldContext.acceptsResponse(from: first, runtimeGeneration: oldGeneration, searchGeneration: 9, isLocked: true))

    var pending = AccountSearchRequestRegistry()
    pending.register(oldContext, for: "search-old")
    pending.register(AccountSearchRequestContext(account: first, runtimeGeneration: newGeneration, searchGeneration: 9), for: "search-new")
    pending.register(AccountSearchRequestContext(account: second, runtimeGeneration: RuntimeGeneration(1), searchGeneration: 9), for: "search-other")
    let removedOld = pending.remove(account: first, runtimeGeneration: oldGeneration)
    let staleRequest = pending.take(for: "search-old")
    let currentRequest = pending.take(for: "search-new")
    let otherRequest = pending.take(for: "search-other")
    #expect(removedOld == 1)
    #expect(staleRequest == nil)
    #expect(currentRequest?.runtimeGeneration == newGeneration)
    #expect(otherRequest?.account == second)
    #expect(pending.isEmpty)

    var results = AccountSearchResults()
    let firstResult = AccountSearchResult(account: first, conversation: ConversationKey(account: first, chatID: 5), title: "Чат", excerpt: "A")
    let secondResult = AccountSearchResult(account: second, conversation: ConversationKey(account: second, chatID: 5), title: "Чат", excerpt: "B")
    let firstAccepted = results.append(firstResult)
    let secondAccepted = results.append(secondResult)
    results.removeAll(for: first)
    #expect(firstAccepted)
    #expect(secondAccepted)
    #expect(results.values.map(\.account) == [second])
    let firstReaccepted = results.append(firstResult)
    #expect(firstReaccepted)
    #expect(results.values.map(\.account) == [second, first])
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

@Test func atomicPrivateReplacementPreservesPriorFileUntilPermissionSetupSucceeds() throws {
    enum InjectedFailure: Error { case permissionUpdate }

    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    let destination = root.appendingPathComponent("drafts.aesgcm")
    let oldCiphertext = Data("old-ciphertext".utf8)
    let newCiphertext = Data("new-ciphertext".utf8)
    try oldCiphertext.write(to: destination)

    #expect(throws: InjectedFailure.self) {
        try AtomicPrivateFile.replace(newCiphertext, at: destination, prepareStagingFile: { _ in
            throw InjectedFailure.permissionUpdate
        })
    }
    #expect(try Data(contentsOf: destination) == oldCiphertext)
    #expect(try FileManager.default.contentsOfDirectory(atPath: root.path) == ["drafts.aesgcm"])

    try AtomicPrivateFile.replace(newCiphertext, at: destination)
    #expect(try Data(contentsOf: destination) == newCiphertext)
    let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
    #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
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

@Test func encryptedDraftStoreKeepsLastDurableCopyWhenDiskWriteFails() throws {
    enum InjectedFailure: Error { case diskFull }

    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let account = AccountUUID()
    let key = Data(repeating: 0xA8, count: 32)
    let conversation = ConversationKey(account: account, chatID: 78)
    let healthyStore = try EncryptedDraftStore(account: account, stateDirectory: root, key: key)
    try healthyStore.save([conversation: "last durable copy"])
    let oldCiphertext = try Data(contentsOf: root.appendingPathComponent("drafts.aesgcm"))

    let failingStore = try EncryptedDraftStore(
        account: account,
        stateDirectory: root,
        key: key,
        replaceFile: { _, _ in throw InjectedFailure.diskFull }
    )
    #expect(throws: EncryptedDraftStoreError.persistence) {
        try failingStore.save([conversation: "new dirty copy"])
    }
    #expect(try Data(contentsOf: root.appendingPathComponent("drafts.aesgcm")) == oldCiphertext)
    #expect(try healthyStore.load() == [conversation: "last durable copy"])
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

private final class DeterministicPhotoPreviewCache: PhotoPreviewCache {
    private var values: [String: Data] = [:]

    func data(forKey key: String) -> Data? { values[key] }
    func insert(_ data: Data, forKey key: String, cost: Int) { values[key] = data }
    func remove(forKey key: String) { values.removeValue(forKey: key) }
}

@Test func photoPipelineReportsDecodeFailureAndReleasesSlotForRetry() async {
    let account = AccountUUID()
    let decoderCalls = LockedTestValue(0)
    let failedToken = LockedTestValue<PhotoPreviewToken?>(nil)
    let failedCallbacks = LockedTestValue(0)
    let successfulCallbacks = LockedTestValue(0)
    let pipeline = PhotoPipeline(
        maxConcurrentDecodes: 1,
        maxQueuedDecodes: 0,
        decoder: { _, _ in
            let call = decoderCalls.get() + 1
            decoderCalls.set(call)
            return call == 1 ? nil : Data([0x42])
        }
    )
    let url = URL(fileURLWithPath: "/unused-by-injected-decoder")
    let completion: @Sendable (PhotoPreviewToken, Data?) -> Void = { token, data in
        if let data {
            if data == Data([0x42]) { successfulCallbacks.set(successfulCallbacks.get() + 1) }
        } else {
            failedToken.set(token)
            failedCallbacks.set(failedCallbacks.get() + 1)
        }
    }

    let firstToken = pipeline.requestPreview(
        account: account,
        messageID: 91,
        fileID: 12,
        fileURL: url,
        maxPixelSize: 320,
        completion: completion
    )
    #expect(await waitForCount(failedCallbacks, atLeast: 1, timeout: .seconds(2)))
    #expect(failedToken.get() == firstToken)
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(2))
    while pipeline.outstandingDecodeCount(for: account) != 0, clock.now < deadline {
        try? await Task.sleep(for: .milliseconds(1))
    }
    #expect(pipeline.outstandingDecodeCount(for: account) == 0)

    _ = pipeline.requestPreview(
        account: account,
        messageID: 91,
        fileID: 12,
        fileURL: url,
        maxPixelSize: 320,
        completion: completion
    )
    #expect(await waitForCount(successfulCallbacks, atLeast: 1, timeout: .seconds(2)))
    #expect(decoderCalls.get() == 2)
}

@Test func photoPipelinePurgesDeletedMessagePreviewWithoutEvictingOtherMessages() async {
    let account = AccountUUID()
    let decoderCalls = LockedTestValue(0)
    let completions = LockedTestValue(0)
    let pipeline = PhotoPipeline(
        maxConcurrentDecodes: 1,
        maxQueuedDecodes: 2,
        cache: DeterministicPhotoPreviewCache(),
        decoder: { _, _ in
            decoderCalls.set(decoderCalls.get() + 1)
            return Data([0x31])
        }
    )
    let url = URL(fileURLWithPath: "/unused-by-injected-decoder")
    let completion: @Sendable (PhotoPreviewToken, Data?) -> Void = { _, data in
        if data != nil { completions.set(completions.get() + 1) }
    }

    _ = pipeline.requestPreview(account: account, chatID: 7, messageID: 10, fileID: 1, fileURL: url, maxPixelSize: 64, completion: completion)
    #expect(await waitForCount(completions, atLeast: 1, timeout: .seconds(2)))
    #expect(decoderCalls.get() == 1, "The first message must be decoded once")
    _ = pipeline.requestPreview(account: account, chatID: 8, messageID: 10, fileID: 1, fileURL: url, maxPixelSize: 64, completion: completion)
    #expect(await waitForCount(completions, atLeast: 2, timeout: .seconds(2)))
    #expect(decoderCalls.get() == 2, "A different chat must have an independent preview cache entry")
    #expect(pipeline.hasCachedPreview(account: account, chatID: 7, messageID: 10, fileID: 1, fileURL: url, maxPixelSize: 64))
    #expect(pipeline.hasCachedPreview(account: account, chatID: 8, messageID: 10, fileID: 1, fileURL: url, maxPixelSize: 64))

    pipeline.removeCachedPreviews(for: account, chatID: 7, messageIDs: [10])
    #expect(!pipeline.hasCachedPreview(account: account, chatID: 7, messageID: 10, fileID: 1, fileURL: url, maxPixelSize: 64))
    #expect(pipeline.hasCachedPreview(account: account, chatID: 8, messageID: 10, fileID: 1, fileURL: url, maxPixelSize: 64), "Deleting chat 7 must preserve chat 8's cache entry")
    _ = pipeline.requestPreview(account: account, chatID: 7, messageID: 10, fileID: 1, fileURL: url, maxPixelSize: 64, completion: completion)
    #expect(await waitForCount(completions, atLeast: 3, timeout: .seconds(2)))
    #expect(decoderCalls.get() == 3, "Deleting one chat's message must re-decode only that chat's preview")
}

@Test func photoPipelineDeletionPreventsLateDecodeFromRestoringExpiredPreview() async {
    let account = AccountUUID()
    let decoderCalls = LockedTestValue(0)
    let firstDecodeStarted = LockedTestValue(false)
    let completedCallbacks = LockedTestValue(0)
    let releaseFirstDecode = DispatchSemaphore(value: 0)
    defer { releaseFirstDecode.signal() }
    let pipeline = PhotoPipeline(maxConcurrentDecodes: 1, maxQueuedDecodes: 1, decoder: { _, _ in
        let call = decoderCalls.get() + 1
        decoderCalls.set(call)
        if call == 1 {
            firstDecodeStarted.set(true)
            releaseFirstDecode.wait()
        }
        return Data([UInt8(call)])
    })
    let url = URL(fileURLWithPath: "/unused-by-injected-decoder")
    let completion: @Sendable (PhotoPreviewToken, Data?) -> Void = { _, data in
        if data != nil { completedCallbacks.set(completedCallbacks.get() + 1) }
    }

    _ = pipeline.requestPreview(account: account, messageID: 44, fileID: 8, fileURL: url, maxPixelSize: 64, completion: completion)
    #expect(await waitForTrue(firstDecodeStarted, timeout: .seconds(2)))
    pipeline.removeCachedPreviews(for: account, chatID: 0, messageIDs: [44])
    releaseFirstDecode.signal()

    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(2))
    while pipeline.outstandingDecodeCount(for: account) != 0, clock.now < deadline {
        try? await Task.sleep(for: .milliseconds(1))
    }
    #expect(pipeline.outstandingDecodeCount(for: account) == 0)
    #expect(completedCallbacks.get() == 0)

    _ = pipeline.requestPreview(account: account, messageID: 44, fileID: 8, fileURL: url, maxPixelSize: 64, completion: completion)
    #expect(await waitForCount(completedCallbacks, atLeast: 1, timeout: .seconds(2)))
    #expect(decoderCalls.get() == 2)
}

@Test func privacyLockInvalidatesInFlightPhotoDecodeAndAllowsFreshPreviewAfterUnlock() async {
    let account = AccountUUID()
    let decoderCalls = LockedTestValue(0)
    let firstDecodeStarted = LockedTestValue(false)
    let successfulCallbacks = LockedTestValue(0)
    let releaseFirstDecode = DispatchSemaphore(value: 0)
    defer { releaseFirstDecode.signal() }
    let pipeline = PhotoPipeline(maxConcurrentDecodes: 1, maxQueuedDecodes: 1, decoder: { _, _ in
        let call = decoderCalls.get() + 1
        decoderCalls.set(call)
        if call == 1 {
            firstDecodeStarted.set(true)
            releaseFirstDecode.wait()
        }
        return Data([UInt8(call)])
    })
    let url = URL(fileURLWithPath: "/unused-by-injected-decoder")
    let completion: @Sendable (PhotoPreviewToken, Data?) -> Void = { _, data in
        if data != nil { successfulCallbacks.set(successfulCallbacks.get() + 1) }
    }

    _ = pipeline.requestPreview(account: account, messageID: 77, fileID: 9, fileURL: url, maxPixelSize: 320, completion: completion)
    #expect(await waitForTrue(firstDecodeStarted, timeout: .seconds(2)))

    // This mirrors Privacy Lock's cache invalidation while ImageIO is still working.
    pipeline.cancelAllPreviews()
    pipeline.removeCachedPreviews(for: account)
    releaseFirstDecode.signal()

    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(2))
    while pipeline.outstandingDecodeCount(for: account) != 0, clock.now < deadline {
        try? await Task.sleep(for: .milliseconds(1))
    }
    #expect(pipeline.outstandingDecodeCount(for: account) == 0)
    #expect(successfulCallbacks.get() == 0)
    #expect(!pipeline.hasCachedPreview(account: account, chatID: 0, messageID: 77, fileID: 9, fileURL: url, maxPixelSize: 320))

    _ = pipeline.requestPreview(account: account, messageID: 77, fileID: 9, fileURL: url, maxPixelSize: 320, completion: completion)
    #expect(await waitForCount(successfulCallbacks, atLeast: 1, timeout: .seconds(2)))
    #expect(decoderCalls.get() == 2, "A fresh post-unlock request must decode and populate the preview again")
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

@Test func photoFileDownloadCapabilityFailsClosedAndPartialFilesStayUnopened() {
    let missingCapability: [[String: Any]] = [[
        "width": 320, "height": 240,
        "photo": ["id": 11, "local": ["path": "/tmp/partial-photo.jpg", "is_downloading_completed": false]],
    ]]
    let denied: [[String: Any]] = [[
        "width": 320, "height": 240,
        "photo": ["id": 12, "local": ["can_be_downloaded": false, "path": "", "is_downloading_completed": false]],
    ]]
    let allowed: [[String: Any]] = [[
        "width": 320, "height": 240,
        "photo": ["id": 13, "local": ["can_be_downloaded": true, "path": "", "is_downloading_completed": false]],
    ]]

    let missing = PhotoSizeCatalog.preview(from: missingCapability)
    #expect(missing?.canBeDownloaded == false)
    #expect(missing?.localPath == "/tmp/partial-photo.jpg")
    #expect(missing?.isDownloaded == false)
    #expect(PhotoSizeCatalog.preview(from: denied)?.canBeDownloaded == false)
    #expect(PhotoSizeCatalog.preview(from: allowed)?.canBeDownloaded == true)
}

@Test func photoCatalogPrefersAccessibleVariantsAndKeepsUnavailableFallback() {
    let sizes: [[String: Any]] = [
        ["width": 320, "height": 240, "photo": ["id": 21, "local": ["can_be_downloaded": true]]],
        ["width": 640, "height": 480, "photo": ["id": 22, "local": ["can_be_downloaded": true]]],
        ["width": 1280, "height": 960, "photo": ["id": 23, "local": ["can_be_downloaded": false]]],
    ]
    #expect(PhotoSizeCatalog.preview(from: sizes)?.fileID == 22)
    #expect(PhotoSizeCatalog.original(from: sizes)?.fileID == 22)

    let locallyAvailable: [[String: Any]] = sizes + [[
        "width": 2560,
        "height": 1920,
        "photo": ["id": 24, "local": [
            "can_be_downloaded": false,
            "path": "/tmp/already-downloaded-photo.jpg",
            "is_downloading_completed": true,
        ]],
    ]]
    #expect(PhotoSizeCatalog.preview(from: locallyAvailable)?.fileID == 24)
    #expect(PhotoSizeCatalog.original(from: locallyAvailable)?.fileID == 24)

    let unavailable = sizes.map { size -> [String: Any] in
        var copy = size
        var photo = copy["photo"] as! [String: Any]
        photo["local"] = ["can_be_downloaded": false]
        copy["photo"] = photo
        return copy
    }
    #expect(PhotoSizeCatalog.preview(from: unavailable)?.fileID == 23)
    #expect(PhotoSizeCatalog.original(from: unavailable)?.fileID == 23)
}

@Test func photoContentOpenIntentIsBoundToRuntimeAndPrivacyEpoch() {
    let account = AccountUUID()
    let otherAccount = AccountUUID()
    let generation = RuntimeGeneration(7)
    let barrier = PrivacyDispatchBarrier()
    let intent = PhotoContentOpenIntent(
        account: account,
        expectedTelegramUserID: 501,
        runtimeGeneration: generation,
        chatID: 90,
        messageID: 12,
        privacyEpoch: barrier.currentEpoch()
    )
    var opened: [[Int64]] = []

    #expect(intent.dispatch(
        through: barrier,
        currentAccount: account,
        currentTelegramUserID: 501,
        currentGeneration: generation
    ) { opened.append([intent.chatID, intent.messageID]) })
    #expect(!intent.dispatch(
        through: barrier,
        currentAccount: otherAccount,
        currentTelegramUserID: 501,
        currentGeneration: generation
    ) { opened.append([intent.chatID, intent.messageID]) })
    #expect(!intent.dispatch(
        through: barrier,
        currentAccount: account,
        currentTelegramUserID: 501,
        currentGeneration: RuntimeGeneration(8)
    ) { opened.append([intent.chatID, intent.messageID]) })
    _ = barrier.setLocked(true)
    #expect(!intent.dispatch(
        through: barrier,
        currentAccount: account,
        currentTelegramUserID: 501,
        currentGeneration: generation
    ) { opened.append([intent.chatID, intent.messageID]) })
    _ = barrier.setLocked(false)
    #expect(!intent.dispatch(
        through: barrier,
        currentAccount: account,
        currentTelegramUserID: 501,
        currentGeneration: generation
    ) { opened.append([intent.chatID, intent.messageID]) })
    #expect(opened == [[90, 12]])
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
    #expect(AccountReducer.reduce(
        current: .active(telegramUserID: 441),
        authorizationState: "authorizationStateFutureUnknown",
        telegramUserID: 441
    ) == .failed("Unsupported TDLib authorization state"))
    #expect(AuthorizationStep(tdlibType: "authorizationStateReady").uiAvailability == .nonInteractive)
}

@Test func authorizationRecoveryAllowsChangingPhoneOnlyFromCodeStep() {
    #expect(AuthorizationRecoveryPolicy.canChangePhoneNumber(
        from: "authorizationStateWaitCode", hasRuntime: true, isLocked: false, requestInFlight: false
    ))
    for state in [
        "authorizationStateWaitPhoneNumber",
        "authorizationStateWaitPassword",
        "authorizationStateWaitEmailAddress",
        "authorizationStateWaitEmailCode",
        "authorizationStateWaitRegistration",
        "authorizationStateWaitOtherDeviceConfirmation",
        "authorizationStateReady",
        "unknown",
    ] {
        #expect(!AuthorizationRecoveryPolicy.canChangePhoneNumber(
            from: state, hasRuntime: true, isLocked: false, requestInFlight: false
        ))
    }
    #expect(!AuthorizationRecoveryPolicy.canChangePhoneNumber(
        from: "authorizationStateWaitCode", hasRuntime: false, isLocked: false, requestInFlight: false
    ))
    #expect(!AuthorizationRecoveryPolicy.canChangePhoneNumber(
        from: "authorizationStateWaitCode", hasRuntime: true, isLocked: true, requestInFlight: false
    ))
    #expect(!AuthorizationRecoveryPolicy.canChangePhoneNumber(
        from: "authorizationStateWaitCode", hasRuntime: true, isLocked: false, requestInFlight: true
    ))
}

@Test func authorizationAnnouncementsAreStaticAndDeduplicatedByAccountGenerationAndStep() {
    #expect(AuthorizationStep(tdlibType: "authorizationStateWaitOtherDeviceConfirmation") == .qrConfirmation)
    #expect(AuthorizationAnnouncement.message(for: .qrConfirmation) == "Вход по QR: отсканируйте код в Telegram на телефоне для подтверждения.")
    let steps: [AuthorizationStep] = [
        .phoneNumber, .code, .password, .emailAddress, .emailCode, .registration, .qrConfirmation,
    ]
    let messages = steps.compactMap(AuthorizationAnnouncement.message(for:))
    #expect(messages.count == steps.count)
    #expect(AuthorizationAnnouncement.message(for: .parameters) == nil)
    #expect(AuthorizationAnnouncement.message(for: .premiumPurchase) == nil)
    #expect(AuthorizationAnnouncement.message(for: .unknown) == nil)
    #expect(messages.allSatisfy { !$0.isEmpty })

    let accountA = AccountUUID()
    let accountB = AccountUUID()
    let phoneStep = AuthorizationAnnouncementContext(
        account: accountA,
        generation: RuntimeGeneration(1),
        step: .phoneNumber
    )
    #expect(phoneStep.shouldAnnounce(after: nil))
    #expect(!phoneStep.shouldAnnounce(after: phoneStep))
    #expect(AuthorizationAnnouncementContext(account: accountA, generation: RuntimeGeneration(1), step: .code)
        .shouldAnnounce(after: phoneStep))
    #expect(AuthorizationAnnouncementContext(account: accountA, generation: RuntimeGeneration(2), step: .phoneNumber)
        .shouldAnnounce(after: phoneStep))
    #expect(AuthorizationAnnouncementContext(account: accountB, generation: RuntimeGeneration(1), step: .phoneNumber)
        .shouldAnnounce(after: phoneStep))
}

@Test func authenticationFailureAnnouncementsAreStaticAndLimitedToSubmittableSteps() {
    let cases: [(AuthorizationStep, String)] = [
        (.phoneNumber, "Номер не принят Telegram. Проверьте код страны и номер."),
        (.code, "Код не принят. Проверьте последнее сообщение с кодом и попробуйте снова."),
        (.password, "Пароль двухэтапной проверки не принят. Попробуйте снова."),
        (.emailAddress, "Адрес почты не принят. Проверьте его и попробуйте снова."),
        (.emailCode, "Код из письма не принят. Проверьте последнее письмо и попробуйте снова."),
        (.registration, "Не удалось завершить регистрацию. Проверьте имя и попробуйте снова."),
    ]
    for (step, expected) in cases {
        #expect(AuthenticationFailureAnnouncement.message(for: step) == expected)
    }
    #expect(AuthenticationFailureAnnouncement.message(for: .qrConfirmation) == "Не удалось запросить QR-код. Попробуйте вход по номеру телефона.")
    #expect(AuthenticationFailureAnnouncement.message(for: .ready) == nil)
    #expect(AuthenticationFailureAnnouncement.message(for: .unknown) == nil)
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

@Test func tdlibNotificationUpdateReplacesPushContentWithExactConversationRoute() throws {
    let account = AccountUUID()
    let update: [String: Any] = [
        "@type": "updateNotification",
        "notification_group_id": 7,
        "notification": [
            "id": 19,
            "date": 321,
            "is_silent": true,
            "type": [
                "@type": "notificationTypeNewMessage",
                "show_preview": true,
                "message": [
                    "id": 88,
                    "chat_id": -44,
                    "topic_id": ["@type": "messageTopicThread", "message_thread_id": 55],
                    "content": ["@type": "messageText", "text": ["text": "Обновлённый текст"]],
                ],
            ],
        ],
    ]

    let routed = try #require(TDLibNotificationRouter.routeUpdate(account: account, update: update))
    #expect(routed.groupID == 7)
    #expect(routed.notificationID == 19)
    #expect(routed.conversation == ConversationKey(account: account, chatID: -44, topic: .thread(messageThreadID: 55)))
    #expect(routed.messageID == 88)
    #expect(routed.preview == "Обновлённый текст")
    #expect(routed.isSilent)
}

@Test func tdlibNotificationUpdateDoesNotInventRouteForPartialPushOrWrongUpdateKind() {
    let account = AccountUUID()
    let partialPush: [String: Any] = [
        "@type": "updateNotification",
        "notification_group_id": 7,
        "notification": [
            "id": 19,
            "type": ["@type": "notificationTypeNewPushMessage"],
        ],
    ]
    #expect(TDLibNotificationRouter.isPendingPushReplacement(partialPush))
    #expect(TDLibNotificationRouter.routeUpdate(account: account, update: partialPush) == nil)
    #expect(!TDLibNotificationRouter.isPendingPushReplacement(["@type": "updateNotificationGroup"]))
    #expect(TDLibNotificationRouter.routeUpdate(account: account, update: ["@type": "updateNotificationGroup"]) == nil)
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
    let reconciled = TDLibNotificationRouter.presentation(for: routed, isPrivacyLocked: false, chatTitle: "Alice", isReconciliation: true)
    let unlocked = TDLibNotificationRouter.presentation(for: routed, isPrivacyLocked: false, chatTitle: "Alice")

    #expect(locked == TDLibNotificationPresentation(title: ProductIdentity.displayName, body: "Новое сообщение", playsSound: false))
    #expect(reconciled == TDLibNotificationPresentation(title: "Alice", body: "Sensitive message text", playsSound: false))
    #expect(!locked.title.contains("Private chat"))
    #expect(!locked.body.contains("Sensitive message text"))
    #expect(unlocked == TDLibNotificationPresentation(title: "Alice", body: "Sensitive message text", playsSound: true))
    #expect(routed.systemIdentifier == identifier)
    #expect(routed.conversation == ConversationKey(account: account, chatID: 44, topic: .main))
}

@Test func privacyLockRedactsCachedNotificationTextButKeepsExactRoute() throws {
    let account = AccountUUID()
    let raw: [String: Any] = [
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
                "content": ["@type": "messageText", "text": ["text": "Unique sensitive preview"]],
            ],
        ],
    ]
    let routed = try #require(TDLibNotificationRouter.route(
        account: account,
        groupID: 3,
        groupChatID: -44,
        notification: raw
    ))
    let lockedCache = routed.redactedForPrivacyLock()

    #expect(routed.preview == "Unique sensitive preview")
    #expect(lockedCache.preview == nil)
    #expect(!lockedCache.showsPreview)
    #expect(lockedCache.account == account)
    #expect(lockedCache.groupID == 3)
    #expect(lockedCache.notificationID == 9)
    #expect(lockedCache.conversation == ConversationKey(account: account, chatID: -44, topic: .forum(topicID: 12)))
    #expect(lockedCache.messageID == 77)
    #expect(lockedCache.systemIdentifier == routed.systemIdentifier)
    #expect(TDLibNotificationRouter.presentation(
        for: lockedCache,
        isPrivacyLocked: false,
        chatTitle: "Private topic",
        isReconciliation: true
    ).body == "Новое сообщение")
}

@Test func notificationUpdatesReceivedWhileLockedNeverCacheMessageText() throws {
    let account = AccountUUID()
    let update: [String: Any] = [
        "@type": "updateNotification",
        "notification_group_id": 7,
        "notification": [
            "id": 19,
            "type": [
                "@type": "notificationTypeNewMessage",
                "show_preview": true,
                "message": [
                    "id": 88,
                    "chat_id": -44,
                    "content": ["@type": "messageText", "text": ["text": "Locked arrival secret"]],
                ],
            ],
        ],
    ]
    let routed = try #require(TDLibNotificationRouter.routeUpdate(
        account: account,
        update: update,
        isPrivacyLocked: true
    ))

    #expect(routed.preview == nil)
    #expect(!routed.showsPreview)
    #expect(routed.conversation == ConversationKey(account: account, chatID: -44, topic: .main))
    #expect(routed.messageID == 88)
    #expect(TDLibNotificationRouter.presentation(
        for: routed,
        isPrivacyLocked: true,
        chatTitle: "Private chat",
        isReconciliation: true
    ).body == "Новое сообщение")
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

@Test func lockedNotificationHandoffClearsOnlyWhenItsMessageIsDeleted() {
    let account = AccountUUID()
    let notification = RoutedTDLibNotification(
        account: account,
        groupID: 1,
        notificationID: 2,
        conversation: ConversationKey(account: account, chatID: 55, topic: .forum(topicID: 8)),
        messageID: 77,
        date: 123,
        isSilent: true,
        showsPreview: false,
        preview: nil
    )
    var handoff = NotificationUnlockHandoff()
    handoff.stage(notification, runtimeGeneration: RuntimeGeneration(1), expectedTelegramUserID: 9)
    handoff.clear(account: account, chatID: 55, messageIDs: [78])
    #expect(handoff.pending?.notification == notification)
    handoff.clear(account: account, chatID: 55, messageIDs: [77])
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

@Test func searchResultNavigationKeepsForumTypeAnchorAndAccountIdentity() {
    let accountA = AccountUUID()
    let accountB = AccountUUID()
    let main = ConversationKey(account: accountA, chatID: 41)
    let forum = ConversationKey(account: accountA, chatID: 41, topic: .forum(topicID: 12))
    let thread = ConversationKey(account: accountA, chatID: 41, topic: .thread(messageThreadID: 17))
    let direct = ConversationKey(account: accountA, chatID: 41, topic: .directMessages(topicID: 23))
    let saved = ConversationKey(account: accountA, chatID: 41, topic: .savedMessages(topicID: 29))
    let sameChatInOtherAccount = ConversationKey(account: accountB, chatID: 41, topic: .forum(topicID: 12))

    let mainPlan = SearchResultNavigationPlan(conversation: main, messageID: 99)
    #expect(mainPlan.conversation == main)
    #expect(mainPlan.topicSelection == .main)
    #expect(mainPlan.historyAnchorMessageID == 99)
    #expect(SearchResultNavigationPlan(conversation: forum, messageID: 100).topicSelection == .forum(topicID: 12))
    #expect(SearchResultNavigationPlan(conversation: forum, messageID: 100).historyAnchorMessageID == 100)
    #expect(SearchResultNavigationPlan(conversation: thread, messageID: 101).topicSelection == .typed(.thread(messageThreadID: 17)))
    #expect(SearchResultNavigationPlan(conversation: direct, messageID: 102).topicSelection == .typed(.directMessages(topicID: 23)))
    #expect(SearchResultNavigationPlan(conversation: saved, messageID: nil).topicSelection == .typed(.savedMessages(topicID: 29)))
    #expect(SearchResultNavigationPlan(conversation: saved, messageID: nil).historyAnchorMessageID == nil)
    #expect(SearchResultNavigationPlan(conversation: forum, messageID: 100) != SearchResultNavigationPlan(
        conversation: sameChatInOtherAccount,
        messageID: 100
    ))
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

@Test func visibleReadCandidatesRequireIncomingVisiblePermittedMessageIDs() {
    let account = AccountUUID()
    let conversation = ConversationKey(account: account, chatID: 81, topic: .forum(topicID: 6))
    let registry = VisibleMessageReadRegistry()
    let candidates = [
        VisibleMessageReadCandidate(messageID: 10, isIncoming: true),
        VisibleMessageReadCandidate(messageID: 11, isIncoming: true),
        VisibleMessageReadCandidate(messageID: 12, isIncoming: false),
        VisibleMessageReadCandidate(messageID: 13, isIncoming: true, canBeViewed: false),
        VisibleMessageReadCandidate(messageID: 0, isIncoming: true),
        VisibleMessageReadCandidate(messageID: 10, isIncoming: true),
    ]

    #expect(registry.candidateIDs(
        messages: candidates,
        fullyVisibleMessageIDs: [10, 12, 13, 0],
        conversation: conversation,
        runtimeGeneration: RuntimeGeneration(2)
    ) == [10])
}

@Test func visibleReadRegistryDeduplicatesPendingAndSucceededRequestsAndReleasesFailures() {
    let account = AccountUUID()
    let conversation = ConversationKey(account: account, chatID: 82, topic: .thread(messageThreadID: 91))
    let generation = RuntimeGeneration(4)
    let candidates = [VisibleMessageReadCandidate(messageID: 20, isIncoming: true)]
    var registry = VisibleMessageReadRegistry()

    #expect(registry.begin(extra: "read-a", conversation: conversation, runtimeGeneration: generation, messageIDs: [20])?.messageIDs == [20])
    #expect(registry.candidateIDs(messages: candidates, fullyVisibleMessageIDs: [20], conversation: conversation, runtimeGeneration: generation).isEmpty)
    #expect(registry.resolve(extra: "read-a", account: account, runtimeGeneration: generation, succeeded: false)?.messageIDs == [20])
    #expect(registry.candidateIDs(messages: candidates, fullyVisibleMessageIDs: [20], conversation: conversation, runtimeGeneration: generation) == [20])

    #expect(registry.begin(extra: "read-b", conversation: conversation, runtimeGeneration: generation, messageIDs: [20])?.messageIDs == [20])
    #expect(registry.resolve(extra: "read-b", account: account, runtimeGeneration: generation, succeeded: true)?.messageIDs == [20])
    #expect(registry.candidateIDs(messages: candidates, fullyVisibleMessageIDs: [20], conversation: conversation, runtimeGeneration: generation).isEmpty)
}

@Test func visibleReadRegistrySeparatesAccountTopicAndRuntimeGenerationAndCanPrune() {
    let accountA = AccountUUID()
    let accountB = AccountUUID()
    let conversationA = ConversationKey(account: accountA, chatID: 83, topic: .forum(topicID: 1))
    let conversationB = ConversationKey(account: accountB, chatID: 83, topic: .forum(topicID: 1))
    let generation = RuntimeGeneration(8)
    var registry = VisibleMessageReadRegistry(maximumRetainedMessages: 1)

    #expect(registry.begin(extra: "read-a", conversation: conversationA, runtimeGeneration: generation, messageIDs: [30]) != nil)
    #expect(registry.resolve(extra: "read-a", account: accountB, runtimeGeneration: generation, succeeded: true) == nil)
    #expect(registry.candidateIDs(
        messages: [VisibleMessageReadCandidate(messageID: 30, isIncoming: true)],
        fullyVisibleMessageIDs: [30],
        conversation: conversationA,
        runtimeGeneration: generation
    ).isEmpty)
    #expect(registry.resolve(extra: "read-a", account: accountA, runtimeGeneration: generation, succeeded: true) != nil)
    #expect(registry.candidateIDs(
        messages: [VisibleMessageReadCandidate(messageID: 30, isIncoming: true)],
        fullyVisibleMessageIDs: [30],
        conversation: conversationA,
        runtimeGeneration: generation
    ).isEmpty)
    #expect(registry.candidateIDs(
        messages: [VisibleMessageReadCandidate(messageID: 30, isIncoming: true)],
        fullyVisibleMessageIDs: [30],
        conversation: conversationB,
        runtimeGeneration: RuntimeGeneration(9)
    ) == [30])
    registry.remove(account: accountA)
    #expect(registry.candidateIDs(
        messages: [VisibleMessageReadCandidate(messageID: 30, isIncoming: true)],
        fullyVisibleMessageIDs: [30],
        conversation: conversationA,
        runtimeGeneration: generation
    ) == [30])
}
