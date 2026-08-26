import Foundation
import Testing
@testable import HisobCore

@Suite("Схлопывание очереди")
struct PendingOperationCollapseTests {
    private let first = expense("10", on: day(2026, 8, 1), title: "первая")
    private let second = expense("20", on: day(2026, 8, 2), title: "вторая")

    @Test("Правка неотправленной записи остаётся созданием")
    func updateAfterAddStaysAdd() {
        var edited = first
        edited.title = "исправленная"

        let collapsed: [PendingOperation] = [.addExpense(first), .updateExpense(edited)].collapsed()

        #expect(collapsed.count == 1)
        guard case .addExpense(let result) = collapsed[0] else {
            Issue.record("Ожидалось создание, получено \(collapsed[0])")
            return
        }
        #expect(result.title == "исправленная")
    }

    @Test("Удаление неотправленной записи снимает обе операции")
    func deleteAfterAddCancelsBoth() {
        let collapsed: [PendingOperation] = [
            .addExpense(first),
            .deleteExpense(first.id)
        ].collapsed()

        // Сервер о записи не знал — сообщать ему об удалении незачем.
        #expect(collapsed.isEmpty)
    }

    @Test("Удаление уже существующей записи сохраняется")
    func deleteOfExistingIsKept() {
        let collapsed: [PendingOperation] = [.deleteExpense(first.id)].collapsed()
        #expect(collapsed == [.deleteExpense(first.id)])
    }

    @Test("Несколько правок схлопываются в последнюю")
    func repeatedUpdatesCollapse() {
        var once = first
        once.title = "раз"
        var twice = first
        twice.title = "два"

        let collapsed: [PendingOperation] = [
            .updateExpense(once), .updateExpense(twice)
        ].collapsed()

        #expect(collapsed == [.updateExpense(twice)])
    }

    @Test("Операции над разными записями не смешиваются")
    func differentExpensesKeptSeparate() {
        let collapsed: [PendingOperation] = [
            .addExpense(first), .addExpense(second), .deleteExpense(first.id)
        ].collapsed()

        #expect(collapsed == [.addExpense(second)])
    }

    @Test("Из смен валюты остаётся последняя")
    func onlyLastCurrencyKept() {
        let collapsed: [PendingOperation] = [
            .setCurrency(CurrencyCode(rawValue: "USD")),
            .setCurrency(.tjs)
        ].collapsed()

        #expect(collapsed == [.setCurrency(.tjs)])
    }

    @Test("Порядок сохраняется")
    func orderIsPreserved() {
        let collapsed: [PendingOperation] = [
            .addExpense(first), .setCurrency(.tjs), .addExpense(second)
        ].collapsed()

        #expect(collapsed == [.addExpense(first), .setCurrency(.tjs), .addExpense(second)])
    }
}

@Suite("Применение операций к состоянию")
struct PendingOperationApplyTests {
    @Test("Создание добавляет трату")
    func addAppends() {
        var ledger = Ledger()
        PendingOperation.addExpense(expense("10", on: day(2026, 8, 1))).apply(to: &ledger)
        #expect(ledger.expenses.count == 1)
    }

    @Test("Повторное создание не плодит дубли")
    func addIsIdempotent() {
        var ledger = Ledger()
        let item = expense("10", on: day(2026, 8, 1))
        PendingOperation.addExpense(item).apply(to: &ledger)
        PendingOperation.addExpense(item).apply(to: &ledger)
        #expect(ledger.expenses.count == 1)
    }

    @Test("Удаление источника не трогает траты, только снимает пометку")
    func deletingSourceDetachesExpenses() {
        let source = IncomeSource(name: "asrmall")
        var ledger = Ledger(
            sources: [source],
            expenses: [
                .single(date: day(2026, 7, 1), category: .other,
                        title: "ноутбук", amount: money("5000"), incomeSourceID: source.id)
            ]
        )

        PendingOperation.deleteSource(source.id).apply(to: &ledger)

        #expect(ledger.sources.isEmpty)
        #expect(ledger.expenses.count == 1)
        #expect(ledger.expenses[0].incomeSourceID == nil)
    }
}
