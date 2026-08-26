import Observation
import SwiftUI

/// Центральный роутер: выбранный таб и путь каждого стека.
@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .month

    var monthPath = NavigationPath()
    var analyticsPath = NavigationPath()
    var settingsPath = NavigationPath()

    func path(for tab: AppTab) -> NavigationPath {
        switch tab {
        case .month: monthPath
        case .analytics: analyticsPath
        case .settings: settingsPath
        }
    }

    /// Повторное нажатие на активный таб возвращает стек к корню —
    /// привычное поведение системных приложений.
    func popToRoot(_ tab: AppTab) {
        switch tab {
        case .month: monthPath = NavigationPath()
        case .analytics: analyticsPath = NavigationPath()
        case .settings: settingsPath = NavigationPath()
        }
    }
}
