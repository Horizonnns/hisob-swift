import HisobCore
import SwiftUI

struct RootTabView: View {
    let store: LedgerStore
    let connection: ConnectionSettings

    @State private var router = AppRouter()

    var body: some View {
        TabView(selection: tabSelection) {
            NavigationStack(path: $router.monthPath) {
                MonthView(viewModel: MonthViewModel(store: store))
                    .navigationDestination(for: AppRoute.self, destination: destination)
            }
            .tabItem { Label(AppTab.month.title, systemImage: AppTab.month.symbol) }
            .tag(AppTab.month)

            NavigationStack(path: $router.analyticsPath) {
                AnalyticsView(viewModel: AnalyticsViewModel(store: store))
                    .navigationDestination(for: AppRoute.self, destination: destination)
            }
            .tabItem { Label(AppTab.analytics.title, systemImage: AppTab.analytics.symbol) }
            .tag(AppTab.analytics)

            NavigationStack(path: $router.settingsPath) {
                SettingsView(store: store, connection: connection, path: $router.settingsPath)
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
            IncomeSourcesView(viewModel: IncomeSourcesViewModel(store: store))
        }
    }
}
