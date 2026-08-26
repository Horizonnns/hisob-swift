import Foundation
import HisobCore
import Observation

@MainActor
@Observable
final class IncomeSourcesViewModel {
    private let store: LedgerStore
    private let calendar: Calendar

    init(store: LedgerStore, calendar: Calendar = .current) {
        self.store = store
        self.calendar = calendar
    }

    var state: LedgerStore.State { store.state }
    var currency: CurrencyCode { store.ledger.currency }
    var operationError: String? { store.operationError }

    /// Активные источники сверху, завершённые ниже — в обеих группах по имени.
    var sources: [IncomeSource] {
        store.ledger.sources.sorted { lhs, rhs in
            let lhsActive = isActiveNow(lhs)
            let rhsActive = isActiveNow(rhs)
            if lhsActive != rhsActive { return lhsActive }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    var isEmpty: Bool { store.ledger.sources.isEmpty }

    func isActiveNow(_ source: IncomeSource) -> Bool {
        guard let endedAt = source.endedAt else { return true }
        return YearMonth.current(calendar: calendar) <= endedAt
    }

    /// Оклад источника за текущий месяц — то, что он приносит прямо сейчас.
    func currentSalary(_ source: IncomeSource) -> Money {
        source.salary(in: YearMonth.current(calendar: calendar), calendar: calendar)
    }

    /// Помечен ли источник как завершающийся — независимо от того, прошёл ли
    /// последний месяц. Иначе источник, завершённый текущим месяцем, выглядит
    /// в точности как бессрочный, и правка кажется несохранившейся.
    func isEnding(_ source: IncomeSource) -> Bool {
        source.endedAt != nil
    }

    /// Последний назначенный оклад — показывается для завершённых источников.
    func lastSalary(_ source: IncomeSource) -> Money? {
        source.sortedHistory().last?.amount
    }

    func load() async {
        await store.loadIfNeeded()
    }

    func reload() async {
        await store.load()
    }

    @discardableResult
    func save(_ source: IncomeSource) async -> Bool {
        await store.save(source)
    }

    func delete(_ source: IncomeSource) async {
        await store.delete(sourceID: source.id)
    }

    func dismissOperationError() {
        store.dismissOperationError()
    }
}
