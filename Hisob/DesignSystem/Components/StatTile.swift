import HisobCore
import SwiftUI

/// Плашка статистики: подпись, сумма, иконка.
struct StatTile: View {
    let label: String
    let amount: Money
    let currency: CurrencyCode
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack(spacing: DS.Spacing.s) {
                Image(systemName: symbol)
                    .font(.system(size: DS.IconSize.tile, weight: .semibold))
                    .foregroundStyle(tint)
                    .symbolRenderingMode(.hierarchical)

                Text(label)
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            AmountText(amount: amount, currency: currency)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.l)
        .dsGlass(cornerRadius: DS.Radius.tile)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(MoneyFormat.string(amount, currency: currency))")
    }
}
