import Foundation

/// Категория траты.
///
/// Хранится стабильным ключом (`food`), а не отображаемым текстом. В вебе в
/// базе лежали русские подписи («Еда»), из-за чего переименование категории
/// сломало бы исторические данные, а локализация была невозможна. Подписи
/// живут в слое UI, домен знает только ключи.
///
/// Это не `enum`, чтобы пользователь мог завести свою категорию: любой
/// нераспознанный ключ остаётся валидным значением.
public struct ExpenseCategory: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let food = ExpenseCategory(rawValue: "food")
    public static let transport = ExpenseCategory(rawValue: "transport")
    public static let rent = ExpenseCategory(rawValue: "rent")
    public static let utilities = ExpenseCategory(rawValue: "utilities")
    public static let communication = ExpenseCategory(rawValue: "communication")
    public static let health = ExpenseCategory(rawValue: "health")
    public static let hygiene = ExpenseCategory(rawValue: "hygiene")
    public static let cosmetics = ExpenseCategory(rawValue: "cosmetics")
    public static let clothing = ExpenseCategory(rawValue: "clothing")
    public static let entertainment = ExpenseCategory(rawValue: "entertainment")
    public static let education = ExpenseCategory(rawValue: "education")
    public static let gifts = ExpenseCategory(rawValue: "gifts")
    public static let charity = ExpenseCategory(rawValue: "charity")
    public static let loan = ExpenseCategory(rawValue: "loan")
    public static let savings = ExpenseCategory(rawValue: "savings")
    public static let other = ExpenseCategory(rawValue: "other")

    /// Встроенные категории в порядке показа в списке выбора.
    public static let builtIn: [ExpenseCategory] = [
        .food, .transport, .rent, .utilities, .communication, .health,
        .hygiene, .cosmetics, .clothing, .entertainment, .education,
        .gifts, .charity, .loan, .savings, .other
    ]

    public var isBuiltIn: Bool { Self.builtIn.contains(self) }

    // MARK: - Импорт из веб-версии

    /// Русские подписи, под которыми категории лежат в проде.
    /// Используется однократно при переносе данных из Postgres.
    private static let legacyNames: [String: ExpenseCategory] = [
        "Еда": .food,
        "Транспорт": .transport,
        "Аренда": .rent,
        "Коммуналка": .utilities,
        "Связь/Интернет": .communication,
        "Здоровье": .health,
        "Гигиена": .hygiene,
        "Косметика": .cosmetics,
        "Одежда": .clothing,
        "Развлечения": .entertainment,
        "Образование": .education,
        "Подарки": .gifts,
        "Благотворительность": .charity,
        "Кредит": .loan,
        "Сбережения": .savings,
        "Прочее": .other
    ]

    /// Категория по подписи из старой базы.
    /// Нераспознанная подпись сохраняется как есть — данные не теряются.
    public init(legacyName: String) {
        self = Self.legacyNames[legacyName] ?? ExpenseCategory(rawValue: legacyName)
    }
}
