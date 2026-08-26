import Foundation

/// Календарный день в виде «2026-08-02».
///
/// Разбор и сборка идут через `DateComponents` текущего календаря с полднем
/// в качестве времени, а не через ISO-8601 в UTC. При UTC-разборе полночь
/// 1 сентября для пользователя западнее Гринвича превращается в 31 августа —
/// и трата уезжает в предыдущий месяц.
public enum DayString {
    public static func string(from date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    public static func date(from string: String, calendar: Calendar = .current) -> Date? {
        let parts = string.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }
        return calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: 12)
        )
    }
}
