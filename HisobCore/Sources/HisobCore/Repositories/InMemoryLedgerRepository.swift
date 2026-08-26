import Foundation

/// Реализация в памяти: для превью, тестов и первого запуска до подключения
/// постоянного хранилища. Заменяется на SwiftData/сетевую реализацию без
/// изменений во View и ViewModel.
public actor InMemoryLedgerRepository: LedgerRepository {
    private var ledger: Ledger

    public init(ledger: Ledger = Ledger()) {
        self.ledger = ledger
    }

    public func load() async throws -> Ledger {
        ledger
    }

    public func add(_ expense: Expense) async throws {
        ledger.expenses.append(expense)
    }

    public func update(_ expense: Expense) async throws {
        guard let index = ledger.expenses.firstIndex(where: { $0.id == expense.id }) else {
            throw LedgerRepositoryError.expenseNotFound(expense.id)
        }
        ledger.expenses[index] = expense
    }

    public func delete(expenseID: Expense.ID) async throws {
        guard let index = ledger.expenses.firstIndex(where: { $0.id == expenseID }) else {
            throw LedgerRepositoryError.expenseNotFound(expenseID)
        }
        ledger.expenses.remove(at: index)
    }

    public func save(_ source: IncomeSource) async throws {
        if let index = ledger.sources.firstIndex(where: { $0.id == source.id }) {
            ledger.sources[index] = source
        } else {
            ledger.sources.append(source)
        }
    }

    public func delete(sourceID: IncomeSource.ID) async throws {
        guard let index = ledger.sources.firstIndex(where: { $0.id == sourceID }) else {
            throw LedgerRepositoryError.sourceNotFound(sourceID)
        }
        ledger.sources.remove(at: index)
        // Траты, отнесённые к источнику, остаются — они личные, привязка
        // была лишь пометкой.
        for index in ledger.expenses.indices where ledger.expenses[index].incomeSourceID == sourceID {
            ledger.expenses[index].incomeSourceID = nil
        }
    }

    public func setCurrency(_ currency: CurrencyCode) async throws {
        ledger.currency = currency
    }
}
