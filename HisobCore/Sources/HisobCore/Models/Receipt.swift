import Foundation

/// Вид разового поступления.
///
/// Как и `ExpenseCategory`, хранится стабильным ключом, а не подписью, и не
/// является `enum`: нераспознанный ключ остаётся валидным значением, поэтому
/// новый вид можно добавить, не ломая исторические данные.
public struct ReceiptKind: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let gift = ReceiptKind(rawValue: "gift")
    public static let refund = ReceiptKind(rawValue: "refund")
    public static let sale = ReceiptKind(rawValue: "sale")
    public static let bonus = ReceiptKind(rawValue: "bonus")
    public static let other = ReceiptKind(rawValue: "other")

    /// Встроенные виды в порядке показа в списке выбора.
    public static let builtIn: [ReceiptKind] = [.gift, .refund, .sale, .bonus, .other]
}

/// Разовое поступление: подарок, возврат долга, продажа вещи.
///
/// Оклад приходит от источника дохода и повторяется каждый месяц; такие
/// деньги — событие одного дня, и привязывать их к месту работы неверно.
/// Поэтому поступления лежат рядом с тратами и входят в доход месяца — а
/// значит, и в остаток, и в перенос на следующий месяц.
public struct Receipt: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var date: Date
    public var kind: ReceiptKind
    /// Откуда деньги: «подарок на др», «вернул Далер».
    public var title: String
    public var amount: Money

    public init(
        id: UUID = UUID(),
        date: Date,
        kind: ReceiptKind,
        title: String,
        amount: Money
    ) {
        self.id = id
        self.date = date
        self.kind = kind
        self.title = title
        self.amount = amount
    }

    public func month(calendar: Calendar = .current) -> YearMonth {
        YearMonth(date: date, calendar: calendar)
    }
}
