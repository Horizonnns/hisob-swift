import Foundation

/// Хранилище с локальным снимком поверх удалённого.
///
/// Чтение: сходить в сеть, сохранить снимок; при недоступности сети отдать
/// последний снимок. Запись: только через сеть — при её отсутствии операция
/// честно падает, а вызывающая сторона откатывает оптимистичное изменение.
/// Очередь отложенных записей — отдельная задача, здесь её намеренно нет:
/// молча копить правки и синхронизировать их без разрешения конфликтов
/// опаснее, чем показать ошибку.
public actor CachedLedgerRepository: LedgerRepository {
    private let remote: any LedgerRepository
    private let snapshots: LedgerSnapshotStore

    public init(remote: any LedgerRepository, snapshots: LedgerSnapshotStore) {
        self.remote = remote
        self.snapshots = snapshots
    }

    public func load() async throws -> Ledger {
        do {
            let ledger = try await remote.load()
            await snapshots.save(ledger)
            return ledger
        } catch let error as APIError {
            // Снимок выручает только при обрыве связи. На 401 его отдавать
            // нельзя: токен отозвали, и показывать данные дальше неправильно.
            guard case .transport = error, let cached = await snapshots.load() else {
                throw error
            }
            return cached
        }
    }

    public func add(_ expense: Expense) async throws {
        try await remote.add(expense)
        await refreshSnapshot()
    }

    public func update(_ expense: Expense) async throws {
        try await remote.update(expense)
        await refreshSnapshot()
    }

    public func delete(expenseID: Expense.ID) async throws {
        try await remote.delete(expenseID: expenseID)
        await refreshSnapshot()
    }

    public func save(_ source: IncomeSource) async throws {
        try await remote.save(source)
        await refreshSnapshot()
    }

    public func delete(sourceID: IncomeSource.ID) async throws {
        try await remote.delete(sourceID: sourceID)
        await refreshSnapshot()
    }

    public func setCurrency(_ currency: CurrencyCode) async throws {
        try await remote.setCurrency(currency)
        await refreshSnapshot()
    }

    /// Обновляет снимок после успешной записи. Ошибка здесь не важна:
    /// данные уже на сервере, снимок догонит при следующей загрузке.
    private func refreshSnapshot() async {
        guard let ledger = try? await remote.load() else { return }
        await snapshots.save(ledger)
    }
}
