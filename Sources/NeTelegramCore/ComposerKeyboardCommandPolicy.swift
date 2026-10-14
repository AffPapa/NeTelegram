import Foundation

/// Keeps message sending explicit: plain Return and IME composition stay in the editor.
public enum ComposerKeyboardCommandPolicy {
    public static func shouldSend(
        isCommandReturn: Bool,
        composerIsFocused: Bool,
        isLocked: Bool,
        hasMarkedText: Bool,
        sendIsEnabled: Bool
    ) -> Bool {
        isCommandReturn && composerIsFocused && !isLocked && !hasMarkedText && sendIsEnabled
    }
}
