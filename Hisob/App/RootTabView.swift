import HisobCore
import SwiftUI

struct RootTabView: View {
    let repository: any LedgerRepository

    @State private var router = AppRouter()

    var body: some View {
        TabView(selection: tabSelection) {
            NavigationStack(path: $router.monthPath) {
                MonthView(viewModel: MonthViewModel(repository: repository))
                    .navigationDestination(for: AppRoute.self, destination: destination)
            }
            .tabItem { Label(AppTab.month.title, systemImage: AppTab.month.symbol) }
            .tag(AppTab.month)

            NavigationStack(path: $router.analyticsPath) {
                PlaceholderView(title: L.Tab.analytics, symbol: AppTab.analytics.symbol)
                    .navigationDestination(for: AppRoute.self, destination: destination)
            }
            .tabItem { Label(AppTab.analytics.title, systemImage: AppTab.analytics.symbol) }
            .tag(AppTab.analytics)

            NavigationStack(path: $router.settingsPath) {
                PlaceholderView(title: L.Tab.settings, symbol: AppTab.settings.symbol)
                    .navigationDestination(for: AppRoute.self, destination: destination)
            }
            .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.symbol) }
            .tag(AppTab.settings)
        }
        .tint(DS.Palette.brand)
    }

    /// Перехватывает выбор таба, чтобы повторное нажатие сбрасывало стек.
    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { router.selectedTab },
            set: { newValue in
                if newValue == router.selectedTab {
                    router.popToRoot(newValue)
                }
                router.selectedTab = newValue
            }
        )
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .incomeSources:
            PlaceholderView(title: L.Tab.settings, symbol: "briefcase")
        case .expenseDetails:
            PlaceholderView(title: L.Month.expenses, symbol: "list.bullet")
        }
    }
}

/// Заглушка для ещё не собранных экранов.
struct PlaceholderView: View {
    let title: String
    let symbol: String

    var body: some View {
        EmptyStateView(symbol: symbol, title: title, message: L.Common.comingSoon)
            .frame(maxHeight: .infinity)
            .background(DS.Palette.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}
