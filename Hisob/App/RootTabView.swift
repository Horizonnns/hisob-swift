import HisobCore
import SwiftUI

struct RootTabView: View {
    let store: LedgerStore
    let connection: ConnectionSettings
    let lock: BiometricLock

    @State private var router = AppRouter()
    /// Вью-модель месяца живёт здесь, потому что кнопка добавления вынесена
    /// из экрана к панели вкладок и должна класть трату в тот же месяц.
    @State private var monthViewModel: MonthViewModel
    @State private var isAddingExpense = false

    init(store: LedgerStore, connection: ConnectionSettings, lock: BiometricLock) {
        self.store = store
        self.connection = connection
        self.lock = lock
        _monthViewModel = State(initialValue: MonthViewModel(store: store))
    }

    var body: some View {
        TabView(selection: tabSelection) {
            NavigationStack(path: $router.monthPath) {
                MonthView(viewModel: monthViewModel)
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
                SettingsView(store: store, connection: connection, lock: lock, path: $router.settingsPath)
                    .navigationDestination(for: AppRoute.self, destination: destination)
            }
            .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.symbol) }
            .tag(AppTab.settings)
        }
        .tint(DS.Palette.brand)
        // Системное сжатие панели при прокрутке — родное поведение iOS 26.
        .nativeTabBarMinimize()
        .tabAccessory(
            showsAdd: router.selectedTab == .month,
            remaining: monthViewModel.summary.remaining,
            currency: monthViewModel.currency
        ) {
            isAddingExpense = true
        }
        .sheet(isPresented: $isAddingExpense) {
            ExpenseEditor(defaultDate: monthViewModel.defaultDate,
                          currency: monthViewModel.currency) { expense in
                await monthViewModel.addExpense(expense)
            }
        }
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
