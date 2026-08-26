import Charts
import HisobCore
import SwiftUI

/// Кольцевая диаграмма расходов по категориям с итогом в центре.
struct CategoryDonutChart: View {
    let slices: [CategorySlice]
    let currency: CurrencyCode
    let centerLabel: String
    let centerAmount: Money
    let selected: ExpenseCategory?
    let onSelect: (ExpenseCategory) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: DS.Spacing.l) {
            chart
            legend
        }
        .padding(DS.Spacing.l)
        .dsGlass()
    }

    private var chart: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value(L.Analytics.amount, slice.plotValue),
                innerRadius: .ratio(0.64),
                angularInset: 2
            )
            .cornerRadius(6)
            .foregroundStyle(CategoryPresentation.tint(slice.category))
            .opacity(opacity(for: slice.category))
        }
        .chartLegend(.hidden)
        .frame(height: 200)
        .animation(DS.Motion.resolved(DS.Motion.smooth, reduceMotion: reduceMotion), value: slices)
        .overlay {
            VStack(spacing: 2) {
                Text(centerLabel)
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .lineLimit(1)

                AmountText(
                    amount: centerAmount,
                    currency: currency,
                    font: DS.Typography.amountCompact
                )
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
            .padding(.horizontal, DS.Spacing.xxl)
            .allowsHitTesting(false)
        }
        .accessibilityLabel(L.Analytics.byCategory)
    }

    private var legend: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), alignment: .leading),
                      GridItem(.flexible(), alignment: .leading)],
            alignment: .leading,
            spacing: DS.Spacing.s
        ) {
            ForEach(slices) { slice in
                Button {
                    onSelect(slice.category)
                } label: {
                    HStack(spacing: DS.Spacing.s) {
                        Circle()
                            .fill(CategoryPresentation.tint(slice.category))
                            .frame(width: 8, height: 8)

                        Text(slice.title)
                            .font(DS.Typography.caption)
                            .lineLimit(1)

                        Spacer(minLength: DS.Spacing.xs)

                        Text(MoneyFormat.number(slice.amount))
                            .font(DS.Typography.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .opacity(opacity(for: slice.category))
                    .contentShape(.rect)
                }
                .buttonStyle(.pressable(scale: 0.97))
                .accessibilityLabel(slice.title)
                .accessibilityValue(MoneyFormat.string(slice.amount, currency: currency))
                .accessibilityAddTraits(selected == slice.category ? [.isSelected, .isButton] : .isButton)
            }
        }
        .animation(DS.Motion.resolved(DS.Motion.quick, reduceMotion: reduceMotion), value: selected)
    }

    /// Невыбранные категории приглушаются, а не скрываются: так видно долю
    /// выбранной относительно остальных.
    private func opacity(for category: ExpenseCategory) -> Double {
        guard let selected else { return 1 }
        return selected == category ? 1 : 0.32
    }
}
