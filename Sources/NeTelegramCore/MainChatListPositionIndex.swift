/// Tracks membership and ordering for TDLib's main chat list only.
/// A position with order zero means TDLib removed the chat from that list.
public enum ChatListPositionScope: Sendable, Equatable {
    case main
    case other
}

public struct MainChatListPositionIndex: Sendable, Equatable {
    private var orderByChatID: [Int64: UInt64] = [:]

    public init() {}

    public func order(for chatID: Int64) -> UInt64? {
        orderByChatID[chatID]
    }

    public var chatIDs: Set<Int64> { Set(orderByChatID.keys) }

    /// Replaces one chat's complete positions snapshot from `getChat`/`updateChat`.
    public mutating func replaceSnapshot(chatID: Int64, mainListOrder: UInt64?) {
        guard let mainListOrder, mainListOrder > 0 else {
            orderByChatID.removeValue(forKey: chatID)
            return
        }
        orderByChatID[chatID] = mainListOrder
    }

    /// Applies an incremental position update. Non-main lists are deliberately ignored.
    public mutating func applyUpdate(chatID: Int64, scope: ChatListPositionScope, order: UInt64) {
        guard scope == .main else { return }
        replaceSnapshot(chatID: chatID, mainListOrder: order)
    }
}
