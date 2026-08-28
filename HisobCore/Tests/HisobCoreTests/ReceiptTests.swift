import Foundation
import Testing
@testable import HisobCore

@Suite("Разовые поступления")
struct ReceiptTests {
    private let ledger = Ledger(
        sources: [IncomeSource(name: "OD", salaryHistory: [salary("10000", from: day(2026, 8, 1))])],
        expenses: [expense("2000", on: day(2026, 8, 10))],
        receipts: [
            receipt("500", on: day(2026, 8, 3), kind: .gift, title: "подарок на др"),
            receipt("300", on: day(2026, 8, 4), kind: .gift, title: "от брата"),
            receipt("120", on: day(2026, 8, 5), kind: .refund, title: "вернул Далер"),
            receipt("999", on: day(2026, 9, 1), kind: .sale, title: "продал стул")
        ]
    )

    @Test("Поступления входят в доход месяца, но не в оклады")
    func receiptsCountAsIncome() {
        #expect(calculator.salaries(ledger, in: ym(2026, 8)) == money("10000"))
        #expect(calculator.receipts(ledger, in: ym(2026, 8)) == money("920"))
        #expect(calculator.income(ledger, in: ym(2026, 8)) == money("10920"))
    }

    @Test("Чужой месяц не считается")
    func othersMonthIgnored() {
        #expect(calculator.receipts(ledger, in: ym(2026, 9)) == money("999"))
    }

    @Test("Остаток растёт на сумму поступлений")
    func remainingGrows() {
        let summary = calculator.summary(ledger, for: ym(2026, 8))
        #expect(summary.receipts == money("920"))
        #expect(summary.remaining == money("8920"))
    }

    @Test("Разбивка группирует по видам и сортирует по убыванию")
    func breakdownGroupsByKind() {
        let shares = calculator.receiptBreakdown(ledger, in: ym(2026, 8))
        #expect(shares.count == 2)
        #expect(shares.first?.kind == .gift)
        #expect(shares.first?.amount == money("800"))
        #expect(shares.last?.kind == .refund)
        #expect(shares.last?.amount == money("120"))
    }

    @Test("Поступления переносятся в следующий месяц вместе с окладом")
    func carryoverIncludesReceipts() {
        // Август: 10000 оклада + 920 подарков − 2000 трат = 8920.
        #expect(calculator.carryover(ledger, before: ym(2026, 9)) == money("8920"))
    }

    @Test("Цепочка переноса начинается и с поступления, если оно раньше трат")
    func chainStartsFromReceipt() {
        let early = Ledger(
            expenses: [expense("100", on: day(2026, 8, 1))],
            receipts: [receipt("400", on: day(2026, 6, 10))]
        )
        #expect(early.firstRecordedMonth(calendar: utc) == ym(2026, 6))
        // Июнь: +400, июль: без движения, значит к августу переходит 400.
        #expect(calculator.carryover(early, before: ym(2026, 8)) == money("400"))
    }

    @Test("Поступления месяца отдаются по возрастанию даты")
    func receiptsSorted() {
        let list = ledger.receipts(in: ym(2026, 8), calendar: utc)
        #expect(list.map(\.title) == ["подарок на др", "от брата", "вернул Далер"])
    }
}
