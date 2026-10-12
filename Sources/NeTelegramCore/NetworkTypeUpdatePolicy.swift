public enum NetworkTypeUpdatePolicy {
    /// Suppresses duplicate path notifications. Wake handling can force one
    /// reapplication because the transport may have changed during sleep.
    public static func shouldApply(current: String, next: String, force: Bool = false) -> Bool {
        force || current != next
    }
}
