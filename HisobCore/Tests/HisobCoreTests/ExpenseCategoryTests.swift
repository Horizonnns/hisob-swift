import Foundation
import Testing
@testable import HisobCore

@Suite("Категории")
struct ExpenseCategoryTests {
    @Test("Русские подписи из прода отображаются в стабильные ключи")
    func legacyMapping() {
        #expect(ExpenseCategory(legacyName: "Еда") == .food)
        #expect(ExpenseCategory(legacyName: "Связь/Интернет") == .communication)
        #expect(ExpenseCategory(legacyName: "Благотворительность") == .charity)
        #expect(ExpenseCategory(legacyName: "Сбережения") == .savings)
    }

    @Test("Незнакомая категория сохраняется, а не теряется при импорте")
    func unknownLegacyNameSurvives() {
        let custom = ExpenseCategory(legacyName: "Своя категория")
        #expect(custom.rawValue == "Своя категория")
        #expect(!custom.isBuiltIn)
    }

    @Test("Все 16 категорий веб-версии перенесены")
    func allLegacyCategoriesCovered() {
        let legacy = [
            "Еда", "Транспорт", "Аренда", "Коммуналка", "Связь/Интернет",
            "Здоровье", "Гигиена", "Косметика", "Одежда", "Развлечения",
            "Образование", "Подарки", "Благотворительность", "Кредит",
            "Сбережения", "Прочее"
        ]
        #expect(legacy.count == ExpenseCategory.builtIn.count)
        for name in legacy {
            #expect(ExpenseCategory(legacyName: name).isBuiltIn, "не распознана: \(name)")
        }
    }
}
