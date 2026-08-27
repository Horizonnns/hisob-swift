import HisobCore
import SwiftUI

/// Строка траты: дата, категория, описание, сумма.
/// Групповая трата разворачивается по нажатию.
struct ExpenseRow: View {
    let expense: Expense
    let currency: CurrencyCode
    @Binding var expandedIDs: Set<Expense.ID>

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isExpanded: Bool { expandedIDs.contains(expense.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            // Групповая трата раскрывается кнопкой, а не onTapGesture:
            // внутри List жест конфликтует со swipe-действиями строки,
            // и заодно VoiceOver объявляет элемент кнопкой.
            if expense.isGroup {
                Button(action: toggle) { header }
                    .buttonStyle(.plain)
                    .accessibilityHint(isExpanded ? L.Month.collapseGroup : L.Month.expandGroup)
            } else {
                header
            }

            if expense.isGroup, isExpanded {
                items
                    // Только прозрачность. Со сдвигом сверху позиции наезжали
                    // на шапку — раскрытие читалось как рывок, а не как рост.
                    .transition(.opacity)
            }
        }
        .padding(.vertical, DS.Spacing.s)
    }

    /// Позиции группы — вложенной карточкой, а не плоским серым списком:
    /// так видно, где группа началась и где кончилась.
    private var items: some View {
        VStack(spacing: 0) {
            ForEach(Array(expense.items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Rectangle()
                        .fill(DS.Palette.separator)
                        .frame(height: 0.5)
                        .padding(.leading, DS.Spacing.m)
                }

                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.m) {
                    Text(item.title)
                        .font(DS.Typography.caption)
                        .lineLimit(2)

                    Spacer(minLength: DS.Spacing.s)

                    Text(MoneyFormat.number(item.amount))
                        .font(DS.Typography.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DS.Spacing.m)
                .padding(.vertical, DS.Spacing.s)
            }
        }
        .background(
            DS.Palette.surfaceElevated,
            in: RoundedRectangle(cornerRadius: DS.Radius.tile, style: .continuous)
        )
        // 44 = ширина иконки (32) плюс отступ до заголовка (12): позиции
        // встают ровно под названием группы.
        .padding(.leading, 44)
    }

    private func toggle() {
        withAnimation(DS.Motion.resolved(DS.Motion.snappy, reduceMotion: reduceMotion)) {
            if isExpanded { expandedIDs.remove(expense.id) } else { expandedIDs.insert(expense.id) }
        }
    }

    private var header: some View {
        HStack(spacing: DS.Spacing.m) {
                icon

                // Дата ушла в заголовок дня. У обычной траты второй строки
                // теперь нет вовсе — строка стала ниже и спокойнее.
                VStack(alignment: .leading, spacing: 2) {
                    Text(expense.title.isEmpty ? CategoryPresentation.title(expense.category) : expense.title)
                        .font(DS.Typography.body)
                        .lineLimit(1)

                    if expense.isGroup {
                        Text("\(expense.items.count) \(L.Month.positions)")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: DS.Spacing.s)

                AmountText(
                    amount: expense.total,
                    currency: currency,
                    font: DS.Typography.amountCompact
                )
                .lineLimit(1)

                if expense.isGroup {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
        .contentShape(.rect)
    }

    private var icon: some View {
        Image(systemName: CategoryPresentation.symbol(expense.category))
            .font(.system(size: DS.IconSize.regular, weight: .medium))
            .foregroundStyle(CategoryPresentation.tint(expense.category))
            .frame(width: 32, height: 32)
            .background(
                CategoryPresentation.tint(expense.category).opacity(0.14),
                in: RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
            )
    }
}
