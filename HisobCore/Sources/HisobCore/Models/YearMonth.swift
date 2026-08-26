import Foundation

/// Календарный месяц — «2026-08».
///
/// Заменяет строковые операции из веб-версии (`date.startsWith(month)`,
/// сравнение с `"\(month)-31"`, `shiftMonth` через `date-fns`). Арифметика
/// и сравнение идут по порядковому номеру месяца, поэтому несуществующих
/// дат вроде 31 февраля здесь возникнуть не может в принципе.
public struct YearMonth: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let year: Int
    /// 1...12
    public let month: Int

    public init(year: Int, month: Int) {
        precondition((1...12).contains(month), "Месяц вне диапазона 1...12: \(month)")
        self.year = year
        self.month = month
    }

    // MARK: - Арифметика

    /// Порядковый номер месяца от нулевого года — основа сравнения и сдвигов.
    private var ordinal: Int { year * 12 + (month - 1) }

    private init(ordinal: Int) {
        self.year = Int((Double(ordinal) / 12).rounded(.down))
        self.month = ordinal - self.year * 12 + 1
    }

    /// Месяц, сдвинутый на `months` вперёд (или назад при отрицательном значении).
    public func adding(months: Int) -> YearMonth {
        YearMonth(ordinal: ordinal + months)
    }

    /// Количество месяцев от `other` до `self`.
    public func months(since other: YearMonth) -> Int {
        ordinal - other.ordinal
    }

    public static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        lhs.ordinal < rhs.ordinal
    }

    // MARK: - Календарь

    public init(date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month], from: date)
        self.init(year: parts.year ?? 1, month: parts.month ?? 1)
    }

    /// Первое число этого месяца.
    public func startDate(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? .distantPast
    }

    /// Содержит ли месяц указанную дату.
    public func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        YearMonth(date: date, calendar: calendar) == self
    }

    public static func current(calendar: Calendar = .current, now: Date = .now) -> YearMonth {
        YearMonth(date: now, calendar: calendar)
    }

    // MARK: - Текст

    /// Канонический вид «2026-08» — он же формат хранения и импорта.
    public var description: String {
        String(format: "%04d-%02d", year, month)
    }

    /// Разбирает «2026-08», а также «2026-08-14» (день игнорируется).
    public init?(_ string: String) {
        let parts = string.split(separator: "-")
        guard parts.count >= 2,
              let year = Int(parts[0]), let month = Int(parts[1]),
              (1...12).contains(month)
        else { return nil }
        self.init(year: year, month: month)
    }
}

extension YearMonth: Codable {
    /// Кодируется строкой «2026-08» — так дампы и JSON остаются читаемыми.
    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let value = YearMonth(raw) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Некорректный месяц: \(raw)")
            )
        }
        self = value
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

extension YearMonth: Strideable {
    public func distance(to other: YearMonth) -> Int { other.months(since: self) }
    public func advanced(by n: Int) -> YearMonth { adding(months: n) }
}
