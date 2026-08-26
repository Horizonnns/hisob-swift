import Foundation

/// Доля категории в расходах — данные для круговой диаграммы.
public struct CategoryTotal: Identifiable, Hashable, Sendable {
    public var id: ExpenseCategory { category }
    public let category: ExpenseCategory
    public let amount: Money

    public init(category: ExpenseCategory, amount: Money) {
        self.category = category
        self.amount = amount
    }
}

/// Сумма трат за месяц — точка на столбчатой диаграмме.
public struct MonthlyTotal: Identifiable, Hashable, Sendable {
    public var id: YearMonth { month }
    public let month: YearMonth
    public let amount: Money

    public init(month: YearMonth, amount: Money) {
        self.month = month
        self.amount = amount
    }
}

/// Агрегаты для графиков. Тоже чистые функции.
public struct Analytics: Sendable {
    public let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Расходы по категориям, по убыванию суммы.
    public func byCategory(_ expenses: [Expense]) -> [CategoryTotal] {
        Dictionary(grouping: expenses, by: \.category)
            .map { CategoryTotal(category: $0.key, amount: $0.value.reduce(Money.zero) { $0 + $1.total }) }
            .sorted {
                $0.amount == $1.amount
                    ? $0.category.rawValue < $1.category.rawValue
                    : $0.amount > $1.amount
            }
    }

    /// Суммы за `count` месяцев, заканчивая `month`. Месяцы без трат
    /// возвращаются нулями, чтобы на графике не было провалов в сетке.
    public func monthlyTotals(
        _ expenses: [Expense],
        ending month: YearMonth,
        count: Int = 12
    ) -> [MonthlyTotal] {
        guard count > 0 else { return [] }
        var sums: [YearMonth: Money] = [:]
        for expense in expenses {
            let key = expense.month(calendar: calendar)
            sums[key, default: .zero] += expense.total
        }
        let start = month.adding(months: -(count - 1))
        return (0..<count).map { offset in
            let cursor = start.adding(months: offset)
            return MonthlyTotal(month: cursor, amount: sums[cursor] ?? .zero)
        }
    }
}
