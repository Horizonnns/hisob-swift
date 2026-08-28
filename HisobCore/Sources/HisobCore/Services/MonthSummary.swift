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
    /// Из чего сложился доход по местам работы.
    public let incomeBreakdown: [IncomeShare]
    /// Разовые поступления месяца — они уже входят в `income`.
    public let receipts: Money
    /// Из чего сложились разовые поступления.
    public let receiptBreakdown: [ReceiptShare]
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
        receipts: Money = .zero,
        receiptBreakdown: [ReceiptShare] = [],
        spent: Money,
        carryover: Money
    ) {
        self.month = month
        self.currency = currency
        self.income = income
        self.incomeBreakdown = incomeBreakdown
        self.receipts = receipts
        self.receiptBreakdown = receiptBreakdown
        self.spent = spent
        self.carryover = carryover
    }
}

/// Доля одного вида разовых поступлений в месяце.
public struct ReceiptShare: Identifiable, Hashable, Sendable {
    public let kind: ReceiptKind
    public let amount: Money

    public var id: ReceiptKind { kind }

    public init(kind: ReceiptKind, amount: Money) {
        self.kind = kind
        self.amount = amount
    }
}
