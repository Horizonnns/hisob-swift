import HisobCore
import SwiftUI

/// Чип-фильтр категории со счётчиком.
struct CategoryChip: View {
    let category: ExpenseCategory
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: CategoryPresentation.symbol(category))
                    .font(.caption)
                Text(CategoryPresentation.title(category))
                    .font(DS.Typography.caption)
                Text("\(count)")
                    .font(DS.Typography.caption.monospacedDigit())
                    .foregroundStyle(isSelected ? DS.Palette.onBrand.opacity(0.7) : .secondary)
            }
            .padding(.horizontal, DS.Spacing.m)
            .padding(.vertical, DS.Spacing.s)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable(scale: 0.96))
        // Выбранный чип заливается акцентом, поэтому подпись на нём — не
        // акцентом же (иначе текст пропадает), а контрастными чернилами.
        .foregroundStyle(isSelected ? DS.Palette.onBrand : .primary)
        .dsGlass(
            cornerRadius: DS.Radius.chip,
            tint: isSelected ? DS.Palette.brand : nil,
            isInteractive: true
        )
        .animation(DS.Motion.resolved(DS.Motion.quick, reduceMotion: reduceMotion), value: isSelected)
        .accessibilityLabel(CategoryPresentation.title(category))
        .accessibilityValue("\(count)")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}
