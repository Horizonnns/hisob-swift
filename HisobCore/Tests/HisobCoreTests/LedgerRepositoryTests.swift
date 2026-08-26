import Foundation
import Testing
@testable import HisobCore

@Suite("Хранилище")
struct LedgerRepositoryTests {
    @Test("Добавление, правка и удаление затрагивают одну запись")
    func crudByStableID() async throws {
        let repository = InMemoryLedgerRepository()
        var first = expense("100", on: day(2026, 8, 1), title: "первая")
        let second = expense("200", on: day(2026, 8, 2), title: "вторая")

        try await repository.add(first)
        try await repository.add(second)
        #expect(try await repository.load().expenses.count == 2)

        first.title = "исправленная"
        try await repository.update(first)
        let afterUpdate = try await repository.load()
        #expect(afterUpdate.expenses.first { $0.id == first.id }?.title == "исправленная")
        // Правка одной записи не трогает соседнюю — в вебе перезаписывался
        // весь массив целиком.
        #expect(afterUpdate.expenses.first { $0.id == second.id }?.title == "вторая")

        try await repository.delete(expenseID: first.id)
        let afterDelete = try await repository.load()
        #expect(afterDelete.expenses.map(\.id) == [second.id])
    }

    @Test("Правка несуществующей записи — ошибка, а не тихое создание")
    func updateMissingThrows() async throws {
        let repository = InMemoryLedgerRepository()
        let ghost = expense("1", on: day(2026, 8, 1))
        await #expect(throws: LedgerRepositoryError.expenseNotFound(ghost.id)) {
            try await repository.update(ghost)
        }
    }

    @Test("save создаёт источник и обновляет его по тому же id")
    func upsertSource() async throws {
        let repository = InMemoryLedgerRepository()
        var source = IncomeSource(name: "OD", salaryHistory: [salary("9980", from: day(2026, 6, 10))])

        try await repository.save(source)
        #expect(try await repository.load().sources.count == 1)

        source.salaryHistory.append(salary("10120", from: day(2026, 8, 1)))
        try await repository.save(source)
        let stored = try await repository.load()
        #expect(stored.sources.count == 1)
        #expect(stored.sources[0].salaryHistory.count == 2)
    }

    @Test("Удаление источника не удаляет траты — они личные")
    func deletingSourceKeepsExpenses() async throws {
        let source = IncomeSource(name: "asrmall")
        let repository = InMemoryLedgerRepository(ledger: Ledger(sources: [source]))
        let attached = Expense.single(
            date: day(2026, 7, 1), category: .other,
            title: "ноутбук", amount: money("5000"), incomeSourceID: source.id
        )
        try await repository.add(attached)

        try await repository.delete(sourceID: source.id)
        let stored = try await repository.load()
        #expect(stored.sources.isEmpty)
        #expect(stored.expenses.count == 1)
        #expect(stored.expenses[0].incomeSourceID == nil)
    }
}
