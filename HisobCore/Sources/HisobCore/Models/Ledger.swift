import Foundation

/// Полный финансовый срез пользователя: источники дохода и все траты.
///
/// Траты лежат здесь, а не внутри источников — это и есть перевёрнутая модель.
/// Личные расходы (еда, транспорт, коммуналка) финансируются суммарным доходом
/// и не принадлежат конкретной работе.
public struct Ledger: Hashable, Codable, Sendable {
    public var currency: CurrencyCode
    public var sources: [IncomeSource]
    public var expenses: [Expense]

    public init(
        currency: CurrencyCode = .tjs,
        sources: [IncomeSource] = [],
        expenses: [Expense] = []
    ) {
        self.currency = currency
        self.sources = sources
        self.expenses = expenses
    }

    public func source(id: IncomeSource.ID) -> IncomeSource? {
        sources.first { $0.id == id }
    }

    /// Траты указанного месяца, по возрастанию даты.
    public func expenses(in month: YearMonth, calendar: Calendar = .current) -> [Expense] {
        expenses
            .filter { month.contains($0.date, calendar: calendar) }
            .sorted { $0.date < $1.date }
    }

    /// Самый ранний месяц, в котором есть хоть одна трата.
    /// С него начинается цепочка переноса остатка.
    public func firstExpenseMonth(calendar: Calendar = .current) -> YearMonth? {
        expenses.map { $0.month(calendar: calendar) }.min()
    }
}
