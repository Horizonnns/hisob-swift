import Foundation
import HisobCore

/// Демонстрационные данные для превью и первого запуска.
///
/// ВНИМАНИЕ: это не выгрузка из прода. Структура источников повторяет реальную
/// (OD — текущая работа, asrmall завершён в июле 2026), но суммы asrmall
/// и список трат условные. Реальные данные приезжают импортом — см.
/// `docs/migration.md`.
enum PreviewData {
    static let ledger: Ledger = {
        Ledger(
            currency: .tjs,
            sources: [od, asrmall],
            expenses: expenses
        )
    }()

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
            SalaryEntry(effectiveFrom: date(2026, 1, 1), amount: 5000)
        ],
        endedAt: YearMonth(year: 2026, month: 7)
    )

    private static let expenses: [Expense] = [
        .single(date: date(2026, 6, 12), category: .food, title: "продукты", amount: 1800),
        .single(date: date(2026, 6, 20), category: .transport, title: "такси", amount: 260),
        .single(date: date(2026, 7, 3), category: .utilities, title: "свет и вода", amount: 640),
        .single(date: date(2026, 7, 15), category: .food, title: "продукты", amount: 2100),
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
