import Foundation

public enum TypingActionCommand: Equatable, Sendable {
    case typing(ConversationKey)
    case cancel(ConversationKey)
}

/// Keeps remote typing presence tied to the one visible conversation and
/// refreshes it at a bounded rate while the user continues editing.
public struct TypingActionPolicy: Sendable {
    public static let refreshInterval: TimeInterval = 4

    private var activeConversation: ConversationKey?
    private var lastTypingActionAt: TimeInterval?

    public init() {}

    public mutating func update(
        conversation: ConversationKey,
        hasText: Bool,
        now: TimeInterval
    ) -> [TypingActionCommand] {
        var commands: [TypingActionCommand] = []

        if activeConversation != conversation, let activeConversation {
            commands.append(.cancel(activeConversation))
            self.activeConversation = nil
            lastTypingActionAt = nil
        }

        guard hasText else {
            if activeConversation == conversation {
                commands.append(.cancel(conversation))
                activeConversation = nil
                lastTypingActionAt = nil
            }
            return commands
        }

        if activeConversation == conversation,
           let lastTypingActionAt,
           now >= lastTypingActionAt,
           now - lastTypingActionAt < Self.refreshInterval {
            return commands
        }

        activeConversation = conversation
        self.lastTypingActionAt = now
        commands.append(.typing(conversation))
        return commands
    }

    /// Stop presence when the visible account/chat/topic changes or privacy
    /// lock begins. The caller sends the returned cancellation before changing
    /// the UI context or locking user-command dispatch.
    public mutating func stop() -> TypingActionCommand? {
        guard let activeConversation else { return nil }
        self.activeConversation = nil
        lastTypingActionAt = nil
        return .cancel(activeConversation)
    }

    /// A failed or rejected sendChatAction must be retried on the next edit.
    public mutating func retryTypingAction(for conversation: ConversationKey) {
        guard activeConversation == conversation else { return }
        lastTypingActionAt = nil
    }
}
