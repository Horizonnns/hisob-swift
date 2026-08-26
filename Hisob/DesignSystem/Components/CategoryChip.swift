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
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DS.Spacing.m)
            .padding(.vertical, DS.Spacing.s)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable(scale: 0.96))
        .foregroundStyle(isSelected ? DS.Palette.brand : .primary)
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
