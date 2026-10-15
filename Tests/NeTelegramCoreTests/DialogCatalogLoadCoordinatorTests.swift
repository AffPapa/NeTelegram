import Testing
@testable import NeTelegramCore

@Test func dialogCatalogLoadsEveryMainAndArchivePageUntilTdlibEndMarker() {
    var catalog = DialogCatalogLoadCoordinator()

    var request = catalog.begin()
    #expect(request == .init(list: .main, requestID: 1, page: 1))
    #expect(catalog.state == .loading(list: .main, page: 1))

    request = catalog.finish(request!, outcome: .pageLoaded)
    #expect(request == .init(list: .main, requestID: 2, page: 2))
    #expect(catalog.completedPages == 1)

    request = catalog.finish(request!, outcome: .pageLoaded)
    #expect(request == .init(list: .main, requestID: 3, page: 3))
    request = catalog.finish(request!, outcome: .noMoreChats)
    #expect(request == .init(list: .archive, requestID: 1, page: 1))

    request = catalog.finish(request!, outcome: .pageLoaded)
    #expect(request == .init(list: .archive, requestID: 2, page: 2))
    request = catalog.finish(request!, outcome: .noMoreChats)

    #expect(request == nil)
    #expect(catalog.state == .complete)
    #expect(catalog.completedPages == 3)
}

@Test func dialogCatalogFailureStopsAutomaticDrainAndRetryResumesSameList() {
    var catalog = DialogCatalogLoadCoordinator()
    var request = catalog.begin()!
    request = catalog.finish(request, outcome: .pageLoaded)!
    #expect(request.list == .main && request.page == 2)

    #expect(catalog.finish(request, outcome: .failed) == nil)
    #expect(catalog.state == .failed(list: .main, page: 2))

    request = catalog.begin()!
    #expect(request.list == .main && request.page == 2)
    request = catalog.finish(request, outcome: .noMoreChats)!
    #expect(request.list == .archive && request.page == 1)
}

@Test func dialogCatalogRejectsOverlappingAndStaleCompletion() {
    var catalog = DialogCatalogLoadCoordinator()
    let request = catalog.begin()!
    #expect(catalog.begin() == nil)
    #expect(catalog.finish(.init(list: .main, requestID: request.requestID + 50, page: request.page), outcome: .pageLoaded) == nil)
    #expect(catalog.state == .loading(list: .main, page: 1))
}

@Test func dialogCatalogCanRestartAfterPrivacySnapshotInvalidatesAnInFlightPage() {
    var catalog = DialogCatalogLoadCoordinator()
    let staleRequest = catalog.begin()!

    catalog.invalidate()

    #expect(catalog.finish(staleRequest, outcome: .pageLoaded) == nil)
    #expect(catalog.state == .needsLoad)
    let replacement = catalog.begin()!
    #expect(replacement.list == .main && replacement.page == 1)
    #expect(catalog.finish(staleRequest, outcome: .noMoreChats) == nil)
    #expect(catalog.state == .loading(list: .main, page: 1))
}
