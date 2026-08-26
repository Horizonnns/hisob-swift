import Foundation

/// Хранилище финансовых данных.
///
/// Методы намеренно гранулярные. В веб-версии клиент отправлял весь массив
/// расходов целиком, а сервер удалял все записи и создавал заново: одна
/// ошибка на клиенте стирала всю историю, а две открытые вкладки затирали
/// правки друг друга. Здесь каждая операция затрагивает одну запись
/// со стабильным `id`.
public protocol LedgerRepository: Sendable {
    /// Полный срез: расчёт переноса требует всей истории, а не одного месяца.
    func load() async throws -> Ledger

    func add(_ expense: Expense) async throws
    func update(_ expense: Expense) async throws
    func delete(expenseID: Expense.ID) async throws

    /// Создаёт источник или обновляет существующий по `id`.
    func save(_ source: IncomeSource) async throws
    func delete(sourceID: IncomeSource.ID) async throws

    func setCurrency(_ currency: CurrencyCode) async throws
}

/// Ошибки хранилища.
public enum LedgerRepositoryError: Error, Equatable, Sendable {
    case expenseNotFound(Expense.ID)
    case sourceNotFound(IncomeSource.ID)
}
