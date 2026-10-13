public enum LoginItemRegistrationState: Sendable, Equatable {
    case unavailable
    case notRegistered
    case requiresApproval
    case enabled
}

public enum LoginItemPreferenceAction: Sendable, Equatable {
    case showUnavailable
    case noChange
    case openLoginItemsSettings
    case register
    case unregister
}

public enum LoginItemPreferencePolicy {
    public static func action(
        for state: LoginItemRegistrationState,
        requestedEnabled: Bool
    ) -> LoginItemPreferenceAction {
        switch (state, requestedEnabled) {
        case (.unavailable, _):
            .showUnavailable
        case (.notRegistered, false), (.enabled, true):
            .noChange
        case (.notRegistered, true):
            .register
        case (.requiresApproval, true):
            .openLoginItemsSettings
        case (.enabled, false), (.requiresApproval, false):
            .unregister
        }
    }
}
