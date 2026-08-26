import Foundation

/// Запись в истории оклада: с какой даты действует какая сумма.
public struct SalaryEntry: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    /// Точная дата, с которой действует оклад — показывается пользователю
    /// («с 2026-06-10»).
    public var effectiveFrom: Date
    public var amount: Money

    public init(id: UUID = UUID(), effectiveFrom: Date, amount: Money) {
        self.id = id
        self.effectiveFrom = effectiveFrom
        self.amount = amount
    }

    /// Месяц, начиная с которого действует оклад.
    ///
    /// Гранулярность намеренно месячная: оклад, назначенный 10 июня, считается
    /// действующим за весь июнь. Так было в веб-версии (сравнение с концом
    /// месяца), и менять это правило при переносе оснований нет.
    public func effectiveMonth(calendar: Calendar = .current) -> YearMonth {
        YearMonth(date: effectiveFrom, calendar: calendar)
    }
}

/// Источник дохода — место работы или проект, с которого приходит оклад.
///
/// Ключевое отличие от веб-версии: источник больше не владеет расходами.
/// Он отвечает только на вопрос «сколько денег принёс в этом месяце».
public struct IncomeSource: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var role: String
    public var salaryHistory: [SalaryEntry]

    /// Последний месяц, за который источник приносил доход, включительно.
    ///
    /// `nil` — работа продолжается. Без этого поля в вебе оклад завершившейся
    /// работы продолжал начисляться бесконечно вперёд: `salaryAtMonth` брала
    /// последнюю подходящую запись, а даты окончания у оклада не было. Пока
    /// проект был один, это не бросалось в глаза; при суммировании нескольких
    /// источников давало бы фантомный доход каждый месяц.
    public var endedAt: YearMonth?

    public init(
        id: UUID = UUID(),
        name: String,
        role: String = "",
        salaryHistory: [SalaryEntry] = [],
        endedAt: YearMonth? = nil
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.salaryHistory = salaryHistory
        self.endedAt = endedAt
    }

    /// Приносил ли источник доход в указанном месяце.
    public func isActive(in month: YearMonth, calendar: Calendar = .current) -> Bool {
        if let endedAt, month > endedAt { return false }
        guard let first = firstMonth(calendar: calendar) else { return false }
        return month >= first
    }

    /// Первый месяц, за который назначен оклад.
    public func firstMonth(calendar: Calendar = .current) -> YearMonth? {
        salaryHistory.map { $0.effectiveMonth(calendar: calendar) }.min()
    }

    /// Оклад за указанный месяц: последняя запись, вступившая в силу не позже
    /// этого месяца. После `endedAt` — ноль.
    public func salary(in month: YearMonth, calendar: Calendar = .current) -> Money {
        if let endedAt, month > endedAt { return .zero }
        return salaryHistory
            .filter { $0.effectiveMonth(calendar: calendar) <= month }
            .max { $0.effectiveMonth(calendar: calendar) < $1.effectiveMonth(calendar: calendar) }?
            .amount ?? .zero
    }

    /// История оклада по возрастанию даты — порядок для показа в UI.
    public func sortedHistory() -> [SalaryEntry] {
        salaryHistory.sorted { $0.effectiveFrom < $1.effectiveFrom }
    }
}
