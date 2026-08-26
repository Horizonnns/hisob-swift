import Foundation
import HisobCore
import Observation

@MainActor
@Observable
final class MonthViewModel {
    enum State: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    private let repository: any LedgerRepository
    private let calculator: LedgerCalculator
    private let calendar: Calendar

    private(set) var state: State = .loading
    private(set) var ledger = Ledger()
    /// Сообщение о неудавшейся операции; показывается баннером и гасится само.
    private(set) var operationError: String?

    var month: YearMonth
    var query = ExpenseQuery()

    init(
        repository: any LedgerRepository,
        calendar: Calendar = .current,
        month: YearMonth? = nil
    ) {
        self.repository = repository
        self.calendar = calendar
        self.calculator = LedgerCalculator(calendar: calendar)
        self.month = month ?? YearMonth.current(calendar: calendar)
    }

    // MARK: - Производные значения

    var summary: MonthSummary {
        calculator.summary(ledger, for: month)
    }

    /// Все траты месяца — по ним считается статистика и счётчики категорий.
    var monthExpenses: [Expense] {
        ledger.expenses(in: month, calendar: calendar)
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

    // MARK: - Загрузка

    func load() async {
        state = .loading
        do {
            ledger = try await repository.load()
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    // MARK: - Навигация по месяцам

    func goToPreviousMonth() { month = month.adding(months: -1) }
    func goToNextMonth() { month = month.adding(months: 1) }
    func goToCurrentMonth() { month = YearMonth.current(calendar: calendar) }

    // MARK: - Фильтры

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

    // MARK: - Изменения

    func addExpense(
        amount: Money,
        category: ExpenseCategory,
        date: Date,
        title: String
    ) async {
        let expense = Expense.single(
            date: date,
            category: category,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount
        )

        // Оптимистично: список обновляется сразу, ожидание записи не блокирует UI.
        ledger.expenses.append(expense)
        do {
            try await repository.add(expense)
        } catch {
            // Откат. В веб-версии его не было — при неудачном сохранении
            // на экране оставалось то, чего в базе нет.
            ledger.expenses.removeAll { $0.id == expense.id }
            operationError = L.Error.saveFailed
        }
    }

    func deleteExpense(_ expense: Expense) async {
        guard let index = ledger.expenses.firstIndex(where: { $0.id == expense.id }) else { return }
        let removed = ledger.expenses.remove(at: index)
        do {
            try await repository.delete(expenseID: removed.id)
        } catch {
            ledger.expenses.insert(removed, at: index)
            operationError = L.Error.saveFailed
        }
    }

    func dismissOperationError() {
        operationError = nil
    }
}
