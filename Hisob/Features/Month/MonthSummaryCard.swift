import HisobCore
import SwiftUI

/// Сводка месяца одним блоком.
///
/// Четыре равные плашки занимали половину экрана, хотя смысл несут не поровну:
/// сюда заходят посмотреть остаток, остальное — справка. Поэтому остаток
/// крупно, а доход, перенос и расход — строкой под чертой.
struct MonthSummaryCard: View {
    let summary: MonthSummary
    let showsCarryover: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L.Month.remaining)
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                AmountText(
                    amount: summary.remaining,
                    currency: summary.currency,
                    font: DS.Typography.screenTitle.monospacedDigit(),
                    color: summary.remaining >= .zero ? .primary : DS.Palette.expense
                )
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            }

            Rectangle()
                .fill(DS.Palette.separator)
                .frame(height: 0.5)

            HStack(alignment: .top, spacing: DS.Spacing.m) {
                stat(L.Month.income, summary.income, "arrow.up.right", DS.Palette.income)

                if showsCarryover {
                    stat(L.Month.carryover, summary.carryover,
                         "arrow.turn.down.right", DS.Palette.carryover)
                }

                stat(L.Month.spent, summary.spent, "arrow.down.right", DS.Palette.expense)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.l)
        .dsGlass()
    }

    private func stat(_ label: String, _ amount: Money,
                      _ symbol: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: symbol)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(tint)

                Text(label)
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Text(MoneyFormat.string(amount, currency: summary.currency))
                .font(DS.Typography.caption.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(MoneyFormat.string(amount, currency: summary.currency))")
    }
}
