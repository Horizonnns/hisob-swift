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

    /// Поступления месяца.
    var monthReceipts: [Receipt] {
        store.ledger.receipts(in: month, calendar: calendar)
    }

    /// Поступления после фильтра.
    ///
    /// Фильтр по категориям — про траты, поэтому при нём поступления
    /// скрываются целиком: иначе список «Еда» показывал бы подарок. Поиск
    /// текстом работает — ищем по описанию и виду.
    var visibleReceipts: [Receipt] {
        guard query.categories.isEmpty else { return [] }

        let text = query.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return monthReceipts }

        return monthReceipts.filter {
            $0.title.localizedCaseInsensitiveContains(text)
                || ReceiptPresentation.title($0.kind).localizedCaseInsensitiveContains(text)
        }
    }

    /// Запись дня: трата или поступление. Лежат в одном списке, потому что
    /// человек вспоминает день целиком, а не отдельно приход и расход.
    enum DayEntry: Identifiable {
        case expense(Expense)
        case receipt(Receipt)

        var id: UUID {
            switch self {
            case .expense(let expense): expense.id
            case .receipt(let receipt): receipt.id
            }
        }

        var date: Date {
            switch self {
            case .expense(let expense): expense.date
            case .receipt(let receipt): receipt.date
            }
        }
    }

    /// День списка: заголовок несёт дату и суммы за день, поэтому в самих
    /// строках дата больше не повторяется — раньше она была самой частой
    /// надписью на экране и ничего не сообщала.
    struct DaySection: Identifiable {
        let date: Date
        let entries: [DayEntry]

        var id: Date { date }

        /// Потрачено за день.
        var spent: Money {
            entries.reduce(.zero) { sum, entry in
                if case .expense(let expense) = entry { return sum + expense.total }
                return sum
            }
        }

        /// Пришло за день. Ноль — значит в заголовке ничего не показываем.
        var received: Money {
            entries.reduce(.zero) { sum, entry in
                if case .receipt(let receipt) = entry { return sum + receipt.amount }
                return sum
            }
        }
    }

    /// От свежего к старому: то, что случилось сегодня, нужно чаще, чем то,
    /// что было первого числа.
    var visibleDays: [DaySection] {
        let entries = visibleExpenses.map(DayEntry.expense) + visibleReceipts.map(DayEntry.receipt)

        return Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
            .map { date, entries in
                DaySection(date: date, entries: entries.sorted { $0.date < $1.date })
            }
            .sorted { $0.date > $1.date }
    }

    /// «Сегодня» и «Вчера» вместо даты: так быстрее опознаётся свежее.
    func dayTitle(_ date: Date) -> String {
        if calendar.isDateInToday(date) { return L.Month.today }
        if calendar.isDateInYesterday(date) { return L.Month.yesterday }
        return date.formatted(
            .dateTime.day().month(.wide).locale(Locale(identifier: "ru_RU"))
        )
    }

    /// Категории, встречающиеся в этом месяце, со счётчиком.
    var categoryCounts: [(category: ExpenseCategory, count: Int)] {
        Dictionary(grouping: monthExpenses, by: \.category)
            .map { (category: $0.key, count: $0.value.count) }
            .sorted { CategoryPresentation.title($0.category) < CategoryPresentation.title($1.category) }
    }

    var hasFilter: Bool { !query.isEmpty }

    /// Показывать ли пустой экран. Поступление без трат — тоже содержимое.
    var isEmpty: Bool { visibleExpenses.isEmpty && visibleReceipts.isEmpty }

    /// Дата новой траты: в текущем месяце — сегодня, в прошлом — его первое
    /// число, иначе запись улетела бы в другой месяц.
    var defaultDate: Date {
        isCurrentMonth ? .now : month.startDate()
    }

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

    func addReceipt(_ receipt: Receipt) async -> Bool {
        await store.add(receipt)
    }

    func updateReceipt(_ receipt: Receipt) async -> Bool {
        await store.update(receipt)
    }

    func deleteReceipt(_ receipt: Receipt) async {
        await store.delete(receipt)
    }

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

    @discardableResult
    func addExpense(_ expense: Expense) async -> Bool {
        await store.add(expense)
    }

    @discardableResult
    func updateExpense(_ expense: Expense) async -> Bool {
        await store.update(expense)
    }

    func deleteExpense(_ expense: Expense) async {
        await store.delete(expense)
    }

    func dismissOperationError() {
        store.dismissOperationError()
    }
}
