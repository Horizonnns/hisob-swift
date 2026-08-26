import Foundation
import Testing
@testable import HisobCore

@Suite("YearMonth")
struct YearMonthTests {
    @Test("Канонический вид дополняется нулями")
    func description() {
        #expect(ym(2026, 8).description == "2026-08")
        #expect(ym(2026, 12).description == "2026-12")
    }

    @Test("Разбирает и месяц, и полную дату")
    func parsing() {
        #expect(YearMonth("2026-08") == ym(2026, 8))
        #expect(YearMonth("2026-08-14") == ym(2026, 8))
        #expect(YearMonth("мусор") == nil)
        #expect(YearMonth("2026-13") == nil)
    }

    @Test("Сравнение идёт по времени, а не по строке")
    func ordering() {
        #expect(ym(2025, 12) < ym(2026, 1))
        #expect(ym(2026, 2) > ym(2026, 1))
        #expect(ym(2026, 8) == ym(2026, 8))
    }

    @Test("Сдвиг переходит через границу года в обе стороны")
    func shifting() {
        #expect(ym(2026, 12).adding(months: 1) == ym(2027, 1))
        #expect(ym(2026, 1).adding(months: -1) == ym(2025, 12))
        #expect(ym(2026, 8).adding(months: -12) == ym(2025, 8))
        #expect(ym(2026, 3).adding(months: 0) == ym(2026, 3))
    }

    @Test("Разница в месяцах")
    func distance() {
        #expect(ym(2026, 8).months(since: ym(2026, 6)) == 2)
        #expect(ym(2026, 1).months(since: ym(2025, 12)) == 1)
    }

    @Test("Месяц знает свои даты")
    func containsDate() {
        #expect(ym(2026, 8).contains(day(2026, 8, 1), calendar: utc))
        #expect(ym(2026, 8).contains(day(2026, 8, 31), calendar: utc))
        #expect(!ym(2026, 8).contains(day(2026, 9, 1), calendar: utc))
    }

    @Test("Кодируется строкой и читается обратно")
    func codableRoundTrip() throws {
        let encoded = try JSONEncoder().encode(ym(2026, 8))
        #expect(String(data: encoded, encoding: .utf8) == "\"2026-08\"")
        #expect(try JSONDecoder().decode(YearMonth.self, from: encoded) == ym(2026, 8))
    }

    @Test("Февраль не превращается в 31-е — старый строковый костыль невозможен")
    func noPhantomDays() {
        // В вебе оклад сравнивался со строкой "\(month)-31", то есть с датой,
        // которой в феврале не существует. Здесь сравниваются сами месяцы.
        #expect(ym(2026, 2).adding(months: 1) == ym(2026, 3))
    }
}
