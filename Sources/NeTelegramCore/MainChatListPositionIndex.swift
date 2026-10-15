/// Tracks membership and ordering for TDLib chat lists rendered in the app.
/// A position with order zero means TDLib removed the chat from that list.
public enum ChatListPositionScope: Sendable, Hashable {
    case main
    case archive
    case folder(Int32)
    case other
}

public struct MainChatListPositionIndex: Sendable, Equatable {
    private var orderByScope: [ChatListPositionScope: [Int64: UInt64]] = [:]

    public init() {}

    public func order(for chatID: Int64) -> UInt64? {
        order(for: chatID, scope: .main)
    }

    public func order(for chatID: Int64, scope: ChatListPositionScope) -> UInt64? {
        orderByScope[scope]?[chatID]
    }

    public var chatIDs: Set<Int64> { chatIDs(scope: .main) }

    public func chatIDs(scope: ChatListPositionScope) -> Set<Int64> {
        Set(orderByScope[scope, default: [:]].keys)
    }

    /// Replaces one chat's complete positions snapshot from `getChat`/`updateChat`.
    public mutating func replaceSnapshot(chatID: Int64, mainListOrder: UInt64?) {
        replaceSnapshot(chatID: chatID, scope: .main, order: mainListOrder)
    }

    public mutating func replaceSnapshot(chatID: Int64, scope: ChatListPositionScope, order: UInt64?) {
        guard scope != .other, let order, order > 0 else {
            orderByScope[scope]?.removeValue(forKey: chatID)
            return
        }
        orderByScope[scope, default: [:]][chatID] = order
    }

    /// Applies an incremental position update for the main, archived, or a
    /// custom folder list. The UI can deduplicate folders into one dialog row.
    public mutating func applyUpdate(chatID: Int64, scope: ChatListPositionScope, order: UInt64) {
        replaceSnapshot(chatID: chatID, scope: scope, order: order)
    }
}
