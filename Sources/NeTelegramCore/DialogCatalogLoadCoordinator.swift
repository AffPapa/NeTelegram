import Foundation

/// The conversation index is loaded in stable chunks, one TDLib chat list at a
/// time. A successful page does not mean the catalog is complete; only TDLib's
/// end-of-list response does.
public struct DialogCatalogLoadCoordinator: Sendable {
    public enum List: String, Sendable, Equatable {
        case main
        case archive
    }

    public struct Request: Sendable, Equatable {
        public let list: List
        public let requestID: UInt64
        public let page: Int
    }

    public enum Outcome: Sendable, Equatable {
        case pageLoaded
        case noMoreChats
        case failed
    }

    public enum State: Sendable, Equatable {
        case needsLoad
        case loading(list: List, page: Int)
        case failed(list: List, page: Int)
        case complete
    }

    private var main = ChatListLoadState()
    private var archive = ChatListLoadState()
    private var mainPages = 0
    private var archivePages = 0
    private var activeRequest: Request?

    public init() {}

    public var state: State {
        if let activeRequest {
            return .loading(list: activeRequest.list, page: activeRequest.page)
        }
        if main.state == .failed { return .failed(list: .main, page: mainPages + 1) }
        if archive.state == .failed { return .failed(list: .archive, page: archivePages + 1) }
        if main.state == .exhausted && archive.state == .exhausted { return .complete }
        return .needsLoad
    }

    public var completedPages: Int { mainPages + archivePages }

    /// Starts or retries the next sequential page. There is never more than
    /// one catalog request outstanding for this runtime.
    public mutating func begin() -> Request? {
        guard activeRequest == nil else { return nil }
        if main.state == .failed || main.state == .needsLoad || main.state == .loaded {
            if let id = main.state == .loaded ? main.beginNextPage() : main.beginLoad() {
                return activate(.main, requestID: id, page: mainPages + 1)
            }
        }
        if main.state == .exhausted,
           (archive.state == .failed || archive.state == .needsLoad || archive.state == .loaded) {
            if let id = archive.state == .loaded ? archive.beginNextPage() : archive.beginLoad() {
                return activate(.archive, requestID: id, page: archivePages + 1)
            }
        }
        return nil
    }

    /// Completes one request and immediately returns the next bounded request,
    /// if any. TDLib 404 ends a list; a short successful page does not.
    public mutating func finish(_ request: Request, outcome: Outcome) -> Request? {
        guard activeRequest == request else { return nil }
        activeRequest = nil
        switch (request.list, outcome) {
        case (.main, .pageLoaded):
            guard main.completeLoad(requestID: request.requestID) else { return nil }
            mainPages += 1
        case (.archive, .pageLoaded):
            guard archive.completeLoad(requestID: request.requestID) else { return nil }
            archivePages += 1
        case (.main, .noMoreChats):
            guard main.finishNoMoreChats(requestID: request.requestID) else { return nil }
        case (.archive, .noMoreChats):
            guard archive.finishNoMoreChats(requestID: request.requestID) else { return nil }
        case (.main, .failed):
            guard main.failLoad(requestID: request.requestID) else { return nil }
        case (.archive, .failed):
            guard archive.failLoad(requestID: request.requestID) else { return nil }
        }
        if outcome == .failed { return nil }
        return begin()
    }

    public mutating func invalidate() {
        activeRequest = nil
        main.invalidate()
        archive.invalidate()
        mainPages = 0
        archivePages = 0
    }

    private mutating func activate(_ list: List, requestID: UInt64, page: Int) -> Request {
        let request = Request(list: list, requestID: requestID, page: page)
        activeRequest = request
        return request
    }
}
