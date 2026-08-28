import Foundation
import HisobCore

extension YearMonth {
    /// «Август 2026».
    ///
    /// Формат задан явно: шаблонный `.dateTime.month(.wide).year()` в русской
    /// локали добавляет «г.» — «Август 2026 г.», что в заголовке лишнее.
    var displayTitle: String {
        Self.titleFormatter.string(from: startDate()).capitalizedFirst
    }

    private static let titleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()
}

extension String {
    /// «август 2026» → «Август 2026».
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
