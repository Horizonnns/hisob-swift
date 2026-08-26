import Foundation
import HisobCore

/// Демонстрационные данные для превью и режима без подключения.
///
/// История окладов взята из веб-версии как есть. Записи `asrmall` за июль
/// с суммой 1 TJS — это костыль старой модели: даты окончания у оклада не
/// было, и чтобы источник перестал начислять доход, выставляли символическую
/// сумму. Здесь для этого есть `endedAt`, но запись сохранена, чтобы цифры
/// за июль воспроизводились в точности.
enum PreviewData {
    static let ledger = Ledger(currency: .tjs, sources: [od, asrmall], expenses: expenses)

    private static let od = IncomeSource(
        name: "OD",
        role: "Team-Lead / Frontend-разработчик",
        salaryHistory: [
            SalaryEntry(effectiveFrom: date(2026, 6, 10), amount: 9980),
            SalaryEntry(effectiveFrom: date(2026, 8, 1), amount: 10120)
        ]
    )

    private static let asrmall = IncomeSource(
        name: "asrmall",
        role: "Frontend Engineer",
        salaryHistory: [
            SalaryEntry(effectiveFrom: date(2026, 3, 10), amount: 6000),
            SalaryEntry(effectiveFrom: date(2026, 4, 1), amount: 8000),
            SalaryEntry(effectiveFrom: date(2026, 6, 1), amount: 4000),
            SalaryEntry(effectiveFrom: date(2026, 7, 1), amount: 1)
        ],
        endedAt: YearMonth(year: 2026, month: 7)
    )

    private static let expenses: [Expense] = [
        .single(date: date(2026, 7, 1), category: .hygiene, title: "айна (3кг)", amount: 75),
        .group(
            date: date(2026, 7, 1),
            category: .food,
            title: "перекус",
            items: [
                ExpenseItem(amount: 25, title: "самса"),
                ExpenseItem(amount: 15, title: "чай")
            ]
        ),
        .group(
            date: date(2026, 7, 1),
            category: .food,
            title: "мороженое",
            items: [
                ExpenseItem(amount: 15, title: "рожок"),
                ExpenseItem(amount: 10, title: "стаканчик")
            ]
        ),
        .single(date: date(2026, 7, 8), category: .transport, title: "такси", amount: 260),
        .single(date: date(2026, 7, 19), category: .utilities, title: "свет и вода", amount: 640),
        .single(date: date(2026, 8, 2), category: .food, title: "rc-cola", amount: 13),
        .group(
            date: date(2026, 8, 2),
            category: .loan,
            title: "хумо",
            items: [
                ExpenseItem(amount: 1000, title: "основной платёж"),
                ExpenseItem(amount: Money.parse("923.63")!, title: "проценты")
            ]
        ),
        .single(date: date(2026, 8, 5), category: .transport, title: "заправка", amount: 420),
        .single(date: date(2026, 8, 11), category: .savings, title: "накопления", amount: 1500),
        .single(date: date(2026, 8, 18), category: .communication, title: "интернет", amount: 180)
    ]

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }
}
