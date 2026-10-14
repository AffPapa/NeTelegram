/// Tracks whether a runtime's bounded chat-list snapshot is current. Privacy
/// lock clears presentation caches, so every account must request its snapshot
/// again when it is next selected after unlock.
public struct ChatListLoadState: Sendable, Equatable {
    public enum State: Sendable, Equatable {
        case needsLoad
        case loading
        case loaded
        case exhausted
        case failed
    }

    public private(set) var state: State = .needsLoad
    private var requestSerial: UInt64 = 0
    private var activeRequestID: UInt64?

    public init() {}

    /// Claims one request. A forced reload supersedes the previous loaded state.
    public mutating func beginLoad(reload: Bool = false) -> UInt64? {
        if reload { invalidate() }
        guard state == .needsLoad || state == .failed else { return nil }
        return beginRequest()
    }

    /// Claims another TDLib page only after the previous page request has
    /// completed successfully. Exhaustion is reported separately by TDLib 404.
    public mutating func beginNextPage() -> UInt64? {
        guard state == .loaded else { return nil }
        return beginRequest()
    }

    @discardableResult
    public mutating func completeLoad(requestID: UInt64) -> Bool {
        guard state == .loading, activeRequestID == requestID else { return false }
        activeRequestID = nil
        state = .loaded
        return true
    }

    @discardableResult
    public mutating func finishNoMoreChats(requestID: UInt64) -> Bool {
        guard state == .loading, activeRequestID == requestID else { return false }
        activeRequestID = nil
        state = .exhausted
        return true
    }

    @discardableResult
    public mutating func failLoad(requestID: UInt64) -> Bool {
        guard state == .loading, activeRequestID == requestID else { return false }
        activeRequestID = nil
        state = .failed
        return true
    }

    public mutating func invalidate() {
        activeRequestID = nil
        state = .needsLoad
    }

    private mutating func beginRequest() -> UInt64 {
        requestSerial &+= 1
        activeRequestID = requestSerial
        state = .loading
        return requestSerial
    }
}
