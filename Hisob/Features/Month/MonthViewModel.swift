import Foundation
import HisobCore
import Observation

@MainActor
@Observable
final class MonthViewModel {
    private let store: LedgerStore
    private let calculator: LedgerCalculator
    private let calendar: Calendar

    var month: YearMonth
    var query = ExpenseQuery()

    init(store: LedgerStore, calendar: Calendar = .current, month: YearMonth? = nil) {
        self.store = store
        self.calendar = calendar
        self.calculator = LedgerCalculator(calendar: calendar)
        self.month = month ?? YearMonth.current(calendar: calendar)
    }

    // MARK: - Состояние

    var state: LedgerStore.State { store.state }
    var currency: CurrencyCode { store.ledger.currency }
    var operationError: String? { store.operationError }

    // MARK: - Производные значения

    var summary: MonthSummary {
        calculator.summary(store.ledger, for: month)
    }

    /// Все траты месяца — по ним считается статистика и счётчики категорий.
    var monthExpenses: [Expense] {
        store.ledger.expenses(in: month, calendar: calendar)
    }

    /// Траты после фильтра — их видит пользователь.
    var visibleExpenses: [Expense] {
        monthExpenses.filtered(by: query, categoryTitle: CategoryPresentation.title)
    }

    /// Категории, встречающиеся в этом месяце, со счётчиком.
    var categoryCounts: [(category: ExpenseCategory, count: Int)] {
        Dictionary(grouping: monthExpenses, by: \.category)
            .map { (category: $0.key, count: $0.value.count) }
            .sorted { CategoryPresentation.title($0.category) < CategoryPresentation.title($1.category) }
    }

    var hasFilter: Bool { !query.isEmpty }

    var isCurrentMonth: Bool { month == YearMonth.current(calendar: calendar) }

    /// Перенос показывается только когда он есть — как в веб-версии.
    var showsCarryover: Bool { summary.carryover > .zero }

    // MARK: - Действия

    func load() async {
        await store.loadIfNeeded()
    }

    func reload() async {
        await store.load()
    }

    func goToPreviousMonth() { month = month.adding(months: -1) }
    func goToNextMonth() { month = month.adding(months: 1) }
    func goToCurrentMonth() { month = YearMonth.current(calendar: calendar) }

    func toggleCategory(_ category: ExpenseCategory) {
        if query.categories.contains(category) {
            query.categories.remove(category)
        } else {
            query.categories.insert(category)
        }
    }

    func clearFilters() {
        query = .none
    }

    /// Фильтры сбрасываются при смене месяца: в новом месяце они почти всегда
    /// не имеют смысла и незаметно скрывают траты.
    func monthDidChange() {
        clearFilters()
    }

    func addExpense(
        amount: Money,
        category: ExpenseCategory,
        date: Date,
        title: String
    ) async {
        await store.add(
            .single(
                date: date,
                category: category,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                amount: amount
            )
        )
    }

    func deleteExpense(_ expense: Expense) async {
        await store.delete(expense)
    }

    func dismissOperationError() {
        store.dismissOperationError()
    }
}
