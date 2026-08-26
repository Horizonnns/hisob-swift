import HisobCore
import SwiftUI

/// Сумма с перекатыванием цифр при изменении.
///
/// `numericText` — родной аналог того, как в Telegram меняются счётчики:
/// цифры не мигают, а прокручиваются. При включённом «Уменьшении движения»
/// переход отключается.
struct AmountText: View {
    let amount: Money
    let currency: CurrencyCode
    var font: Font = DS.Typography.amount
    var color: Color = .primary

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(MoneyFormat.string(amount, currency: currency))
            .font(font)
            .foregroundStyle(color)
            .contentTransition(
                reduceMotion ? .identity : .numericText(value: MoneyFormat.transitionValue(amount))
            )
            .animation(DS.Motion.resolved(DS.Motion.snappy, reduceMotion: reduceMotion), value: amount)
    }
}
