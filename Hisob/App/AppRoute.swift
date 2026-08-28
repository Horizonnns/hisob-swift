import Foundation

/// Табы приложения.
enum AppTab: Hashable, CaseIterable {
    case month
    case analytics
    case settings

    var title: String {
        switch self {
        case .month: L.Tab.month
        case .analytics: L.Tab.analytics
        case .settings: L.Tab.settings
        }
    }

    /// Подпись в панели вкладок.
    ///
    /// Пробелы по краям — не опечатка. Плавающая панель iOS 26 считает свою
    /// ширину по подписям и с короткими словами сжимается: 280 pt на «Месяце»
    /// и 305 pt на «Аналитике», отчего вкладки заметно съезжали при переходе.
    /// Управлять её шириной напрямую система не даёт — ни `UITabBar.appearance`
    /// (упирается в 290 pt), ни `.frame` на подписи в новом `Tab` API. Добивка
    /// доводит панель до предела в 363 pt, дальше она не растёт, поэтому
    /// ширина держится одинаковой на всех вкладках.
    var tabBarTitle: String { "   \(title)   " }

    var symbol: String {
        switch self {
        case .month: "calendar"
        case .analytics: "chart.pie.fill"
        case .settings: "gearshape.fill"
        }
    }
}

/// Экраны внутри стеков навигации.
enum AppRoute: Hashable {
    case incomeSources
}
