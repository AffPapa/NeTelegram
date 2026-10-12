/// Tracks whether a runtime's bounded chat-list snapshot is current. Privacy
/// lock clears presentation caches, so every account must request its snapshot
/// again when it is next selected after unlock.
public struct ChatListLoadState: Sendable, Equatable {
    public enum State: Sendable, Equatable {
        case needsLoad
        case loading
        case loaded
    }

    public private(set) var state: State = .needsLoad

    public init() {}

    /// Claims one request. A forced reload supersedes the previous loaded state.
    public mutating func beginLoad(reload: Bool = false) -> Bool {
        if reload { state = .needsLoad }
        guard state == .needsLoad else { return false }
        state = .loading
        return true
    }

    public mutating func completeLoad() {
        guard state == .loading else { return }
        state = .loaded
    }

    public mutating func failLoad() {
        guard state == .loading else { return }
        state = .needsLoad
    }

    public mutating func invalidate() {
        state = .needsLoad
    }
}
