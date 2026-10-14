import Foundation

public enum RuntimeOwnershipError: Error, Equatable, Sendable {
    case duplicateOwner
}

/// Strongly owns every open runtime and keeps account/client lookup indexes in
/// sync. The registry is main-actor isolated because AppKit runtime ownership
/// and presentation both live on the main actor.
@MainActor
public final class RuntimeOwnershipRegistry<Runtime: AnyObject> {
    private var runtimesByAccount: [AccountUUID: Runtime] = [:]
    private var runtimesByClient: [Int32: Runtime] = [:]
    private var routesByAccount: [AccountUUID: RuntimeRoute] = [:]
    private var routesByClient: [Int32: RuntimeRoute] = [:]

    public init() {}

    /// Inserts both indexes together before the caller sends the first
    /// TDLib request. Duplicate account or client ownership is rejected.
    @discardableResult
    public func retain(_ runtime: Runtime, for route: RuntimeRoute) -> Bool {
        let client = route.client.value
        guard runtimesByAccount[route.account] == nil,
              runtimesByClient[client] == nil else {
            return false
        }
        runtimesByAccount[route.account] = runtime
        runtimesByClient[client] = runtime
        routesByAccount[route.account] = route
        routesByClient[client] = route
        return true
    }

    public subscript(account account: AccountUUID) -> Runtime? {
        runtimesByAccount[account]
    }

    public subscript(client clientID: Int32) -> Runtime? {
        runtimesByClient[clientID]
    }

    /// Copy-on-write snapshots keep existing read-only AppDelegate iteration
    /// cheap while preventing callers from mutating ownership out of band.
    public var accounts: [AccountUUID: Runtime] { runtimesByAccount }
    public var clients: [Int32: Runtime] { runtimesByClient }

    /// Releases both indexes only for the exact runtime generation that owns
    /// both keys. A late close from an older generation cannot remove a newer
    /// replacement for the same AccountUUID.
    @discardableResult
    public func release(route: RuntimeRoute, ifOwnedBy runtime: Runtime) -> Bool {
        let client = route.client.value
        guard routesByAccount[route.account] == route,
              routesByClient[client] == route,
              runtimesByAccount[route.account] === runtime,
              runtimesByClient[client] === runtime else {
            return false
        }
        runtimesByAccount.removeValue(forKey: route.account)
        runtimesByClient.removeValue(forKey: client)
        routesByAccount.removeValue(forKey: route.account)
        routesByClient.removeValue(forKey: client)
        return true
    }
}
