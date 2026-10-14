import Foundation

/// Shared ordering boundary for production profile startup and deterministic
/// integration tests. The route is registered before ownership and before the
/// first TDLib request so early updates always have an unambiguous destination.
@MainActor
public enum ProfileRuntimeStartupSequence {
    public enum Outcome {
        case cancelledBeforeRetention(RuntimeRoute)
        case cancelledAfterRetention(RuntimeRoute)
        case initializationQueued(RuntimeRoute)
    }

    public static func execute(
        createRoute: @MainActor () throws -> RuntimeRoute,
        registerRoute: @MainActor (RuntimeRoute) async throws -> Void,
        shouldContinue: @MainActor () -> Bool,
        removeUnretainedRoute: @MainActor (RuntimeRoute) async -> Void,
        retainRuntime: @MainActor (RuntimeRoute) -> Bool,
        startUpdatePipeline: @MainActor () -> Void,
        markWaitingForAuthorization: @MainActor (RuntimeRoute) async -> Void,
        enqueueInitializationRequest: @MainActor (RuntimeRoute) throws -> Void
    ) async throws -> Outcome {
        let route = try createRoute()
        try await registerRoute(route)

        // During quit, close the coordinator-only route that was registered
        // while the task was suspended, without ever retaining or requesting it.
        guard shouldContinue() else {
            await removeUnretainedRoute(route)
            return .cancelledBeforeRetention(route)
        }

        guard retainRuntime(route) else { throw RuntimeOwnershipError.duplicateOwner }
        startUpdatePipeline()
        await markWaitingForAuthorization(route)

        // Once retained, the normal termination path owns this runtime and
        // drains it through TDLib's Closed barrier. Do not enqueue new work.
        guard shouldContinue() else { return .cancelledAfterRetention(route) }

        try enqueueInitializationRequest(route)
        return .initializationQueued(route)
    }
}
