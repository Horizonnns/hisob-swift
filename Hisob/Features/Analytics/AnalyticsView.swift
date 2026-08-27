import HisobCore
import SwiftUI

struct AnalyticsView: View {
    @State var viewModel: AnalyticsViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.l) {
                MonthSwitcher(
                    month: viewModel.month,
                    isCurrent: viewModel.isCurrentMonth,
                    onPrevious: viewModel.goToPreviousMonth,
                    onNext: viewModel.goToNextMonth,
                    onCurrent: viewModel.goToCurrentMonth
                )

                content
            }
            .padding(.horizontal, DS.Spacing.screen)
            .padding(.bottom, DS.Spacing.xxl)
            // Подписи оси последнего графика не должны упираться в плавающий
            // таб-бар, когда список домотан до конца.
            .safeAreaPadding(.bottom, DS.Spacing.xl)
        }
        .background(DS.Palette.background)
        .navigationTitle(L.Tab.analytics)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .animation(
            DS.Motion.resolved(DS.Motion.smooth, reduceMotion: reduceMotion),
            value: viewModel.month
        )
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            VStack(spacing: DS.Spacing.l) {
                SkeletonBlock(height: 300, cornerRadius: DS.Radius.card)
                SkeletonBlock(height: 96, cornerRadius: DS.Radius.card)
                SkeletonBlock(height: 240, cornerRadius: DS.Radius.card)
            }
            .shimmering()

        case .failed(let message):
            ErrorStateView(message: message) {
                Task { await viewModel.reload() }
            }

        case .loaded:
            if viewModel.hasExpenses {
                CategoryDonutChart(
                    slices: viewModel.slices,
                    currency: viewModel.currency,
                    centerLabel: viewModel.centerLabel,
                    centerAmount: viewModel.centerAmount,
                    selected: viewModel.selectedCategory,
                    onSelect: viewModel.toggleSelection
                )
            } else {
                EmptyStateView(
                    symbol: "chart.pie",
                    title: L.Analytics.emptyTitle,
                    message: L.Analytics.emptyMessage
                )
                .dsGlass()
            }

            if !viewModel.incomeShares.isEmpty {
                IncomeBreakdownCard(
                    shares: viewModel.incomeShares,
                    total: viewModel.summary.income,
                    currency: viewModel.currency
                )
            }

            MonthlyBarChart(
                bars: viewModel.monthBars,
                currency: viewModel.currency,
                highlighted: viewModel.month
            )
        }
    }
}
