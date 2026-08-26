import Foundation
import Testing
@testable import HisobCore

@Suite("Разбор дня")
struct DayStringTests {
    @Test("День собирается и разбирается в одном календаре")
    func roundTrip() {
        let date = day(2026, 8, 2)
        #expect(DayString.string(from: date, calendar: utc) == "2026-08-02")
        #expect(DayString.date(from: "2026-08-02", calendar: utc).map {
            DayString.string(from: $0, calendar: utc)
        } == "2026-08-02")
    }

    @Test("Первое число не уезжает в предыдущий месяц в западном поясе")
    func firstDayKeepsItsMonth() throws {
        // Разбор в UTC-полночь для UTC-5 дал бы 31 августа — трата попала бы
        // в чужой месяц. Полдень в календаре пользователя это исключает.
        var western = Calendar(identifier: .gregorian)
        western.timeZone = try #require(TimeZone(secondsFromGMT: -5 * 3600))

        let parsed = try #require(DayString.date(from: "2026-09-01", calendar: western))
        #expect(YearMonth(date: parsed, calendar: western) == ym(2026, 9))
        #expect(DayString.string(from: parsed, calendar: western) == "2026-09-01")
    }

    @Test("Мусор не разбирается")
    func rejectsGarbage() {
        #expect(DayString.date(from: "2026-08", calendar: utc) == nil)
        #expect(DayString.date(from: "не дата", calendar: utc) == nil)
    }
}

@Suite("Адрес API")
struct APIConfigurationTests {
    @Test("Схема дописывается, хвостовой слэш убирается")
    func normalizesRawURL() {
        let variants = ["hisob.vercel.app", "https://hisob.vercel.app", "https://hisob.vercel.app/"]
        for raw in variants {
            let configuration = APIConfiguration(rawURL: raw, token: "t")
            #expect(configuration?.baseURL.absoluteString == "https://hisob.vercel.app", "не сошлось на \(raw)")
        }
    }

    @Test("Пустые значения отвергаются")
    func rejectsEmpty() {
        #expect(APIConfiguration(rawURL: "", token: "t") == nil)
        #expect(APIConfiguration(rawURL: "hisob.vercel.app", token: "") == nil)
        #expect(APIConfiguration(rawURL: "   ", token: "t") == nil)
    }
}
