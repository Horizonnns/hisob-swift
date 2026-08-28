import Foundation

/// Хранилище, работающее без сети.
///
/// Чтение: отправить накопленное, сходить на сервер, сохранить снимок.
/// Без связи — отдать снимок с наложенными неотправленными операциями,
/// чтобы приложение показывало ровно то, что показывало до потери сети.
///
/// Запись: применить локально и попробовать отправить. Не вышло по связи —
/// положить в очередь и считать операцию выполненной; вызывающая сторона
/// ничего не откатывает. Отказ сервера (400, 404, 401) — по-прежнему ошибка:
/// такое повторять бессмысленно.
///
/// Разрешение конфликтов — «выигрывает последняя запись». Для одного
/// пользователя с одним устройством этого достаточно; при нескольких
/// устройствах правки того же месяца могут затереть друг друга.
public actor OfflineFirstLedgerRepository: LedgerRepository {
    private let remote: any LedgerRepository
    private let snapshots: LedgerSnapshotStore
    private let queue: PendingOperationQueue

    public init(
        remote: any LedgerRepository,
        snapshots: LedgerSnapshotStore,
        queue: PendingOperationQueue
    ) {
        self.remote = remote
        self.snapshots = snapshots
        self.queue = queue
    }

    /// Сколько изменений ждут отправки — показывается в настройках.
    public func pendingCount() async -> Int {
        await queue.count
    }

    /// Отправляет накопленное и сообщает, опустела ли очередь.
    /// Вызывается явно — кнопкой повтора в настройках.
    @discardableResult
    public func flushPending() async -> Bool {
        try? await queue.flush(to: remote)
        return await queue.isEmpty
    }

    public func load() async throws -> Ledger {
        // Чтение не отправляет очередь: неудачная отправка упиралась
        // в таймаут и задерживала показ данных. Отправкой распоряжается
        // вызывающая сторона через `flushPending()` — она знает, ждать
        // результата или нет.
        do {
            let fresh = try await remote.load()
            await snapshots.save(fresh)
            return await queue.applying(to: fresh)
        } catch let error as APIError {
            // Снимок выручает только при обрыве связи. На 401 его отдавать
            // нельзя: токен отозвали, показывать данные дальше неправильно.
            guard case .transport = error, let cached = await snapshots.load() else {
                throw error
            }
            return await queue.applying(to: cached)
        }
    }

    public func add(_ expense: Expense) async throws {
        try await write(.addExpense(expense))
    }

    public func update(_ expense: Expense) async throws {
        try await write(.updateExpense(expense))
    }

    public func delete(expenseID: Expense.ID) async throws {
        try await write(.deleteExpense(expenseID))
    }

    public func add(_ receipt: Receipt) async throws {
        try await write(.addReceipt(receipt))
    }

    public func update(_ receipt: Receipt) async throws {
        try await write(.updateReceipt(receipt))
    }

    public func delete(receiptID: Receipt.ID) async throws {
        try await write(.deleteReceipt(receiptID))
    }

    public func save(_ source: IncomeSource) async throws {
        try await write(.saveSource(source))
    }

    public func delete(sourceID: IncomeSource.ID) async throws {
        try await write(.deleteSource(sourceID))
    }

    public func setCurrency(_ currency: CurrencyCode) async throws {
        try await write(.setCurrency(currency))
    }

    // MARK: - Общий путь записи

    private func write(_ operation: PendingOperation) async throws {
        await updateSnapshot(with: operation)

        do {
            try await operation.send(to: remote)
        } catch let error as APIError {
            guard case .transport = error else { throw error }
            await queue.enqueue(operation)
        }
    }

    /// Локальный снимок обновляется сразу: без этого перезапуск без сети
    /// показал бы состояние до правки.
    private func updateSnapshot(with operation: PendingOperation) async {
        guard var ledger = await snapshots.load() else { return }
        operation.apply(to: &ledger)
        await snapshots.save(ledger)
    }
}
