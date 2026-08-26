import Foundation
import Testing
@testable import HisobCore

@Suite("Фильтр трат")
struct ExpenseQueryTests {
    private let expenses = [
        expense("13", on: day(2026, 8, 2), category: .food, title: "rc-cola"),
        expense("40", on: day(2026, 8, 3), category: .transport, title: "такси до офиса"),
        Expense.group(
            date: day(2026, 8, 4),
            category: .loan,
            title: "хумо",
            items: [ExpenseItem(amount: money("100"), title: "страховка")]
        )
    ]

    @Test("Пустой запрос ничего не отсекает")
    func emptyQueryKeepsAll() {
        #expect(expenses.filtered(by: .none).count == 3)
    }

    @Test("Фильтр по категориям")
    func categoryFilter() {
        let query = ExpenseQuery(categories: [.food, .loan])
        #expect(expenses.filtered(by: query).map(\.title).sorted() == ["rc-cola", "хумо"])
    }

    @Test("Поиск по описанию без учёта регистра")
    func caseInsensitiveSearch() {
        #expect(expenses.filtered(by: ExpenseQuery(text: "RC-Cola")).map(\.title) == ["rc-cola"])
    }

    @Test("Точное совпадение идёт выше частичного")
    func scoringOrder() {
        let items = [
            expense("1", on: day(2026, 8, 1), title: "такси до аэропорта"),
            expense("2", on: day(2026, 8, 2), title: "такси")
        ]
        #expect(items.filtered(by: ExpenseQuery(text: "такси")).map(\.title) == ["такси", "такси до аэропорта"])
    }

    @Test("Находит трату по позиции внутри группы")
    func searchesInsideGroupItems() {
        #expect(expenses.filtered(by: ExpenseQuery(text: "страховка")).map(\.title) == ["хумо"])
    }

    @Test("Находит по подписи категории, а не по её ключу")
    func searchesByCategoryTitle() {
        // Домен хранит `food`; пользователь ищет «Еда» — подпись приходит из UI.
        let titles: (ExpenseCategory) -> String = { $0 == .food ? "Еда" : $0.rawValue }
        let result = expenses.filtered(by: ExpenseQuery(text: "еда"), categoryTitle: titles)
        #expect(result.map(\.title) == ["rc-cola"])
    }

    @Test("Категория и текст применяются вместе")
    func combinedFilters() {
        let query = ExpenseQuery(text: "такси", categories: [.food])
        #expect(expenses.filtered(by: query).isEmpty)
    }
}
