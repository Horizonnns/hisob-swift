import SwiftUI

/// Кнопка «добавить расход» над панелью вкладок.
///
/// Штатная полка `tabViewBottomAccessory` не подошла: она рисует стеклянную
/// капсулу даже с пустым содержимым, то есть на «Аналитике» и «Настройках»
/// висела бы пустая полоса. Поэтому кнопка плавает сама по себе и живёт
/// только там, где нужна.
///
/// В шапку добавление не вернулось намеренно: это главное действие экрана, а
/// до верхнего правого угла большой палец не дотягивается.
struct AddExpenseButton: ViewModifier {
    let isVisible: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottomTrailing) {
                if isVisible {
                    button
                        .padding(.trailing, DS.Spacing.screen)
                        // Отмерено от островка: он занимает полосу 793…851 pt,
                        // кнопка встаёт над ним с зазором.
                        .padding(.bottom, 60)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(DS.Motion.resolved(DS.Motion.snappy, reduceMotion: reduceMotion),
                       value: isVisible)
    }

    private var button: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(DS.Palette.brand)
                .frame(width: 56, height: 56)
                .contentShape(.circle)
        }
        .buttonStyle(.pressable(scale: 0.94))
        .dsGlass(cornerRadius: 28, isInteractive: true)
        .accessibilityLabel(L.Month.addExpense)
    }
}

extension View {
    /// Родное сжатие панели вкладок при прокрутке. Появилось в iOS 26, ниже
    /// панель просто не сжимается.
    @ViewBuilder
    func nativeTabBarMinimize() -> some View {
        if #available(iOS 26.0, *) {
            tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }

    /// Кнопка добавления расхода над панелью вкладок.
    func addExpenseButton(isVisible: Bool, action: @escaping () -> Void) -> some View {
        modifier(AddExpenseButton(isVisible: isVisible, action: action))
    }
}
