import Charts
import HisobCore
import SwiftUI

/// Расходы по месяцам. Текущий месяц выделен цветом бренда.
struct MonthlyBarChart: View {
    let bars: [MonthBar]
    let currency: CurrencyCode
    let highlighted: YearMonth

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            Text(L.Analytics.byMonth)
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Chart(bars) { bar in
                BarMark(
                    x: .value(L.Analytics.month, bar.month.description),
                    y: .value(L.Analytics.amount, bar.plotValue)
                )
                .foregroundStyle(bar.month == highlighted ? DS.Palette.brand : DS.Palette.brand.opacity(0.35))
                .cornerRadius(6)
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let raw = value.as(String.self), let month = YearMonth(raw) {
                            Text(Self.shortMonth(month))
                                .font(.system(size: 9, weight: .semibold))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(DS.Palette.separator)
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(Self.compact(amount))
                                .font(.system(size: 9))
                        }
                    }
                }
            }
            .frame(height: 180)
            .animation(DS.Motion.resolved(DS.Motion.smooth, reduceMotion: reduceMotion), value: bars)
        }
        .padding(DS.Spacing.l)
        .dsGlass()
        .accessibilityLabel(L.Analytics.byMonth)
    }

    private static func shortMonth(_ month: YearMonth) -> String {
        formatter.string(from: month.startDate())
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLL"
        return formatter
    }()

    /// Ось Y в тысячах: полные суммы не помещаются и мешают читать график.
    private static func compact(_ value: Double) -> String {
        value >= 1000 ? "\(Int(value / 1000))к" : "\(Int(value))"
    }
}
