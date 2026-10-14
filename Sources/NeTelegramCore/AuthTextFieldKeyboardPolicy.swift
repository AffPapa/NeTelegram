/// Prevents a Return key used to commit an input method candidate from
/// accidentally submitting the current authentication step.
public enum AuthTextFieldKeyboardPolicy {
    public static func shouldSubmit(
        isAuthenticationField: Bool,
        isReturnCommand: Bool,
        hasMarkedText: Bool
    ) -> Bool {
        isAuthenticationField && isReturnCommand && !hasMarkedText
    }
}
