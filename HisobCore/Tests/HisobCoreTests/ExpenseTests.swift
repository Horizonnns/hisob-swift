import Foundation
import Testing
@testable import HisobCore

@Suite("Трата")
struct ExpenseTests {
    @Test("Сумма одиночной траты")
    func singleTotal() {
        #expect(expense("13", on: day(2026, 8, 2)).total == money("13"))
    }

    @Test("Сумма группы всегда считается из позиций")
    func groupTotal() {
        // Рассинхронизировать сумму и позиции здесь структурно невозможно:
        // в вебе `amount` и `items` были отдельными полями.
        let grouped = Expense.group(
            date: day(2026, 8, 2),
            category: .loan,
            title: "хумо",
            items: [
                ExpenseItem(amount: money("1000"), title: "первая"),
                ExpenseItem(amount: money("923.63"), title: "вторая")
            ]
        )
        #expect(grouped.total == money("1923.63"))
        #expect(grouped.isGroup)
        #expect(grouped.items.count == 2)
    }

    @Test("Дробные суммы складываются точно")
    func decimalPrecision() {
        // На Double 0.1 + 0.2 != 0.3; Decimal обязан дать точный результат,
        // иначе за год накопится расхождение в остатке.
        let items = (1...10).map { _ in ExpenseItem(amount: money("0.1"), title: "x") }
        let grouped = Expense.group(date: day(2026, 8, 1), category: .food, title: "мелочь", items: items)
        #expect(grouped.total == money("1.0"))
    }

    @Test("Пустая группа даёт ноль, а не падение")
    func emptyGroup() {
        let grouped = Expense.group(date: day(2026, 8, 1), category: .food, title: "пусто", items: [])
        #expect(grouped.total == .zero)
    }

    @Test("Трата знает свой месяц")
    func month() {
        #expect(expense("10", on: day(2026, 8, 31)).month(calendar: utc) == ym(2026, 8))
    }

    @Test("По умолчанию трата личная, а не привязана к работе")
    func personalByDefault() {
        #expect(expense("10", on: day(2026, 8, 1)).incomeSourceID == nil)
    }
}
