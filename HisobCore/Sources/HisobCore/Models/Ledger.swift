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
    /// Разовые поступления: подарки, возвраты, продажи.
    public var receipts: [Receipt]

    public init(
        currency: CurrencyCode = .tjs,
        sources: [IncomeSource] = [],
        expenses: [Expense] = [],
        receipts: [Receipt] = []
    ) {
        self.currency = currency
        self.sources = sources
        self.expenses = expenses
        self.receipts = receipts
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

    /// Поступления указанного месяца, по возрастанию даты.
    public func receipts(in month: YearMonth, calendar: Calendar = .current) -> [Receipt] {
        receipts
            .filter { month.contains($0.date, calendar: calendar) }
            .sorted { $0.date < $1.date }
    }

    /// Самый ранний месяц, в котором есть хоть одна запись — трата или
    /// поступление. С него начинается цепочка переноса остатка.
    ///
    /// Поступления учитываются наравне с тратами: подарок, полученный до
    /// первой траты, — такое же начало учёта.
    public func firstRecordedMonth(calendar: Calendar = .current) -> YearMonth? {
        let months = expenses.map { $0.month(calendar: calendar) }
            + receipts.map { $0.month(calendar: calendar) }
        return months.min()
    }
}
