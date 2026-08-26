import Foundation
import HisobCore

/// Форматирование сумм. Разделитель разрядов — как в веб-версии: «10 120 TJS».
enum MoneyFormat {
    private static let locale = Locale(identifier: "ru_RU")

    static func string(_ amount: Money, currency: CurrencyCode) -> String {
        "\(number(amount)) \(currency.rawValue)"
    }

    /// Только число, без кода валюты — для осей графиков и компактных мест.
    static func number(_ amount: Money) -> String {
        amount.formatted(
            .number
                .precision(.fractionLength(0...2))
                .locale(locale)
        )
    }

    /// Значение для `contentTransition(.numericText(value:))`: перекатывание
    /// цифр должно знать направление изменения.
    static func transitionValue(_ amount: Money) -> Double {
        NSDecimalNumber(decimal: amount).doubleValue
    }
}
