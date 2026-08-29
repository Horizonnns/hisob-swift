import HisobCore
import SwiftUI

/// Строка с названием месяца и возвратом к текущему.
///
/// Раньше месяц жил отдельной строкой со стрелками над содержимым. Она
/// занимала место и дублировала то, о чём карточка и так рассказывает,
/// поэтому переехала внутрь карточки, а листают месяцы свайпом.
struct MonthTitleRow: View {
    let month: YearMonth
    let isCurrent: Bool
    let onCurrent: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
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
}

/// Листание месяцев горизонтальной протяжкой.
private struct MonthPaging: ViewModifier {
    let onPrevious: () -> Void
    let onNext: () -> Void
    let attachToAncestor: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGFloat = 0
    @State private var switchCount = 0

    /// Порог срабатывания. Меньше — и месяц будет перелистываться от
    /// случайного касания при прокрутке.
    private let threshold: CGFloat = 56

    func body(content: Content) -> some View {
        content
            .offset(x: dragOffset)
            // Подложкой, а не наложением: наложение перехватывало касания, и
            // кнопки под ним переставали нажиматься.
            .background {
                HorizontalSwipe(onChange: follow, onEnd: finish,
                                attachToAncestor: attachToAncestor)
            }
            .sensoryFeedback(.selection, trigger: switchCount)
            // Жест недоступен VoiceOver, поэтому те же действия — отдельными
            // пунктами ротора.
            .accessibilityAction(named: L.Month.previousMonth, onPrevious)
            .accessibilityAction(named: L.Month.nextMonth, onNext)
    }

    private func follow(_ dx: CGFloat) {
        // Идём за пальцем с сопротивлением: видно, что жест распознан, но
        // содержимое не убегает с экрана.
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
}

extension View {
    /// Свайп влево — следующий месяц, вправо — предыдущий.
    ///
    /// `attachToAncestor` нужен там, где поверх содержимого лежит свой
    /// обработчик касаний — например прозрачный слой выбора сектора диаграммы.
    func monthPaging(
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void,
        attachToAncestor: Bool = false
    ) -> some View {
        modifier(MonthPaging(onPrevious: onPrevious, onNext: onNext,
                             attachToAncestor: attachToAncestor))
    }
}
