import Foundation
import CoreFoundation

public struct AccountUUID: Hashable, Sendable, Identifiable, Codable {
    public let id: UUID
    public init(_ id: UUID = UUID()) { self.id = id }
}

public struct RuntimeGeneration: Hashable, Sendable, Comparable {
    public let value: UInt64
    public init(_ value: UInt64) { self.value = value }
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.value < rhs.value }
}

public struct ClientID: Hashable, Sendable {
    public let value: Int32
    public init(_ value: Int32) { self.value = value }
}

public enum AccountAvailability: Sendable, Equatable {
    case needsAuthorization
    case starting
    case waitingForAuthorization
    case readyIdentityPending
    case active(telegramUserID: Int64)
    case failed(String)
    case closing
    case closed
}

public struct RuntimeRoute: Sendable, Equatable {
    public let account: AccountUUID
    public let generation: RuntimeGeneration
    public let client: ClientID

    public init(account: AccountUUID, generation: RuntimeGeneration, client: ClientID) {
        self.account = account
        self.generation = generation
        self.client = client
    }
}

/// Revalidates ownership after a runtime callback has suspended. The
/// coordinator is checked first; local UI/runtime ownership is checked only
/// after that await, while executing on the main actor.
@MainActor
public enum RuntimeUpdateOwnership {
    /// Runs the runtime's asynchronous update reduction and then checks that
    /// the same route still owns the callback before the caller applies any
    /// account, notification, or presentation side effects.
    public static func consumeThenCheck(
        _ route: RuntimeRoute,
        consume: @MainActor () async -> Void,
        coordinatorRouteIsCurrent: @Sendable () async -> Bool,
        localOwnerIsCurrent: @MainActor () -> Bool
    ) async -> Bool {
        await consume()
        return await isCurrent(
            route,
            coordinatorRouteIsCurrent: coordinatorRouteIsCurrent,
            localOwnerIsCurrent: localOwnerIsCurrent
        )
    }

    public static func isCurrent(
        _ route: RuntimeRoute,
        coordinatorRouteIsCurrent: @Sendable () async -> Bool,
        localOwnerIsCurrent: @MainActor () -> Bool
    ) async -> Bool {
        guard await coordinatorRouteIsCurrent() else { return false }
        return localOwnerIsCurrent()
    }

    /// A terminal Closed update removes its coordinator route before the
    /// caller performs local cleanup. Let only that exact local runtime finish
    /// handling the event; a replacement generation still fails the local
    /// ownership check.
    public static func isCurrentOrTerminalClose(
        _ route: RuntimeRoute,
        isTerminalClose: Bool,
        coordinatorRouteIsCurrent: @Sendable () async -> Bool,
        localOwnerIsCurrent: @MainActor () -> Bool
    ) async -> Bool {
        let coordinatorOwnsRoute = await coordinatorRouteIsCurrent()
        guard localOwnerIsCurrent() else { return false }
        return coordinatorOwnsRoute || isTerminalClose
    }
}

public struct RoutedTDLibUpdate: Sendable {
    public let route: RuntimeRoute
    public let json: Data
}

public enum TDLibRoutingError: Error, Equatable, Sendable {
    case malformedUpdate
    case missingClientID
    case invalidClientID
    case unregisteredClientID(ClientID)
}

/// TDLib JSON plus its validated client routing field, parsed once at ingress
/// so the bounded update queue can schedule client lanes fairly.
public struct BufferedTDLibUpdate: Sendable {
    public let json: Data
    public let clientID: ClientID?
    public let routingError: TDLibRoutingError?
    let usesReservedLaneCapacity: Bool

    public init(json: Data, usesReservedLaneCapacity: Bool = false) {
        self.json = json
        self.usesReservedLaneCapacity = usesReservedLaneCapacity
        guard let object = try? JSONSerialization.jsonObject(with: json),
              let fields = object as? [String: Any] else {
            clientID = nil
            routingError = .malformedUpdate
            return
        }
        guard let number = fields["@client_id"] as? NSNumber else {
            clientID = nil
            routingError = .missingClientID
            return
        }
        guard CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue.rounded(.towardZero) == number.doubleValue,
              number.int64Value >= Int64(Int32.min), number.int64Value <= Int64(Int32.max) else {
            clientID = nil
            routingError = .invalidClientID
            return
        }
        clientID = ClientID(number.int32Value)
        routingError = nil
    }
}

public enum RuntimeEventKind: Sendable, Equatable {
    case ordinaryState
    case authorization
    case deletion
    case ttl
}

/// Data-only core contract. A concrete TDLib adapter must supply the one blocking
/// receive worker and ordered decoding; this type never substitutes UI selection
/// when routing fails.
public actor RuntimeCoordinator {
    public let startupParallelism: Int
    private var routes: [ClientID: RuntimeRoute] = [:]
    private var states: [AccountUUID: AccountAvailability] = [:]
    private var activeStarts = 0
    private var generationCounters: [AccountUUID: UInt64] = [:]

    public init(startupParallelism: Int = 2) {
        self.startupParallelism = max(1, startupParallelism)
    }

    public func registerBeforeFirstRequest(_ route: RuntimeRoute) throws {
        guard routes[route.client] == nil else { throw RuntimeError.clientIDAlreadyRouted }
        guard !routes.values.contains(where: { $0.account == route.account }) else {
            throw RuntimeError.generationAlreadyRouted
        }
        routes[route.client] = route
        states[route.account] = .starting
    }

    public func route(for client: ClientID) -> RuntimeRoute? { routes[client] }

    /// Confirms that an asynchronous callback still belongs to the active
    /// client/account/generation after it suspends. Callers must not use a
    /// route checked before an `await` as proof that it is still current.
    public func isCurrent(_ route: RuntimeRoute) -> Bool {
        routes[route.client] == route
    }

    /// Returns a fresh generation for each client opened in this process.
    public func nextGeneration(for account: AccountUUID) -> RuntimeGeneration {
        let next = (generationCounters[account] ?? 0) &+ 1
        generationCounters[account] = next
        return RuntimeGeneration(next)
    }

    /// Removes a route only when the first request was rejected before it was
    /// queued. Once TDLib has accepted initialization, callers must retain the
    /// route and database ownership until an authorizationStateClosed update.
    @discardableResult
    public func removeRouteAfterInitializationRequestRejected(_ route: RuntimeRoute) -> Bool {
        guard routes[route.client] == route else { return false }
        routes.removeValue(forKey: route.client)
        states[route.account] = .failed("TDLib initialization request could not be queued")
        return true
    }

    /// TDLib's global JSON interface tags every update with @client_id. Missing
    /// or unknown IDs are explicit routing errors; selected UI state is never a
    /// substitute for a missing route.
    public func routeUpdate(_ json: Data) throws -> RoutedTDLibUpdate {
        try routeUpdate(BufferedTDLibUpdate(json: json))
    }

    /// Preserves each client's order while allowing the bounded ingress buffer
    /// to alternate between independent TDLib clients.
    public func routeUpdate(_ update: BufferedTDLibUpdate) throws -> RoutedTDLibUpdate {
        if let routingError = update.routingError { throw routingError }
        guard let client = update.clientID else { throw TDLibRoutingError.missingClientID }
        guard let route = routes[client] else { throw TDLibRoutingError.unregisteredClientID(client) }
        return RoutedTDLibUpdate(route: route, json: update.json)
    }

    public func state(for account: AccountUUID) -> AccountAvailability? { states[account] }

    /// Applies a TDLib authorization update only while its client, account,
    /// and generation still own the registered route. A late event from a
    /// closed client cannot overwrite the state of a newer runtime.
    @discardableResult
    public func applyAuthorizationState(
        _ authorizationState: String,
        telegramUserID: Int64?,
        from route: RuntimeRoute
    ) -> Bool {
        guard routes[route.client] == route else { return false }
        let reduced = AccountReducer.reduce(
            current: states[route.account],
            authorizationState: authorizationState,
            telegramUserID: telegramUserID
        )
        states[route.account] = reduced
        if reduced == .closed { routes.removeValue(forKey: route.client) }
        return true
    }

    /// Updates account-level state only when no runtime route owns the account.
    /// This is reserved for failures before TDLib client registration; it cannot
    /// overwrite state belonging to a newly opened generation.
    @discardableResult
    public func setState(_ state: AccountAvailability, for account: AccountUUID) -> Bool {
        guard !routes.values.contains(where: { $0.account == account }) else { return false }
        states[account] = state
        return true
    }

    /// Applies status produced by a specific runtime only while that exact
    /// client/account/generation still owns the route.
    @discardableResult
    public func setState(_ state: AccountAvailability, from route: RuntimeRoute) -> Bool {
        guard routes[route.client] == route else { return false }
        states[route.account] = state
        return true
    }

    /// Permits cover local client construction only; callers release before an
    /// OTP/network wait so one stalled profile cannot block the remaining ramp.
    public func acquireStartupPermit() -> Bool {
        guard activeStarts < startupParallelism else { return false }
        activeStarts += 1
        return true
    }

    public func releaseStartupPermit() { activeStarts = max(0, activeStarts - 1) }

    /// Only presentation-only updates may be coalesced. Critical lifecycle events
    /// must remain lossless; callers apply bounded backpressure instead of dropping.
    public func mayCoalesce(_ event: RuntimeEventKind) -> Bool {
        event == .ordinaryState
    }

    public func removeRouteAfterClosed(_ client: ClientID) {
        guard let route = routes.removeValue(forKey: client) else { return }
        states[route.account] = .closed
    }
}

/// FIFO startup permits limit only simultaneous local opens. The permit is
/// released after client registration and first request, before any auth wait.
public actor RuntimeStartupScheduler {
    public let parallelism: Int
    private var active = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init(parallelism: Int = 2) { self.parallelism = max(1, parallelism) }

    public func acquire() async {
        if active < parallelism {
            active += 1
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    public func release() {
        if waiters.isEmpty {
            active = max(0, active - 1)
        } else {
            waiters.removeFirst().resume()
        }
    }

    /// Runs the local open phase under one startup permit and returns the
    /// permit on both success and failure. Callers should finish this phase
    /// immediately after the first TDLib request is queued, before waiting for
    /// phone, code, password, or other network-driven authorization updates.
    public func withPermit<Value: Sendable>(
        _ operation: @Sendable () async throws -> Value
    ) async rethrows -> Value {
        await acquire()
        do {
            let value = try await operation()
            release()
            return value
        } catch {
            release()
            throw error
        }
    }

    public func activeStarts() -> Int { active }
    public func queuedStarts() -> Int { waiters.count }
}

public enum RuntimeError: Error, Equatable {
    case clientIDAlreadyRouted
    /// An account's TDLib database must not have two live client owners.
    case generationAlreadyRouted
}
