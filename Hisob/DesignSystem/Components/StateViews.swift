import SwiftUI

/// Пустое состояние: иконка, объяснение и основное действие.
struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: DS.Spacing.m) {
            Image(systemName: symbol)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)

            Text(title).font(DS.Typography.sectionTitle)

            Text(message)
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                DSButton(title: actionTitle, symbol: "plus", kind: .primary, action: action)
                    .padding(.top, DS.Spacing.s)
                    .frame(maxWidth: 260)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.xl)
        .accessibilityElement(children: .contain)
    }
}

/// Ошибка с возможностью повторить.
struct ErrorStateView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.m) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(DS.Palette.expense)
                .symbolRenderingMode(.hierarchical)

            Text(L.Error.title).font(DS.Typography.sectionTitle)

            Text(message)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            DSButton(title: L.Error.retry, symbol: "arrow.clockwise", kind: .secondary, action: retry)
                .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.xl)
    }
}

/// Скелетон-заглушка: прямоугольник с бегущим бликом.
///
/// Спиннер на весь экран заменён скелетонами намеренно — макет не «прыгает»
/// при появлении данных.
struct SkeletonBlock: View {
    var height: CGFloat = 20
    var cornerRadius: CGFloat = DS.Radius.chip

    @State private var shift: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(DS.Palette.surfaceElevated)
            .frame(height: height)
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.12), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: proxy.size.width * 0.6)
                        .offset(x: shift * proxy.size.width)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    shift = 1.6
                }
            }
            .accessibilityHidden(true)
    }
}
