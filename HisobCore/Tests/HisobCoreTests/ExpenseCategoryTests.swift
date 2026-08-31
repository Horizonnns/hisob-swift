import Foundation
import Testing
@testable import HisobCore

@Suite("Категории")
struct ExpenseCategoryTests {
    @Test("Встроенных категорий шестнадцать и все опознаются")
    func builtInCategories() {
        #expect(ExpenseCategory.builtIn.count == 16)
        for category in ExpenseCategory.builtIn {
            #expect(category.isBuiltIn, "не опознана: \(category.rawValue)")
        }
    }

    @Test("Своя категория сохраняется как есть")
    func customCategorySurvives() {
        let custom = ExpenseCategory(rawValue: "Своя категория")
        #expect(custom.rawValue == "Своя категория")
        #expect(!custom.isBuiltIn)
    }
}
