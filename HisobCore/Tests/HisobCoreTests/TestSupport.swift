import Foundation
@testable import HisobCore

/// Фиксированный календарь: тесты не должны зависеть от часового пояса машины.
let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date {
    utc.date(from: DateComponents(year: year, month: month, day: dayOfMonth))!
}

func ym(_ year: Int, _ month: Int) -> YearMonth {
    YearMonth(year: year, month: month)
}

func money(_ value: String) -> Money {
    Money.parse(value)!
}

func salary(_ amount: String, from date: Date) -> SalaryEntry {
    SalaryEntry(effectiveFrom: date, amount: money(amount))
}

func expense(
    _ amount: String,
    on date: Date,
    category: ExpenseCategory = .food,
    title: String = "тест"
) -> Expense {
    .single(date: date, category: category, title: title, amount: money(amount))
}

let calculator = LedgerCalculator(calendar: utc)
let analytics = Analytics(calendar: utc)
