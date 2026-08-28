import HisobCore
import SwiftUI

/// Сводка месяца одним блоком.
///
/// Четыре равные плашки занимали половину экрана, хотя смысл несут не поровну:
/// сюда заходят посмотреть остаток, остальное — справка. Поэтому остаток
/// крупно, а доход, перенос и расход — строкой под чертой.
///
/// Название месяца тоже здесь: отдельная строка со стрелками над карточкой
/// занимала место и дублировала то, о чём карточка и так рассказывает.
/// Переключают месяц свайпом по самой карточке.
struct MonthSummaryCard: View {
    let month: YearMonth
    let isCurrent: Bool
    let summary: MonthSummary
    let showsCarryover: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onCurrent: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Смещение под пальцем. Карточка идёт за ним с сопротивлением — так видно,
    /// что жест распознан, но она не убегает с экрана.
    @State private var dragOffset: CGFloat = 0
    @State private var switchCount = 0

    /// Порог срабатывания. Меньше — и месяц будет перелистываться от случайного
    /// касания при прокрутке списка.
    private let threshold: CGFloat = 56

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            monthRow

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
        .offset(x: dragOffset)
        // Подложкой, а не наложением: наложение перехватывало касания, и
        // кнопка «к текущему» под ним переставала нажиматься.
        .background {
            HorizontalSwipe(onChange: follow, onEnd: finish)
        }
        .sensoryFeedback(.selection, trigger: switchCount)
        // Жест недоступен VoiceOver, поэтому те же действия — отдельными
        // пунктами ротора.
        .accessibilityAction(named: L.Month.previousMonth, onPrevious)
        .accessibilityAction(named: L.Month.nextMonth, onNext)
    }

    private var monthRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.s) {
            Text(month.displayTitle)
                .font(DS.Typography.sectionTitle)
                .contentTransition(reduceMotion ? .identity : .numericText())
                .id(month)
                .transition(.opacity)

            Spacer(minLength: DS.Spacing.s)

            // Кнопка появляется только когда есть куда возвращаться: на
            // текущем месяце подпись «текущий» ничего не сообщала бы.
            if !isCurrent {
                Button(action: onCurrent) {
                    Text(L.Month.goToCurrent)
                        .font(DS.Typography.label)
                        .textCase(.uppercase)
                        .foregroundStyle(DS.Palette.brand)
                        .padding(.horizontal, DS.Spacing.s)
                        .padding(.vertical, DS.Spacing.xs)
                        .contentShape(.capsule)
                }
                .buttonStyle(.pressable(scale: 0.96))
                .dsGlass(cornerRadius: DS.Radius.chip, isInteractive: true)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(DS.Motion.resolved(DS.Motion.snappy, reduceMotion: reduceMotion), value: month)
    }

    /// Смена месяца свайпом по карточке: влево — вперёд, вправо — назад, как
    /// и стрелки над ней.
    private func follow(_ dx: CGFloat) {
        // Идём за пальцем с сопротивлением: видно, что жест распознан, но
        // карточка не убегает с экрана.
        dragOffset = dx / 3
    }

    private func finish(_ dx: CGFloat) {
        withAnimation(DS.Motion.resolved(DS.Motion.snappy, reduceMotion: reduceMotion)) {
            dragOffset = 0
        }

        guard abs(dx) > threshold else { return }

        switchCount += 1
        if dx < 0 { onNext() } else { onPrevious() }
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
