import Foundation
import Testing
@testable import HisobCore

@Suite("Итоги месяца")
struct MonthSummaryTests {
    private let ledger = Ledger(
        sources: [IncomeSource(name: "OD", salaryHistory: [salary("10120", from: day(2026, 8, 1))])],
        expenses: [
            expense("13", on: day(2026, 8, 2), category: .food, title: "rc-cola"),
            Expense.group(
                date: day(2026, 8, 2),
                category: .loan,
                title: "хумо",
                items: [
                    ExpenseItem(amount: money("1000"), title: "часть 1"),
                    ExpenseItem(amount: money("923.63"), title: "часть 2")
                ]
            ),
            expense("500", on: day(2026, 9, 1), title: "другой месяц")
        ]
    )

    @Test("Потрачено считает и одиночные траты, и группы, только за свой месяц")
    func spentIncludesGroupsAndIgnoresOtherMonths() {
        #expect(calculator.spent(ledger, in: ym(2026, 8)) == money("1936.63"))
        #expect(calculator.spent(ledger, in: ym(2026, 9)) == money("500"))
    }

    @Test("Остаток = доход + перенос − потрачено")
    func remainingMath() {
        let summary = calculator.summary(ledger, for: ym(2026, 8))
        #expect(summary.income == money("10120"))
        #expect(summary.spent == money("1936.63"))
        #expect(summary.remaining == summary.income + summary.carryover - summary.spent)
    }

    @Test("Перерасход даёт отрицательный остаток, а не ноль")
    func remainingCanGoNegative() {
        // Отрицательный остаток должен быть виден пользователю в своём месяце;
        // обнуляется он только при переносе в следующий.
        let overspent = Ledger(
            sources: [IncomeSource(name: "OD", salaryHistory: [salary("1000", from: day(2026, 8, 1))])],
            expenses: [expense("1500", on: day(2026, 8, 5))]
        )
        #expect(calculator.summary(overspent, for: ym(2026, 8)).remaining == money("-500"))
    }

    @Test("Месяц без данных даёт нули, а не падение")
    func emptyMonth() {
        let summary = calculator.summary(Ledger(), for: ym(2026, 8))
        #expect(summary.income == .zero)
        #expect(summary.spent == .zero)
        #expect(summary.carryover == .zero)
        #expect(summary.remaining == .zero)
        #expect(summary.incomeBreakdown.isEmpty)
    }

    @Test("Траты месяца отсортированы по дате")
    func expensesSorted() {
        let unordered = Ledger(expenses: [
            expense("1", on: day(2026, 8, 20), title: "поздняя"),
            expense("2", on: day(2026, 8, 3), title: "ранняя")
        ])
        #expect(unordered.expenses(in: ym(2026, 8), calendar: utc).map(\.title) == ["ранняя", "поздняя"])
    }
}
