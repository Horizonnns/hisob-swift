import HisobCore
import SwiftUI

/// Переключатель месяца. Стрелки дают тактильный отклик, подпись
/// перелистывается в сторону движения.
struct MonthSwitcher: View {
    let month: YearMonth
    let isCurrent: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onCurrent: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            arrow(symbol: "chevron.left", label: L.Month.previousMonth, action: onPrevious)

            VStack(spacing: 2) {
                Text(title)
                    .font(DS.Typography.sectionTitle)
                    .contentTransition(reduceMotion ? .identity : .numericText())
                    .id(month)
                    .transition(.opacity)

                Text(isCurrent ? L.Month.currentMonth : L.Month.goToCurrent)
                    .font(DS.Typography.label)
                    .foregroundStyle(isCurrent ? .secondary : DS.Palette.brand)
                    .textCase(.uppercase)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
            .onTapGesture { if !isCurrent { onCurrent() } }
            .accessibilityAddTraits(isCurrent ? [] : .isButton)
            .accessibilityHint(isCurrent ? "" : L.Month.goToCurrent)

            arrow(symbol: "chevron.right", label: L.Month.nextMonth, action: onNext)
        }
        .animation(DS.Motion.resolved(DS.Motion.snappy, reduceMotion: reduceMotion), value: month)
        .sensoryFeedback(.selection, trigger: month)
    }

    private var title: String {
        Self.formatter.string(from: month.startDate()).capitalizedFirst
    }

    /// Формат задан явно: шаблонный `.dateTime.month(.wide).year()` в русской
    /// локали добавляет «г.» — «Август 2026 г.», что в заголовке лишнее.
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    private func arrow(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: DS.IconSize.regular, weight: .semibold))
                .frame(width: 40, height: 40)
                .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .dsGlass(cornerRadius: DS.Radius.control, isInteractive: true)
        .accessibilityLabel(label)
    }
}

extension String {
    /// «август 2026» → «Август 2026».
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
