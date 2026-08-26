import Foundation

/// Как поступать с отрицательным остатком при переносе в следующий месяц.
public enum CarryoverPolicy: Sendable {
    /// Отрицательный остаток обнуляется: перерасход не превращается в долг
    /// следующего месяца. Поведение веб-версии (`Math.max(0, ...)`).
    case clampNegative
    /// Перерасход переносится минусом и уменьшает следующий месяц.
    case allowDebt
}

/// Все расчёты по месяцу. Чистые функции без побочных эффектов и без
/// зависимости от UI — поэтому покрываются тестами целиком.
public struct LedgerCalculator: Sendable {
    public let calendar: Calendar
    public let carryoverPolicy: CarryoverPolicy

    public init(calendar: Calendar = .current, carryoverPolicy: CarryoverPolicy = .clampNegative) {
        self.calendar = calendar
        self.carryoverPolicy = carryoverPolicy
    }

    // MARK: - Доход

    /// Суммарный доход за месяц по всем источникам.
    ///
    /// Раньше оклад брался у одного проекта; теперь источники складываются,
    /// и завершённые в расчёт не попадают (см. `IncomeSource.endedAt`).
    public func income(_ ledger: Ledger, in month: YearMonth) -> Money {
        ledger.sources.reduce(Money.zero) { $0 + $1.salary(in: month, calendar: calendar) }
    }

    /// Разбивка дохода по источникам; источники без дохода отброшены.
    public func incomeBreakdown(_ ledger: Ledger, in month: YearMonth) -> [IncomeShare] {
        ledger.sources
            .map { source in
                IncomeShare(
                    sourceID: source.id,
                    sourceName: source.name,
                    amount: source.salary(in: month, calendar: calendar)
                )
            }
            .filter { $0.amount > .zero }
            .sorted { $0.amount > $1.amount }
    }

    // MARK: - Расход

    public func spent(_ ledger: Ledger, in month: YearMonth) -> Money {
        ledger.expenses
            .filter { month.contains($0.date, calendar: calendar) }
            .reduce(Money.zero) { $0 + $1.total }
    }

    // MARK: - Перенос остатка

    /// Остаток, накопленный за все месяцы до `month`.
    ///
    /// Цепочка одна на пользователя и идёт сквозь смену работы: остаток
    /// периода завершённого источника перетекает в первые месяцы следующего.
    /// В веб-версии цепочка считалась внутри проекта и на смене работы
    /// обрывалась.
    ///
    /// Начало цепочки — первый месяц с тратами: месяцы до начала учёта
    /// достоверных данных не содержат.
    public func carryover(_ ledger: Ledger, before month: YearMonth) -> Money {
        guard let start = ledger.firstExpenseMonth(calendar: calendar), start < month else {
            return .zero
        }

        var balance = Money.zero
        for cursor in stride(from: start, to: month, by: 1) {
            balance += income(ledger, in: cursor) - spent(ledger, in: cursor)
            if carryoverPolicy == .clampNegative, balance < .zero {
                balance = .zero
            }
        }
        return balance
    }

    // MARK: - Итог

    public func summary(_ ledger: Ledger, for month: YearMonth) -> MonthSummary {
        MonthSummary(
            month: month,
            currency: ledger.currency,
            income: income(ledger, in: month),
            incomeBreakdown: incomeBreakdown(ledger, in: month),
            spent: spent(ledger, in: month),
            carryover: carryover(ledger, before: month)
        )
    }
}
