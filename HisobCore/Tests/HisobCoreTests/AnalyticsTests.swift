import Foundation
import Testing
@testable import HisobCore

@Suite("Аналитика")
struct AnalyticsTests {
    @Test("Категории сгруппированы и отсортированы по убыванию")
    func categoryBreakdown() {
        let expenses = [
            expense("100", on: day(2026, 8, 1), category: .food),
            expense("50", on: day(2026, 8, 2), category: .food),
            expense("300", on: day(2026, 8, 3), category: .transport)
        ]
        let result = analytics.byCategory(expenses)
        #expect(result.map(\.category) == [.transport, .food])
        #expect(result.map(\.amount) == [money("300"), money("150")])
    }

    @Test("Группы учитываются по сумме позиций")
    func groupsCountedByItemsTotal() {
        let expenses = [
            Expense.group(
                date: day(2026, 8, 1),
                category: .loan,
                title: "хумо",
                items: [ExpenseItem(amount: money("1923.63"), title: "платёж")]
            )
        ]
        #expect(analytics.byCategory(expenses).first?.amount == money("1923.63"))
    }

    @Test("Окно из 12 месяцев заканчивается указанным месяцем")
    func monthlyWindow() {
        let result = analytics.monthlyTotals([], ending: ym(2026, 8), count: 12)
        #expect(result.count == 12)
        #expect(result.first?.month == ym(2025, 9))
        #expect(result.last?.month == ym(2026, 8))
    }

    @Test("Месяцы без трат возвращаются нулями, а не пропускаются")
    func gapsFilledWithZero() {
        let expenses = [expense("500", on: day(2026, 8, 10))]
        let result = analytics.monthlyTotals(expenses, ending: ym(2026, 8), count: 3)
        #expect(result.map(\.amount) == [.zero, .zero, money("500")])
        #expect(result.map(\.month) == [ym(2026, 6), ym(2026, 7), ym(2026, 8)])
    }

    @Test("Траты вне окна не попадают в результат")
    func outsideWindowIgnored() {
        let expenses = [expense("999", on: day(2024, 1, 1))]
        let result = analytics.monthlyTotals(expenses, ending: ym(2026, 8), count: 3)
        #expect(result.allSatisfy { $0.amount == .zero })
    }
}
