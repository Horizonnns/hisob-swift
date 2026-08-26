import Foundation
import Testing
@testable import HisobCore

@Suite("Перенос остатка")
struct CarryoverTests {
    @Test("Без трат переносить нечего")
    func noExpenses() {
        let ledger = Ledger(sources: [
            IncomeSource(name: "OD", salaryHistory: [salary("10000", from: day(2026, 1, 1))])
        ])
        #expect(calculator.carryover(ledger, before: ym(2026, 8)) == .zero)
    }

    @Test("Цепочка начинается с первого месяца с тратами, а не с первого оклада")
    func chainStartsAtFirstExpense() {
        // Месяцы до начала учёта не содержат достоверных данных: если начать
        // с первого оклада, приложение припишет пользователю доход, который
        // он на самом деле уже потратил вне учёта.
        let ledger = Ledger(
            sources: [IncomeSource(name: "OD", salaryHistory: [salary("10000", from: day(2026, 1, 1))])],
            expenses: [expense("3000", on: day(2026, 6, 5))]
        )
        // Учёт начат в июне: в цепочку попадает только июнь.
        #expect(calculator.carryover(ledger, before: ym(2026, 7)) == money("7000"))
    }

    @Test("Первый месяц учёта переноса не имеет")
    func firstMonthHasNoCarryover() {
        let ledger = Ledger(
            sources: [IncomeSource(name: "OD", salaryHistory: [salary("10000", from: day(2026, 1, 1))])],
            expenses: [expense("3000", on: day(2026, 6, 5))]
        )
        #expect(calculator.carryover(ledger, before: ym(2026, 6)) == .zero)
    }

    @Test("Остаток накапливается через несколько месяцев подряд")
    func accumulatesAcrossMonths() {
        let ledger = Ledger(
            sources: [IncomeSource(name: "OD", salaryHistory: [salary("10000", from: day(2026, 1, 1))])],
            expenses: [
                expense("8000", on: day(2026, 6, 5)),
                expense("9000", on: day(2026, 7, 5))
            ]
        )
        // июнь: 10000 − 8000 = 2000; июль: 2000 + 10000 − 9000 = 3000
        #expect(calculator.carryover(ledger, before: ym(2026, 8)) == money("3000"))
    }

    @Test("Перерасход обнуляет остаток и не переходит долгом")
    func negativeBalanceIsClamped() {
        let ledger = Ledger(
            sources: [IncomeSource(name: "OD", salaryHistory: [salary("10000", from: day(2026, 1, 1))])],
            expenses: [
                expense("15000", on: day(2026, 6, 5)),
                expense("1000", on: day(2026, 7, 5))
            ]
        )
        // июнь: 10000 − 15000 = −5000 → 0; июль: 0 + 10000 − 1000 = 9000
        #expect(calculator.carryover(ledger, before: ym(2026, 8)) == money("9000"))
    }

    @Test("Политика allowDebt переносит перерасход минусом")
    func debtPolicyCarriesNegative() {
        let debtCalculator = LedgerCalculator(calendar: utc, carryoverPolicy: .allowDebt)
        let ledger = Ledger(
            sources: [IncomeSource(name: "OD", salaryHistory: [salary("10000", from: day(2026, 1, 1))])],
            expenses: [
                expense("15000", on: day(2026, 6, 5)),
                expense("1000", on: day(2026, 7, 5))
            ]
        )
        // июнь: −5000; июль: −5000 + 10000 − 1000 = 4000
        #expect(debtCalculator.carryover(ledger, before: ym(2026, 8)) == money("4000"))
    }
}

@Suite("Смена работы")
struct JobTransitionTests {
    /// Реальная история пользователя: asrmall завершился в июле 2026,
    /// OD начался с оклада от 10 июня 2026 — то есть июнь и июль оба
    /// источника приносили доход одновременно.
    private func ledger(asrmallEnded: YearMonth? = ym(2026, 7)) -> Ledger {
        Ledger(
            sources: [
                IncomeSource(
                    name: "asrmall",
                    role: "Frontend Engineer",
                    salaryHistory: [salary("5000", from: day(2026, 1, 1))],
                    endedAt: asrmallEnded
                ),
                IncomeSource(
                    name: "OD",
                    role: "Team-Lead / Frontend-разработчик",
                    salaryHistory: [
                        salary("9980", from: day(2026, 6, 10)),
                        salary("10120", from: day(2026, 8, 1))
                    ]
                )
            ],
            expenses: [
                expense("1000", on: day(2026, 5, 15)),
                expense("2000", on: day(2026, 6, 15)),
                expense("3000", on: day(2026, 7, 15))
            ]
        )
    }

    @Test("Параллельные источники складываются в общий доход")
    func parallelSourcesSum() {
        let ledger = ledger()
        #expect(calculator.income(ledger, in: ym(2026, 5)) == money("5000"))
        // Июнь и июль — переходный период, работают оба источника.
        #expect(calculator.income(ledger, in: ym(2026, 6)) == money("14980"))
        #expect(calculator.income(ledger, in: ym(2026, 7)) == money("14980"))
    }

    @Test("Завершённый источник перестаёт приносить доход")
    func endedSourceStopsContributing() {
        #expect(calculator.income(ledger(), in: ym(2026, 8)) == money("10120"))
    }

    @Test("Без даты завершения источник платил бы вечно — регресс из веб-версии")
    func withoutEndDatePhantomIncomeAppears() {
        // Это ровно тот баг, который в вебе не был виден на одном проекте:
        // `salaryAtMonth` брала последнюю запись без ограничения сверху.
        let phantom = calculator.income(ledger(asrmallEnded: nil), in: ym(2026, 8))
        #expect(phantom == money("15120"))
        #expect(phantom != calculator.income(ledger(), in: ym(2026, 8)))
    }

    @Test("Остаток проходит сквозь смену работы одной цепочкой")
    func balanceSurvivesJobChange() {
        // май:  0 + 5000 − 1000  = 4000
        // июнь: 4000 + 14980 − 2000 = 16980
        // июль: 16980 + 14980 − 3000 = 28960
        // В веб-версии цепочка считалась внутри проекта, поэтому остаток
        // периода asrmall в OD не попадал вовсе.
        #expect(calculator.carryover(ledger(), before: ym(2026, 8)) == money("28960"))
    }

    @Test("Итог августа собирается целиком")
    func augustSummary() {
        let summary = calculator.summary(ledger(), for: ym(2026, 8))
        #expect(summary.income == money("10120"))
        #expect(summary.carryover == money("28960"))
        #expect(summary.spent == .zero)
        #expect(summary.remaining == money("39080"))
        // В августе платит только OD.
        #expect(summary.incomeBreakdown.count == 1)
        #expect(summary.incomeBreakdown.first?.sourceName == "OD")
    }

    @Test("Разбивка дохода за переходный месяц показывает оба источника")
    func breakdownDuringOverlap() {
        let summary = calculator.summary(ledger(), for: ym(2026, 6))
        #expect(summary.incomeBreakdown.count == 2)
        // Отсортировано по убыванию суммы.
        #expect(summary.incomeBreakdown.map(\.sourceName) == ["OD", "asrmall"])
        #expect(summary.incomeBreakdown.map(\.amount) == [money("9980"), money("5000")])
    }
}
