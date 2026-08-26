import Foundation

/// Фильтр списка трат: подстрока и набор категорий.
public struct ExpenseQuery: Hashable, Sendable {
    public var text: String
    public var categories: Set<ExpenseCategory>

    public init(text: String = "", categories: Set<ExpenseCategory> = []) {
        self.text = text
        self.categories = categories
    }

    public var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && categories.isEmpty
    }

    public static let none = ExpenseQuery()
}

extension ExpenseQuery {
    /// Насколько трата соответствует запросу: 3 — точное совпадение,
    /// 2 — начинается с запроса, 1 — содержит (в том числе в позициях группы),
    /// 0 — не подходит. Порт ранжирования из веб-версии.
    func score(_ expense: Expense, categoryTitle: (ExpenseCategory) -> String) -> Int {
        let needle = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return 1 }

        let title = expense.title.lowercased()
        let category = categoryTitle(expense.category).lowercased()

        if title == needle || category == needle { return 3 }
        if title.hasPrefix(needle) || category.hasPrefix(needle) { return 2 }
        if title.contains(needle) || category.contains(needle) { return 1 }
        if expense.items.contains(where: { $0.title.lowercased().contains(needle) }) { return 1 }
        return 0
    }
}

extension Array where Element == Expense {
    /// Применяет фильтр: сначала категории, затем текст с ранжированием.
    ///
    /// - Parameter categoryTitle: как категория выглядит для пользователя —
    ///   поиск должен находить трату по слову «Еда», а домен подписей не знает.
    public func filtered(
        by query: ExpenseQuery,
        categoryTitle: (ExpenseCategory) -> String = { $0.rawValue }
    ) -> [Expense] {
        var result = self
        if !query.categories.isEmpty {
            result = result.filter { query.categories.contains($0.category) }
        }
        guard !query.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return result
        }
        return result
            .map { (expense: $0, score: query.score($0, categoryTitle: categoryTitle)) }
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
            .map(\.expense)
    }
}
