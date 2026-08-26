import Foundation
import HisobCore
import Observation

/// Единый источник правды по данным в памяти.
///
/// Экраны читают `ledger` отсюда, а не держат каждый свою копию: правка
/// источника дохода в настройках сразу отражается на экране месяца и в
/// аналитике. Запись идёт в репозиторий, состояние в памяти обновляется
/// оптимистично и откатывается при ошибке.
@MainActor
@Observable
final class LedgerStore {
    enum State: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    private let repository: any LedgerRepository

    private(set) var ledger = Ledger()
    private(set) var state: State = .loading
    /// Сообщение о неудавшейся операции; показывается баннером и гасится само.
    private(set) var operationError: String?

    init(repository: any LedgerRepository) {
        self.repository = repository
    }

    // MARK: - Загрузка

    func load() async {
        state = .loading
        do {
            ledger = try await repository.load()
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Первая загрузка; повторные вызовы (например, при возврате на экран)
    /// данные не перечитывают.
    func loadIfNeeded() async {
        guard state == .loading else { return }
        await load()
    }

    // MARK: - Траты

    func add(_ expense: Expense) async {
        ledger.expenses.append(expense)
        await perform(rollback: { [weak self] in
            self?.ledger.expenses.removeAll { $0.id == expense.id }
        }) { [repository] in
            try await repository.add(expense)
        }
    }

    func update(_ expense: Expense) async {
        guard let index = ledger.expenses.firstIndex(where: { $0.id == expense.id }) else { return }
        let previous = ledger.expenses[index]
        ledger.expenses[index] = expense
        await perform(rollback: { [weak self] in
            guard let self, let index = ledger.expenses.firstIndex(where: { $0.id == previous.id })
            else { return }
            ledger.expenses[index] = previous
        }) { [repository] in
            try await repository.update(expense)
        }
    }

    func delete(_ expense: Expense) async {
        guard let index = ledger.expenses.firstIndex(where: { $0.id == expense.id }) else { return }
        let removed = ledger.expenses.remove(at: index)
        await perform(rollback: { [weak self] in
            guard let self else { return }
            ledger.expenses.insert(removed, at: min(index, ledger.expenses.count))
        }) { [repository] in
            try await repository.delete(expenseID: removed.id)
        }
    }

    // MARK: - Источники дохода

    func save(_ source: IncomeSource) async {
        let previous = ledger.sources
        if let index = ledger.sources.firstIndex(where: { $0.id == source.id }) {
            ledger.sources[index] = source
        } else {
            ledger.sources.append(source)
        }
        await perform(rollback: { [weak self] in
            self?.ledger.sources = previous
        }) { [repository] in
            try await repository.save(source)
        }
    }

    func delete(sourceID: IncomeSource.ID) async {
        let previousSources = ledger.sources
        let previousExpenses = ledger.expenses
        ledger.sources.removeAll { $0.id == sourceID }
        // Траты остаются: привязка к источнику была лишь пометкой.
        for index in ledger.expenses.indices where ledger.expenses[index].incomeSourceID == sourceID {
            ledger.expenses[index].incomeSourceID = nil
        }
        await perform(rollback: { [weak self] in
            self?.ledger.sources = previousSources
            self?.ledger.expenses = previousExpenses
        }) { [repository] in
            try await repository.delete(sourceID: sourceID)
        }
    }

    // MARK: - Служебное

    func dismissOperationError() {
        operationError = nil
    }

    /// Выполняет запись; при ошибке откатывает состояние и показывает баннер.
    private func perform(
        rollback: @MainActor @escaping () -> Void,
        write: @Sendable @escaping () async throws -> Void
    ) async {
        do {
            try await write()
        } catch {
            rollback()
            operationError = L.Error.saveFailed
        }
    }
}
