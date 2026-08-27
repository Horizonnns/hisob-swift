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

/// Заглушка-плашка с бегущим бликом.
///
/// Скелетоны повторяют форму того, что загрузится: место под иконку, две
/// строки текста, сумму справа. Одинаковые прямоугольники ничего не говорят
/// о будущем содержимом, и макет прыгает, когда данные приходят.
struct SkeletonBlock: View {
    var width: CGFloat?
    var height: CGFloat = 12
    var cornerRadius: CGFloat = 6

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(DS.Palette.surfaceElevated)
            .frame(width: width, height: height)
            .accessibilityHidden(true)
    }
}

/// Бегущий блик поверх группы заглушек.
///
/// Один общий блик на весь список выглядит цельно; отдельная анимация
/// у каждой плашки создаёт рябь.
private struct ShimmerOverlay: ViewModifier {
    @State private var shift: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.06), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: proxy.size.width * 0.5)
                        .offset(x: shift * proxy.size.width * 1.5)
                    }
                    .allowsHitTesting(false)
                }
            }
            .mask { content }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    shift = 1.2
                }
            }
    }
}

extension View {
    /// Пускает по содержимому бегущий блик — для групп заглушек.
    func shimmering() -> some View {
        modifier(ShimmerOverlay())
    }
}

/// Заглушка строки списка: иконка, название, подпись, сумма.
struct RowSkeleton: View {
    /// Разная ширина у соседних строк — иначе список выглядит печатным бланком.
    var titleWidth: CGFloat = 140
    var amountWidth: CGFloat = 64

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            SkeletonBlock(width: 32, height: 32, cornerRadius: DS.Radius.chip)

            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                SkeletonBlock(width: titleWidth, height: 12)
                SkeletonBlock(width: 64, height: 10)
            }

            Spacer(minLength: DS.Spacing.s)

            SkeletonBlock(width: amountWidth, height: 14)
        }
        .padding(.vertical, DS.Spacing.s)
    }
}

/// Заглушка сводки месяца — повторяет форму `MonthSummaryCard`.
struct SummarySkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                SkeletonBlock(width: 68, height: 9)
                SkeletonBlock(width: 210, height: 34, cornerRadius: 9)
            }

            Rectangle()
                .fill(DS.Palette.separator)
                .frame(height: 0.5)

            HStack(alignment: .top, spacing: DS.Spacing.m) {
                ForEach([84.0, 78.0, 92.0], id: \.self) { width in
                    VStack(alignment: .leading, spacing: DS.Spacing.s) {
                        SkeletonBlock(width: width * 0.8, height: 9)
                        SkeletonBlock(width: width, height: 12)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.l)
        .dsGlass()
    }
}

/// Заглушка списка трат: сводка, чипы категорий и строки по дням.
struct MonthSkeleton: View {
    /// Ширины подобраны неровно — так список читается как настоящий.
    private let widths: [(CGFloat, CGFloat)] = [
        (150, 62), (108, 74), (176, 56), (126, 68), (142, 60), (96, 78)
    ]

    var body: some View {
        VStack(spacing: DS.Spacing.l) {
            SummarySkeleton()

            HStack(spacing: DS.Spacing.s) {
                ForEach([104.0, 82.0, 96.0], id: \.self) { width in
                    SkeletonBlock(width: width, height: 32, cornerRadius: DS.Radius.chip)
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(widths.enumerated()), id: \.offset) { index, size in
                    // Заголовок дня — перед первой строкой и через каждые две:
                    // ровно так список выглядит с настоящими данными.
                    if index % 2 == 0 {
                        HStack {
                            SkeletonBlock(width: 86, height: 9)
                            Spacer(minLength: 0)
                            SkeletonBlock(width: 54, height: 9)
                        }
                        .padding(.top, index == 0 ? 0 : DS.Spacing.l)
                        .padding(.bottom, DS.Spacing.s)
                    }

                    RowSkeleton(titleWidth: size.0, amountWidth: size.1)
                    Divider().overlay(DS.Palette.separator)
                }
            }
        }
        .shimmering()
        .accessibilityHidden(true)
    }
}

/// Заглушка списка источников дохода.
struct SourcesSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach([(120.0, 86.0), (96.0, 64.0)], id: \.0) { size in
                RowSkeleton(titleWidth: size.0, amountWidth: size.1)
                Divider().overlay(DS.Palette.separator)
            }
        }
        .shimmering()
        .accessibilityHidden(true)
    }
}
