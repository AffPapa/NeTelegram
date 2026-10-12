import Foundation

public enum MessageDeleteMode: Sendable, Equatable {
    case forCurrentUser
    case forEveryone

    public var revoke: Bool { self == .forEveryone }
}

/// Server-reported capabilities for one message at the time of the action.
public struct MessageActionPermissions: Sendable, Equatable {
    public let canEdit: Bool
    public let canDeleteOnlyForSelf: Bool
    public let canDeleteForAllUsers: Bool

    public init(canEdit: Bool, canDeleteOnlyForSelf: Bool, canDeleteForAllUsers: Bool) {
        self.canEdit = canEdit
        self.canDeleteOnlyForSelf = canDeleteOnlyForSelf
        self.canDeleteForAllUsers = canDeleteForAllUsers
    }

    public init(tdlibObject: [String: Any]) {
        canEdit = tdlibObject["can_be_edited"] as? Bool == true
        canDeleteOnlyForSelf = tdlibObject["can_be_deleted_only_for_self"] as? Bool == true
        canDeleteForAllUsers = tdlibObject["can_be_deleted_for_all_users"] as? Bool == true
    }

    public var deleteModes: [MessageDeleteMode] {
        var modes: [MessageDeleteMode] = []
        if canDeleteForAllUsers { modes.append(.forEveryone) }
        if canDeleteOnlyForSelf { modes.append(.forCurrentUser) }
        return modes
    }

    public var hasActions: Bool { canEdit || canDeleteOnlyForSelf || canDeleteForAllUsers }
}
