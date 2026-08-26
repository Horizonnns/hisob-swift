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
