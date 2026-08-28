import Foundation
import HisobCore
import Observation

/// Точка круговой диаграммы. `Money` не умеет в `Plottable`, поэтому для
/// графиков сумма приводится к `Double` — только для отрисовки, расчёты
/// остаются на `Decimal`.
struct CategorySlice: Identifiable, Hashable {
    let category: ExpenseCategory
    let amount: Money
    var id: ExpenseCategory { category }
    var plotValue: Double { MoneyFormat.transitionValue(amount) }
    var title: String { CategoryPresentation.title(category) }
}

/// Столбец диаграммы по месяцам.
struct MonthBar: Identifiable, Hashable {
    let month: YearMonth
    let amount: Money
    var id: YearMonth { month }
    var plotValue: Double { MoneyFormat.transitionValue(amount) }
}

@MainActor
@Observable
final class AnalyticsViewModel {
    /// Сколько месяцев показывать на столбчатой диаграмме.
    private static let monthsWindow = 12

    private let store: LedgerStore
    private let analytics: Analytics
    private let calculator: LedgerCalculator
    private let calendar: Calendar

    var month: YearMonth
    /// Выделенная категория — подсвечивает сектор и меняет подпись в центре.
    var selectedCategory: ExpenseCategory?

    init(store: LedgerStore, calendar: Calendar = .current, month: YearMonth? = nil) {
        self.store = store
        self.calendar = calendar
        self.analytics = Analytics(calendar: calendar)
        self.calculator = LedgerCalculator(calendar: calendar)
        self.month = month ?? YearMonth.current(calendar: calendar)
    }

    var state: LedgerStore.State { store.state }
    var currency: CurrencyCode { store.ledger.currency }
    var isCurrentMonth: Bool { month == YearMonth.current(calendar: calendar) }

    var summary: MonthSummary {
        calculator.summary(store.ledger, for: month)
    }

    /// Переводит угол, по которому попал палец, в категорию.
    ///
    /// `chartAngleSelection` отдаёт позицию вдоль суммы всех секторов,
    /// а не сам сектор — сопоставляем, накапливая доли в том же
    /// порядке, в каком они нарисованы.
    func category(atAngleValue value: Double) -> ExpenseCategory? {
        var accumulated = 0.0
        for slice in slices {
            accumulated += slice.plotValue
            if value <= accumulated { return slice.category }
        }
        return nil
    }

    var slices: [CategorySlice] {
        analytics
            .byCategory(store.ledger.expenses(in: month, calendar: calendar))
            .map { CategorySlice(category: $0.category, amount: $0.amount) }
    }

    var total: Money {
        slices.reduce(Money.zero) { $0 + $1.amount }
    }

    var monthBars: [MonthBar] {
        analytics
            .monthlyTotals(store.ledger.expenses, ending: month, count: Self.monthsWindow)
            .map { MonthBar(month: $0.month, amount: $0.amount) }
    }

    /// Подпись и сумма в центре кольца: выбранная категория либо общий итог.
    var centerLabel: String {
        selectedCategory.map(CategoryPresentation.title) ?? L.Analytics.total
    }

    var centerAmount: Money {
        guard let selectedCategory else { return total }
        return slices.first { $0.category == selectedCategory }?.amount ?? .zero
    }

    var incomeShares: [IncomeShare] { summary.incomeBreakdown }

    var receiptShares: [ReceiptShare] { summary.receiptBreakdown }

    var hasExpenses: Bool { !slices.isEmpty }

    func load() async {
        await store.loadIfNeeded()
    }

    func reload() async {
        await store.load()
    }

    func goToPreviousMonth() {
        month = month.adding(months: -1)
        selectedCategory = nil
    }

    func goToNextMonth() {
        month = month.adding(months: 1)
        selectedCategory = nil
    }

    func goToCurrentMonth() {
        month = YearMonth.current(calendar: calendar)
        selectedCategory = nil
    }

    func toggleSelection(_ category: ExpenseCategory) {
        selectedCategory = selectedCategory == category ? nil : category
    }
}
