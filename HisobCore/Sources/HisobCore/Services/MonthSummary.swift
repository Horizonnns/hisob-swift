import Foundation

/// Вклад одного источника в доход месяца — для разбивки на экране.
public struct IncomeShare: Identifiable, Hashable, Sendable {
    public var id: IncomeSource.ID { sourceID }
    public let sourceID: IncomeSource.ID
    public let sourceName: String
    public let amount: Money

    public init(sourceID: IncomeSource.ID, sourceName: String, amount: Money) {
        self.sourceID = sourceID
        self.sourceName = sourceName
        self.amount = amount
    }
}

/// Итоги месяца — четыре цифры в шапке экрана.
public struct MonthSummary: Hashable, Sendable {
    public let month: YearMonth
    public let currency: CurrencyCode
    /// Суммарный доход всех источников, активных в этом месяце.
    public let income: Money
    /// Из чего сложился доход.
    public let incomeBreakdown: [IncomeShare]
    /// Потрачено за месяц — все траты, независимо от привязки к источнику.
    public let spent: Money
    /// Остаток, перешедший из предыдущих месяцев.
    public let carryover: Money
    /// Сколько осталось: доход + перенос − потрачено.
    public var remaining: Money { income + carryover - spent }

    public init(
        month: YearMonth,
        currency: CurrencyCode,
        income: Money,
        incomeBreakdown: [IncomeShare],
        spent: Money,
        carryover: Money
    ) {
        self.month = month
        self.currency = currency
        self.income = income
        self.incomeBreakdown = incomeBreakdown
        self.spent = spent
        self.carryover = carryover
    }
}
