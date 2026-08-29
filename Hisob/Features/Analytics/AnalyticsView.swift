import HisobCore
import SwiftUI

struct AnalyticsView: View {
    @State var viewModel: AnalyticsViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.l) {
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
                    month: viewModel.month,
                    isCurrent: viewModel.isCurrentMonth,
                    onCurrent: viewModel.goToCurrentMonth,
                    slices: viewModel.slices,
                    currency: viewModel.currency,
                    centerLabel: viewModel.centerLabel,
                    centerAmount: viewModel.centerAmount,
                    selected: viewModel.selectedCategory,
                    onSelect: viewModel.toggleSelection,
                    categoryAt: viewModel.category(atAngleValue:)
                )
                // Жест на самой карточке, а не на содержимом экрана: подложка
                // под карточками касаний не получает — их забирает стекло.
                .monthPaging(
                    onPrevious: viewModel.goToPreviousMonth,
                    onNext: viewModel.goToNextMonth,
                    attachToAncestor: true
                )
            } else {
                VStack(spacing: DS.Spacing.l) {
                    MonthTitleRow(
                        month: viewModel.month,
                        isCurrent: viewModel.isCurrentMonth,
                        onCurrent: viewModel.goToCurrentMonth
                    )

                    EmptyStateView(
                        symbol: "chart.pie",
                        title: L.Analytics.emptyTitle,
                        message: L.Analytics.emptyMessage
                    )
                }
                .padding(DS.Spacing.l)
                .dsGlass()
                // И в пустом месяце тоже, иначе с него нечем было бы уйти.
                .monthPaging(
                    onPrevious: viewModel.goToPreviousMonth,
                    onNext: viewModel.goToNextMonth,
                    attachToAncestor: true
                )
            }

            if !viewModel.incomeShares.isEmpty || !viewModel.receiptShares.isEmpty {
                IncomeBreakdownCard(
                    shares: viewModel.incomeShares,
                    receipts: viewModel.receiptShares,
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
