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
    /// Перевод угла в категорию — знает только вью-модель.
    let categoryAt: (Double) -> ExpenseCategory?

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
                innerRadius: .ratio(0.62),
                angularInset: 2
            )
            .cornerRadius(6)
            .foregroundStyle(CategoryPresentation.tint(slice.category))
            .opacity(opacity(for: slice.category))
        }
        .chartLegend(.hidden)
        // Диаграмма — главное на экране, ей и место. И по ней можно попасть
        // пальцем: раньше выбрать категорию можно было только через легенду.
        .frame(height: 300)
        // `chartAngleSelection` молчит и на тап, и на драг, поэтому попадание
        // считаем сами: точнее и без сюрпризов при смене SDK.
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let anchor = proxy.plotFrame {
                    let frame = geometry[anchor]
                    Color.clear
                        .contentShape(.rect)
                        .onTapGesture { location in
                            select(at: location, in: frame)
                        }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selected)
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
            .animation(DS.Motion.resolved(DS.Motion.quick, reduceMotion: reduceMotion), value: selected)
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

    /// Тап по кольцу выбирает сектор, тап по «дырке» и мимо кольца — снимает
    /// выбор. SectorMark считает угол от 12 часов по часовой стрелке.
    private func select(at location: CGPoint, in frame: CGRect) {
        let dx = location.x - frame.midX
        let dy = location.y - frame.midY
        let outerRadius = min(frame.width, frame.height) / 2
        let radius = (dx * dx + dy * dy).squareRoot()

        guard radius >= outerRadius * 0.62, radius <= outerRadius else {
            if let selected { onSelect(selected) }
            return
        }

        var angle = atan2(dx, -dy)
        if angle < 0 { angle += 2 * .pi }

        let total = slices.reduce(0) { $0 + $1.plotValue }
        guard total > 0, let category = categoryAt(angle / (2 * .pi) * total) else { return }
        onSelect(category)
    }

    /// Невыбранные категории приглушаются, а не скрываются: так видно долю
    /// выбранной относительно остальных.
    private func opacity(for category: ExpenseCategory) -> Double {
        guard let selected else { return 1 }
        return selected == category ? 1 : 0.32
    }
}
