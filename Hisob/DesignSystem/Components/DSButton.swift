import SwiftUI

/// Основная кнопка приложения.
struct DSButton: View {
    enum Kind {
        case primary, secondary, ghost, danger
    }

    let title: String
    var symbol: String?
    var kind: Kind = .primary
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.s) {
                if isLoading {
                    ProgressView().controlSize(.small)
                } else if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: DS.IconSize.regular, weight: .semibold))
                }
                Text(title).font(DS.Typography.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.m)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable(scale: 0.97))
        .foregroundStyle(foreground)
        .background(background, in: RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous))
        .disabled(isLoading)
    }

    private var foreground: Color {
        switch kind {
        case .primary: .white
        case .secondary: .primary
        case .ghost: DS.Palette.brand
        case .danger: .white
        }
    }

    private var background: Color {
        switch kind {
        case .primary: DS.Palette.brand
        case .secondary: DS.Palette.surfaceElevated
        case .ghost: .clear
        case .danger: DS.Palette.expense
        }
    }
}
