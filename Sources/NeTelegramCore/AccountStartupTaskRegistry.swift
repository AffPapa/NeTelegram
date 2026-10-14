import Foundation

/// Tracks profile startup tasks independently so one stalled account cannot
/// hide another account's progress or prevent an isolated retry.
@MainActor
public final class AccountStartupTaskRegistry {
    private struct Entry {
        let id: UUID
        let task: Task<Void, Never>
    }

    private var entries: [AccountUUID: Entry] = [:]

    public init() {}

    public var startingAccounts: Set<AccountUUID> {
        Set(entries.keys)
    }

    public func contains(_ account: AccountUUID) -> Bool {
        entries[account] != nil
    }

    /// Reuses the in-flight task for the same profile. Completion removes only
    /// the registration it created, so a late canceled task cannot erase a
    /// newer retry for that profile.
    @discardableResult
    public func start(
        account: AccountUUID,
        operation: @escaping @MainActor () async throws -> Void,
        onCompletion: @escaping @MainActor (Result<Void, Error>) -> Void = { _ in }
    ) -> Task<Void, Never> {
        if let existing = entries[account] { return existing.task }

        let id = UUID()
        let task = Task { @MainActor [weak self] in
            let result: Result<Void, Error>
            if Task.isCancelled {
                result = .failure(CancellationError())
            } else {
                do {
                    try await operation()
                    result = .success(())
                } catch {
                    result = .failure(error)
                }
            }
            guard let self, self.finish(account: account, id: id) else { return }
            onCompletion(result)
        }
        entries[account] = Entry(id: id, task: task)
        return task
    }

    /// Removes registrations before cancellation, making new startup attempts
    /// explicit and ensuring canceled tasks cannot remain visible as pending.
    @discardableResult
    public func cancelAll() -> Bool {
        let tasks = entries.values.map(\.task)
        entries.removeAll()
        tasks.forEach { $0.cancel() }
        return !tasks.isEmpty
    }

    private func finish(account: AccountUUID, id: UUID) -> Bool {
        guard entries[account]?.id == id else { return false }
        entries.removeValue(forKey: account)
        return true
    }
}
