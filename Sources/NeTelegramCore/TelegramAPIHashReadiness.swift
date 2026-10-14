import Foundation

public enum TelegramAPIHashReadinessError: Error, Equatable, Sendable {
    case timedOut
    case invalidated
}

/// Shares one in-flight Keychain lookup between startup and explicit retries.
/// A caller may stop waiting, but the synchronous Security operation itself
/// cannot be cancelled safely. Later callers attach to that same operation.
public final class TelegramAPIHashReadiness: @unchecked Sendable {
    private typealias Loader = @Sendable () async throws -> String

    private let lock = NSLock()
    private var activeGeneration: UInt64?
    private var explicitReadGeneration: UInt64?
    private var pendingLoader: Loader?
    private var cachedValue: (generation: UInt64, value: String)?
    private var replacementInProgress = false
    private var generation: UInt64 = 0
    private var waiters: [UInt64: [UUID: CheckedContinuation<String, any Error>]] = [:]

    public init() {}

    public func value(
        timeout: TimeInterval = 10,
        supersedingInFlight: Bool = false,
        load: @escaping @Sendable () async throws -> String
    ) async throws -> String {
        let waiterID = UUID()
        return try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            var requestedGeneration = generation
            if !supersedingInFlight,
               let cachedValue,
               cachedValue.generation == requestedGeneration {
                lock.unlock()
                continuation.resume(returning: cachedValue.value)
                return
            }

            var supersededWaiters: [CheckedContinuation<String, any Error>] = []
            var operationToStart: (Loader, UInt64)?
            if supersedingInFlight, !replacementInProgress {
                if explicitReadGeneration == generation {
                    // A retry while the explicit OS query is still running
                    // joins it instead of filling the bounded Keychain queue.
                } else {
                    let staleGeneration = generation
                    generation &+= 1
                    requestedGeneration = generation
                    cachedValue = nil
                    pendingLoader = nil
                    supersededWaiters = waiters.removeValue(forKey: staleGeneration).map { Array($0.values) } ?? []
                    explicitReadGeneration = requestedGeneration
                    activeGeneration = requestedGeneration
                    operationToStart = (load, requestedGeneration)
                }
            }
            waiters[requestedGeneration, default: [:]][waiterID] = continuation
            if operationToStart == nil, activeGeneration == nil {
                if replacementInProgress {
                    pendingLoader = load
                } else {
                    activeGeneration = requestedGeneration
                    operationToStart = (load, requestedGeneration)
                }
            } else if operationToStart == nil, activeGeneration != requestedGeneration, pendingLoader == nil {
                // The old synchronous Security call cannot be cancelled. Defer
                // a fresh read until it returns, then discard its stale value.
                pendingLoader = load
            }
            lock.unlock()
            supersededWaiters.forEach { $0.resume(throwing: TelegramAPIHashReadinessError.invalidated) }

            let timeoutGeneration = requestedGeneration
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + max(0, timeout)) { [weak self] in
                self?.expire(waiterID, generation: timeoutGeneration)
            }

            if let operationToStart { start(operationToStart.0, generation: operationToStart.1) }
        }
    }

    /// Invalidate cached data when the configured app hash changes.
    public func invalidate() {
        beginReplacement()
        finishReplacement()
    }

    /// Accepts a value that the user explicitly authorized the system Keychain
    /// to return. This supersedes any stalled noninteractive lookup without
    /// exposing the value to presentation or diagnostics.
    public func acceptVerifiedValue(_ value: String) {
        lock.lock()
        let staleGeneration = generation
        generation &+= 1
        cachedValue = (generation, value)
        explicitReadGeneration = nil
        pendingLoader = nil
        replacementInProgress = false
        let staleWaiters = waiters.removeValue(forKey: staleGeneration).map { Array($0.values) } ?? []
        lock.unlock()
        staleWaiters.forEach { $0.resume(throwing: TelegramAPIHashReadinessError.invalidated) }
    }

    /// Call before writing a replacement hash so fresh lookups cannot observe
    /// the old Keychain value while the write is still in progress.
    public func beginReplacement() {
        lock.lock()
        let invalidatedGeneration = generation
        generation &+= 1
        cachedValue = nil
        explicitReadGeneration = nil
        replacementInProgress = true
        pendingLoader = nil
        let continuations = waiters.removeValue(forKey: invalidatedGeneration).map { Array($0.values) } ?? []
        lock.unlock()
        continuations.forEach { $0.resume(throwing: TelegramAPIHashReadinessError.invalidated) }
    }

    /// Resume reads after the Keychain write succeeds or fails. On failure,
    /// the next lookup reads the value which remains stored in Keychain.
    public func finishReplacement() {
        lock.lock()
        replacementInProgress = false
        var operationToStart: (Loader, UInt64)?
        if activeGeneration == nil,
           let loader = pendingLoader,
           waiters[generation]?.isEmpty == false {
            pendingLoader = nil
            activeGeneration = generation
            operationToStart = (loader, generation)
        }
        lock.unlock()
        if let operationToStart { start(operationToStart.0, generation: operationToStart.1) }
    }

    private func expire(_ waiterID: UUID, generation waiterGeneration: UInt64) {
        lock.lock()
        let continuation = waiters[waiterGeneration]?.removeValue(forKey: waiterID)
        if waiters[waiterGeneration]?.isEmpty == true { waiters.removeValue(forKey: waiterGeneration) }
        if waiterGeneration == generation, waiters[waiterGeneration] == nil, activeGeneration != generation {
            pendingLoader = nil
        }
        lock.unlock()
        continuation?.resume(throwing: TelegramAPIHashReadinessError.timedOut)
    }

    private func start(_ load: @escaping Loader, generation operationGeneration: UInt64) {
        Task { [self] in
            do {
                complete(.success(try await load()), generation: operationGeneration)
            } catch {
                complete(.failure(error), generation: operationGeneration)
            }
        }
    }

    private func complete(_ result: Result<String, any Error>, generation operationGeneration: UInt64) {
        lock.lock()
        guard activeGeneration == operationGeneration else {
            lock.unlock()
            return
        }
        activeGeneration = nil
        if explicitReadGeneration == operationGeneration {
            explicitReadGeneration = nil
        }
        var continuations: [CheckedContinuation<String, any Error>] = []
        var operationToStart: (Loader, UInt64)?
        if operationGeneration == generation {
            if case .success(let value) = result {
                cachedValue = (generation, value)
            }
            continuations = waiters.removeValue(forKey: generation).map { Array($0.values) } ?? []
        } else if let loader = pendingLoader, waiters[generation]?.isEmpty == false {
            if !replacementInProgress {
                pendingLoader = nil
                activeGeneration = generation
                operationToStart = (loader, generation)
            }
        } else {
            pendingLoader = nil
            waiters.removeValue(forKey: generation)
        }
        lock.unlock()
        continuations.forEach { $0.resume(with: result) }
        if let operationToStart { start(operationToStart.0, generation: operationToStart.1) }
    }
}
