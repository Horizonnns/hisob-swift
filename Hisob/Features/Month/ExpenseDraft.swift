import Foundation
import HisobCore

/// Черновик траты: суммы держатся строками, потому что пользователь может
/// ввести «1 234,56», незавершённое «12,» или мусор. В домен уходит только
/// то, что разобралось.
@Observable
final class ExpenseDraft {
    enum Kind: Hashable {
        case single
        case group
    }

    /// Позиция группы. Отдельный тип, а не `ExpenseItem`, — сумма в процессе
    /// набора ещё не число.
    struct Item: Identifiable, Hashable {
        let id: UUID
        var amountText: String
        var title: String

        init(id: UUID = UUID(), amountText: String = "", title: String = "") {
            self.id = id
            self.amountText = amountText
            self.title = title
        }

        var amount: Money? { ExpenseDraft.parse(amountText) }
        var isValid: Bool { amount != nil && !title.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// Идентификатор редактируемой траты; для новой — свежий.
    let id: UUID
    let isNew: Bool

    var kind: Kind
    var amountText: String
    var items: [Item]
    var category: ExpenseCategory
    var date: Date
    var title: String

    init(editing expense: Expense) {
        self.id = expense.id
        self.isNew = false
        self.category = expense.category
        self.date = expense.date
        self.title = expense.title

        switch expense.kind {
        case .single(let amount):
            self.kind = .single
            self.amountText = ExpenseDraft.format(amount)
            self.items = [Item()]
        case .group(let items):
            self.kind = .group
            self.amountText = ""
            self.items = items.map {
                Item(id: $0.id, amountText: ExpenseDraft.format($0.amount), title: $0.title)
            }
        }
    }

    init(defaultDate: Date) {
        self.id = UUID()
        self.isNew = true
        self.kind = .single
        self.amountText = ""
        self.items = [Item()]
        self.category = .food
        self.date = defaultDate
        self.title = ""
    }

    // MARK: - Разбор

    var singleAmount: Money? { ExpenseDraft.parse(amountText) }

    var validItems: [Item] { items.filter(\.isValid) }

    var groupTotal: Money {
        validItems.reduce(Money.zero) { $0 + ($1.amount ?? .zero) }
    }

    var canSave: Bool {
        switch kind {
        case .single:
            (singleAmount ?? .zero) > .zero
        case .group:
            !validItems.isEmpty && !title.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    /// Собирает трату из черновика. `nil`, если данных не хватает.
    func build() -> Expense? {
        guard canSave else { return nil }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        switch kind {
        case .single:
            guard let amount = singleAmount else { return nil }
            return .single(id: id, date: date, category: category, title: trimmedTitle, amount: amount)
        case .group:
            let built = validItems.map {
                ExpenseItem(
                    id: $0.id,
                    amount: $0.amount ?? .zero,
                    title: $0.title.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            return .group(id: id, date: date, category: category, title: trimmedTitle, items: built)
        }
    }

    // MARK: - Позиции

    func addItem() {
        items.append(Item())
    }

    func removeItem(_ item: Item) {
        guard items.count > 1 else { return }
        items.removeAll { $0.id == item.id }
    }

    // MARK: - Работа с суммой

    /// Принимает и точку, и запятую, и пробелы-разделители разрядов.
    static func parse(_ text: String) -> Money? {
        let normalized = text
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
        guard !normalized.isEmpty, let value = Money.parse(normalized), value > .zero else {
            return nil
        }
        return value
    }

    /// Сумма в поле ввода: без разделителей разрядов и без хвостовых нулей.
    static func format(_ amount: Money) -> String {
        let text = NSDecimalNumber(decimal: amount)
            .description(withLocale: Locale(identifier: "en_US_POSIX"))
        return text
    }
}
