import Foundation

/// Позиция внутри групповой траты — например «хумо (6 поз.)».
public struct ExpenseItem: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var amount: Money
    public var title: String

    public init(id: UUID = UUID(), amount: Money, title: String) {
        self.id = id
        self.amount = amount
        self.title = title
    }
}

/// Трата: либо одна сумма, либо набор позиций.
///
/// Смоделировано перечислением намеренно. В вебе у записи были одновременно
/// поле `amount` и массив `items`, и удерживать их согласованными приходилось
/// вручную в трёх местах (форма, редактор, сервер). Здесь рассинхронизировать
/// их структурно невозможно: сумма группы всегда вычисляется из позиций.
public enum ExpenseKind: Hashable, Codable, Sendable {
    case single(Money)
    case group([ExpenseItem])
}

public struct Expense: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var date: Date
    public var category: ExpenseCategory
    /// Описание траты; для группы — её заголовок.
    public var title: String
    public var kind: ExpenseKind

    /// Источник дохода, к которому трата отнесена явно.
    ///
    /// `nil` — личная трата, то есть подавляющее большинство записей. Заполняется
    /// только для расходов, привязанных к конкретной работе (техника под проект,
    /// поездка к клиенту). Из-за этого поля траты больше не «принадлежат» месту
    /// работы — это и есть развёрнутая модель.
    public var incomeSourceID: IncomeSource.ID?

    public init(
        id: UUID = UUID(),
        date: Date,
        category: ExpenseCategory,
        title: String,
        kind: ExpenseKind,
        incomeSourceID: IncomeSource.ID? = nil
    ) {
        self.id = id
        self.date = date
        self.category = category
        self.title = title
        self.kind = kind
        self.incomeSourceID = incomeSourceID
    }

    /// Итоговая сумма траты.
    public var total: Money {
        switch kind {
        case .single(let amount):
            amount
        case .group(let items):
            items.reduce(Money.zero) { $0 + $1.amount }
        }
    }

    public var isGroup: Bool {
        if case .group = kind { return true }
        return false
    }

    /// Позиции группы; для одиночной траты — пусто.
    public var items: [ExpenseItem] {
        if case .group(let items) = kind { return items }
        return []
    }

    public func month(calendar: Calendar = .current) -> YearMonth {
        YearMonth(date: date, calendar: calendar)
    }
}

extension Expense {
    public static func single(
        id: UUID = UUID(),
        date: Date,
        category: ExpenseCategory,
        title: String,
        amount: Money,
        incomeSourceID: IncomeSource.ID? = nil
    ) -> Expense {
        Expense(id: id, date: date, category: category, title: title,
                kind: .single(amount), incomeSourceID: incomeSourceID)
    }

    public static func group(
        id: UUID = UUID(),
        date: Date,
        category: ExpenseCategory,
        title: String,
        items: [ExpenseItem],
        incomeSourceID: IncomeSource.ID? = nil
    ) -> Expense {
        Expense(id: id, date: date, category: category, title: title,
                kind: .group(items), incomeSourceID: incomeSourceID)
    }
}
