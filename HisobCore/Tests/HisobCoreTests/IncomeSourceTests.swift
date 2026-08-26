import Foundation
import Testing
@testable import HisobCore

@Suite("Оклад источника")
struct IncomeSourceTests {
    /// OD с реальной структурой истории: повышение внутри одной работы.
    private func od(endedAt: YearMonth? = nil) -> IncomeSource {
        IncomeSource(
            name: "OD",
            role: "Team-Lead / Frontend-разработчик",
            salaryHistory: [
                salary("9980", from: day(2026, 6, 10)),
                salary("10120", from: day(2026, 8, 1))
            ],
            endedAt: endedAt
        )
    }

    @Test("Оклад, назначенный в середине месяца, действует за весь месяц")
    func midMonthEffectiveDate() {
        // Запись от 10 июня применяется ко всему июню — так было в вебе,
        // поведение сохранено осознанно.
        #expect(od().salary(in: ym(2026, 6), calendar: utc) == money("9980"))
    }

    @Test("До первой записи дохода нет")
    func beforeFirstEntry() {
        #expect(od().salary(in: ym(2026, 5), calendar: utc) == .zero)
    }

    @Test("Действует последняя вступившая в силу запись")
    func latestApplicableEntry() {
        #expect(od().salary(in: ym(2026, 7), calendar: utc) == money("9980"))
        #expect(od().salary(in: ym(2026, 8), calendar: utc) == money("10120"))
        #expect(od().salary(in: ym(2026, 9), calendar: utc) == money("10120"))
    }

    @Test("Порядок записей в массиве не влияет на результат")
    func unsortedHistory() {
        let shuffled = IncomeSource(
            name: "OD",
            salaryHistory: [
                salary("10120", from: day(2026, 8, 1)),
                salary("9980", from: day(2026, 6, 10))
            ]
        )
        #expect(shuffled.salary(in: ym(2026, 8), calendar: utc) == money("10120"))
        #expect(shuffled.salary(in: ym(2026, 6), calendar: utc) == money("9980"))
    }

    @Test("После завершения работы оклад обнуляется")
    func endedSourceStopsPaying() {
        let ended = od(endedAt: ym(2026, 8))
        #expect(ended.salary(in: ym(2026, 8), calendar: utc) == money("10120"))
        #expect(ended.salary(in: ym(2026, 9), calendar: utc) == .zero)
        #expect(ended.salary(in: ym(2027, 1), calendar: utc) == .zero)
    }

    @Test("Активность источника ограничена с обеих сторон")
    func activityWindow() {
        let ended = od(endedAt: ym(2026, 8))
        #expect(!ended.isActive(in: ym(2026, 5), calendar: utc))
        #expect(ended.isActive(in: ym(2026, 6), calendar: utc))
        #expect(ended.isActive(in: ym(2026, 8), calendar: utc))
        #expect(!ended.isActive(in: ym(2026, 9), calendar: utc))
    }

    @Test("Источник без истории оклада ничего не приносит")
    func emptyHistory() {
        let empty = IncomeSource(name: "Пустой")
        #expect(empty.salary(in: ym(2026, 8), calendar: utc) == .zero)
        #expect(!empty.isActive(in: ym(2026, 8), calendar: utc))
    }
}
