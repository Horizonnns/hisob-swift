import Foundation

/// Формы данных на проводе.
///
/// Суммы — строки: JSON-число клиент прочитал бы в `Double`, и двоичная
/// погрешность приехала бы вместе с данными.
struct LedgerDTO: Codable, Sendable {
    var currency: String
    var sources: [IncomeSourceDTO]
    var expenses: [ExpenseDTO]
    var receipts: [ReceiptDTO]

    /// Сервер старой версии поля не пришлёт — читаем как пустой список,
    /// иначе приложение перестало бы открываться после обновления клиента.
    enum CodingKeys: String, CodingKey {
        case currency, sources, expenses, receipts
    }

    init(currency: String, sources: [IncomeSourceDTO], expenses: [ExpenseDTO], receipts: [ReceiptDTO] = []) {
        self.currency = currency
        self.sources = sources
        self.expenses = expenses
        self.receipts = receipts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currency = try container.decode(String.self, forKey: .currency)
        sources = try container.decode([IncomeSourceDTO].self, forKey: .sources)
        expenses = try container.decode([ExpenseDTO].self, forKey: .expenses)
        receipts = try container.decodeIfPresent([ReceiptDTO].self, forKey: .receipts) ?? []
    }
}

struct ReceiptDTO: Codable, Sendable {
    var id: WireUUID
    var date: String
    var kind: String
    var title: String
    var amount: String
}

struct IncomeSourceDTO: Codable, Sendable {
    var id: WireUUID
    var name: String
    var role: String
    /// «2026-07» либо null.
    var endedAt: String?
    var salaries: [SalaryEntryDTO]
}

struct SalaryEntryDTO: Codable, Sendable {
    var id: WireUUID
    var effectiveFrom: String
    var amount: String
}

struct ExpenseDTO: Codable, Sendable {
    var id: WireUUID
    var date: String
    var category: String
    var title: String
    /// Заполнено — одиночная трата; null — группа.
    var amount: String?
    var items: [ExpenseItemDTO]
    var incomeSourceId: WireUUID?
}

struct ExpenseItemDTO: Codable, Sendable {
    var id: WireUUID
    var amount: String
    var title: String
}

// MARK: - Домен → DTO

extension ExpenseDTO {
    init(_ expense: Expense, calendar: Calendar) {
        self.id = WireUUID(expense.id)
        self.date = DayString.string(from: expense.date, calendar: calendar)
        self.category = expense.category.rawValue
        self.title = expense.title
        self.incomeSourceId = expense.incomeSourceID.map(WireUUID.init)

        switch expense.kind {
        case .single(let amount):
            self.amount = MoneyWire.string(amount)
            self.items = []
        case .group(let items):
            self.amount = nil
            self.items = items.map {
                ExpenseItemDTO(id: WireUUID($0.id), amount: MoneyWire.string($0.amount), title: $0.title)
            }
        }
    }
}

extension ReceiptDTO {
    init(_ receipt: Receipt, calendar: Calendar) {
        self.id = WireUUID(receipt.id)
        self.date = DayString.string(from: receipt.date, calendar: calendar)
        self.kind = receipt.kind.rawValue
        self.title = receipt.title
        self.amount = MoneyWire.string(receipt.amount)
    }
}

extension ReceiptDTO {
    func toDomain(calendar: Calendar) throws -> Receipt {
        guard let date = DayString.date(from: date, calendar: calendar) else {
            throw DTOMappingError.invalidDate(self.date)
        }
        guard let value = Money.parse(amount) else {
            throw DTOMappingError.invalidAmount(amount)
        }
        return Receipt(id: id.value, date: date, kind: ReceiptKind(rawValue: kind),
                       title: title, amount: value)
    }
}

extension IncomeSourceDTO {
    init(_ source: IncomeSource, calendar: Calendar) {
        self.id = WireUUID(source.id)
        self.name = source.name
        self.role = source.role
        self.endedAt = source.endedAt?.description
        self.salaries = source.sortedHistory().map {
            SalaryEntryDTO(
                id: WireUUID($0.id),
                effectiveFrom: DayString.string(from: $0.effectiveFrom, calendar: calendar),
                amount: MoneyWire.string($0.amount)
            )
        }
    }
}

// MARK: - DTO → домен

enum DTOMappingError: Error, Equatable {
    case invalidDate(String)
    case invalidAmount(String)
    case invalidMonth(String)
    /// Сервер прислал запись, где сумма и позиции заданы одновременно
    /// либо не заданы вовсе.
    case ambiguousExpenseKind(UUID)
}

extension ExpenseDTO {
    func toDomain(calendar: Calendar) throws -> Expense {
        guard let date = DayString.date(from: date, calendar: calendar) else {
            throw DTOMappingError.invalidDate(self.date)
        }

        let kind: ExpenseKind
        switch (amount, items.isEmpty) {
        case (let raw?, true):
            guard let value = Money.parse(raw) else {
                throw DTOMappingError.invalidAmount(raw)
            }
            kind = .single(value)
        case (nil, false):
            kind = .group(try items.map { try $0.toDomain() })
        default:
            throw DTOMappingError.ambiguousExpenseKind(id.value)
        }

        return Expense(
            id: id.value,
            date: date,
            category: ExpenseCategory(rawValue: category),
            title: title,
            kind: kind,
            incomeSourceID: incomeSourceId?.value
        )
    }
}

extension ExpenseItemDTO {
    func toDomain() throws -> ExpenseItem {
        guard let value = Money.parse(amount) else {
            throw DTOMappingError.invalidAmount(amount)
        }
        return ExpenseItem(id: id.value, amount: value, title: title)
    }
}

extension SalaryEntryDTO {
    func toDomain(calendar: Calendar) throws -> SalaryEntry {
        guard let date = DayString.date(from: effectiveFrom, calendar: calendar) else {
            throw DTOMappingError.invalidDate(effectiveFrom)
        }
        guard let value = Money.parse(amount) else {
            throw DTOMappingError.invalidAmount(amount)
        }
        return SalaryEntry(id: id.value, effectiveFrom: date, amount: value)
    }
}

extension IncomeSourceDTO {
    func toDomain(calendar: Calendar) throws -> IncomeSource {
        var ended: YearMonth?
        if let endedAt {
            guard let month = YearMonth(endedAt) else {
                throw DTOMappingError.invalidMonth(endedAt)
            }
            ended = month
        }
        return IncomeSource(
            id: id.value,
            name: name,
            role: role,
            salaryHistory: try salaries.map { try $0.toDomain(calendar: calendar) },
            endedAt: ended
        )
    }
}

extension LedgerDTO {
    func toDomain(calendar: Calendar) throws -> Ledger {
        Ledger(
            currency: CurrencyCode(rawValue: currency),
            sources: try sources.map { try $0.toDomain(calendar: calendar) },
            expenses: try expenses.map { try $0.toDomain(calendar: calendar) },
            receipts: try receipts.map { try $0.toDomain(calendar: calendar) }
        )
    }
}

/// Сумма на проводе: ровно два знака после точки, разделитель — точка,
/// независимо от локали устройства.
enum MoneyWire {
    static func string(_ amount: Money) -> String {
        var value = amount
        var rounded = Money.zero
        NSDecimalRound(&rounded, &value, 2, .plain)
        return NSDecimalNumber(decimal: rounded)
            .description(withLocale: Locale(identifier: "en_US_POSIX"))
    }
}
