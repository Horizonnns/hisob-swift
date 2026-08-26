import Foundation

/// Денежная сумма.
///
/// Именно `Decimal`, а не `Double`: суммы вида 1 923,63 при сложении сотен
/// операций накапливают ошибку в двоичной плавающей точке. В вебе поле было
/// объявлено как `Float` — это исправлено здесь осознанно.
public typealias Money = Decimal

extension Money {
    /// Сумма из строки с точкой-разделителем, независимо от локали устройства.
    ///
    /// Нужна для импорта прод-данных и для тестов: `Decimal(string:)` без явной
    /// локали в русской локали не разберёт `"1923.63"`.
    public static func parse(_ string: String) -> Money? {
        Decimal(string: string, locale: Locale(identifier: "en_US_POSIX"))
    }
}

/// Код валюты по ISO 4217. Для нас практически всегда `TJS` (сомони).
public struct CurrencyCode: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Таджикский сомони — валюта по умолчанию.
    public static let tjs = CurrencyCode(rawValue: "TJS")
}
