import HisobCore
import SwiftUI

/// Подписи и иконки категорий.
///
/// Домен хранит стабильные ключи (`food`) и о представлении ничего не знает —
/// вся визуальная часть живёт здесь.
enum CategoryPresentation {
    static func title(_ category: ExpenseCategory) -> String {
        switch category {
        case .food: "Еда"
        case .transport: "Транспорт"
        case .rent: "Аренда"
        case .utilities: "Коммуналка"
        case .communication: "Связь/Интернет"
        case .health: "Здоровье"
        case .hygiene: "Гигиена"
        case .cosmetics: "Косметика"
        case .clothing: "Одежда"
        case .entertainment: "Развлечения"
        case .education: "Образование"
        case .gifts: "Подарки"
        case .charity: "Благотворительность"
        case .loan: "Кредит"
        case .savings: "Сбережения"
        case .other: "Прочее"
        // Пользовательская категория показывается своим ключом как есть.
        default: category.rawValue
        }
    }

    static func symbol(_ category: ExpenseCategory) -> String {
        switch category {
        case .food: "fork.knife"
        case .transport: "car.fill"
        case .rent: "house.fill"
        case .utilities: "bolt.fill"
        case .communication: "wifi"
        case .health: "cross.case.fill"
        case .hygiene: "shower.fill"
        case .cosmetics: "sparkles"
        case .clothing: "tshirt.fill"
        case .entertainment: "gamecontroller.fill"
        case .education: "book.fill"
        case .gifts: "gift.fill"
        case .charity: "heart.fill"
        case .loan: "creditcard.fill"
        case .savings: "banknote.fill"
        case .other: "ellipsis.circle.fill"
        default: "tag.fill"
        }
    }

    /// Цвет-акцент категории.
    ///
    /// Индекс обязан быть детерминированным между запусками: `String.hashValue`
    /// в Swift солится случайным зерном на каждый процесс, из-за чего цвета
    /// категорий менялись при каждом старте приложения.
    static func tint(_ category: ExpenseCategory) -> Color {
        // У каждой встроенной категории собственный оттенок: на кольцевой
        // диаграмме секторы обязаны различаться между собой.
        if let index = ExpenseCategory.builtIn.firstIndex(of: category),
           index < DS.Palette.categoryTints.count {
            return DS.Palette.categoryTints[index]
        }
        // Пользовательская категория: стабильная свёртка ключа, потому что
        // `String.hashValue` меняется от запуска к запуску.
        let folded = category.rawValue.unicodeScalars.reduce(0) { accumulator, scalar in
            (accumulator &* 31 &+ Int(scalar.value)) & 0xFFFF
        }
        return DS.Palette.categoryTints[folded % DS.Palette.categoryTints.count]
    }
}
