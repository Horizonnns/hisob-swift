import Foundation
import Testing
@testable import HisobCore

/// Сетевые сюиты вложены в один сериализованный родительский.
///
/// `MockURLProtocol` держит очередь заготовленных ответов в статике —
/// иначе `URLProtocol` до неё не добраться. Пометка `.serialized` на
/// отдельном сюите разводит только тесты внутри него, а сами сюиты
/// продолжают идти параллельно и разбирают чужие ответы.
@Suite("Сеть", .serialized)
struct NetworkingTests {
    @Suite("Сетевое хранилище")
    struct RemoteLedgerRepositoryTests {
        @Test("Ответ сервера разбирается в доменную модель целиком")
        func loadsLedger() async throws {
            MockURLProtocol.reset(with: [.ok(ledgerJSON)])
            let ledger = try await makeRemoteRepository().load()

            #expect(ledger.currency == .tjs)
            #expect(ledger.sources.count == 2)
            #expect(ledger.expenses.count == 2)

            let od = try #require(ledger.sources.first { $0.name == "OD" })
            #expect(od.endedAt == nil)
            #expect(od.salary(in: ym(2026, 8), calendar: utc) == money("10120"))

            let asrmall = try #require(ledger.sources.first { $0.name == "asrmall" })
            #expect(asrmall.endedAt == ym(2026, 7))
            #expect(asrmall.salary(in: ym(2026, 8), calendar: utc) == .zero)
        }

        @Test("Суммы приходят строками и разбираются точно")
        func parsesDecimalAmounts() async throws {
            MockURLProtocol.reset(with: [.ok(ledgerJSON)])
            let ledger = try await makeRemoteRepository().load()

            let group = try #require(ledger.expenses.first { $0.isGroup })
            #expect(group.total == money("1923.63"))

            let single = try #require(ledger.expenses.first { !$0.isGroup })
            #expect(single.total == money("13"))
        }

        @Test("Группа и одиночная трата различаются по наличию amount")
        func distinguishesExpenseKind() async throws {
            MockURLProtocol.reset(with: [.ok(ledgerJSON)])
            let ledger = try await makeRemoteRepository().load()

            #expect(ledger.expenses.filter(\.isGroup).count == 1)
            #expect(ledger.expenses.filter { !$0.isGroup }.count == 1)
        }

        @Test("Противоречивая запись от сервера отвергается, а не толкуется наугад")
        func rejectsAmbiguousExpense() async {
            let broken = """
            { "currency": "TJS", "sources": [], "expenses": [
              { "id": "33333333-3333-4333-8333-333333333333", "date": "2026-08-02",
                "category": "food", "title": "оба поля", "amount": "10.00",
                "items": [{ "id": "cccccccc-1111-4111-8111-111111111111",
                            "amount": "5.00", "title": "x" }],
                "incomeSourceId": null }
            ]}
            """
            MockURLProtocol.reset(with: [.ok(broken)])
            await #expect(throws: DTOMappingError.self) {
                _ = try await makeRemoteRepository().load()
            }
        }

        @Test("Запрос уходит с токеном в заголовке")
        func sendsBearerToken() async throws {
            MockURLProtocol.reset(with: [.ok(ledgerJSON)])
            _ = try await makeRemoteRepository().load()

            let request = try #require(MockURLProtocol.recorded.first)
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
            #expect(request.url?.path == "/api/ledger")
            #expect(request.httpMethod == "GET")
        }

        @Test("Создание траты уходит POST со стабильным id и суммой строкой")
        func addsExpense() async throws {
            MockURLProtocol.reset(with: [.ok("""
            { "id": "33333333-3333-4333-8333-333333333333", "date": "2026-08-02",
              "category": "food", "title": "rc-cola", "amount": "13.00",
              "items": [], "incomeSourceId": null }
            """, status: 201)])

            let expense = Expense.single(
                id: UUID(uuidString: "33333333-3333-4333-8333-333333333333")!,
                date: day(2026, 8, 2), category: .food, title: "rc-cola", amount: money("13")
            )
            try await makeRemoteRepository().add(expense)

            let request = try #require(MockURLProtocol.recorded.first)
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path == "/api/expenses")

            let body = try #require(request.httpBody)
            let sent = try JSONDecoder().decode(ExpenseDTO.self, from: body)
            #expect(sent.id == expense.id)
            #expect(sent.amount == "13")
            #expect(sent.items.isEmpty)
            #expect(sent.date == "2026-08-02")
        }

        @Test("Группа уходит без amount, но с позициями")
        func addsGroupExpense() async throws {
            MockURLProtocol.reset(with: [.ok("{}", status: 201)])
            let expense = Expense.group(
                date: day(2026, 8, 2), category: .loan, title: "хумо",
                items: [
                    ExpenseItem(amount: money("1000"), title: "основной платёж"),
                    ExpenseItem(amount: money("923.63"), title: "проценты")
                ]
            )
            // Ответ намеренно пустой: важно, что именно ушло на сервер.
            _ = try? await makeRemoteRepository().add(expense)

            let body = try #require(MockURLProtocol.recorded.first?.httpBody)
            let sent = try JSONDecoder().decode(ExpenseDTO.self, from: body)
            #expect(sent.amount == nil)
            #expect(sent.items.count == 2)
            #expect(sent.items.map(\.amount) == ["1000", "923.63"])
        }

        @Test("Удаление уходит DELETE по идентификатору")
        func deletesExpense() async throws {
            MockURLProtocol.reset(with: [.ok("{\"ok\":true}")])
            let id = UUID()
            try await makeRemoteRepository().delete(expenseID: id)

            let request = try #require(MockURLProtocol.recorded.first)
            #expect(request.httpMethod == "DELETE")
            #expect(request.url?.path == "/api/expenses/\(id.uuidString)")
        }

        @Test("Источник сохраняется PUT вместе с историей оклада")
        func savesSource() async throws {
            MockURLProtocol.reset(with: [.ok("{}")])
            let source = IncomeSource(
                name: "OD",
                role: "Team-Lead",
                salaryHistory: [salary("9980", from: day(2026, 6, 10))],
                endedAt: ym(2026, 12)
            )
            _ = try? await makeRemoteRepository().save(source)

            let request = try #require(MockURLProtocol.recorded.first)
            #expect(request.httpMethod == "PUT")
            #expect(request.url?.path == "/api/sources/\(source.id.uuidString)")

            let sent = try JSONDecoder().decode(IncomeSourceDTO.self, from: #require(request.httpBody))
            #expect(sent.endedAt == "2026-12")
            #expect(sent.salaries.first?.effectiveFrom == "2026-06-10")
            #expect(sent.salaries.first?.amount == "9980")
        }

        @Test("Статусы отображаются в осмысленные ошибки")
        func mapsErrorStatuses() async {
            let cases: [(Int, String, APIError)] = [
                (401, "{\"error\":\"Unauthorized\"}", .unauthorized),
                (404, "{\"error\":\"Expense not found\"}", .notFound),
                (409, "{\"error\":\"Expense already exists\"}", .conflict),
                (503, "{\"error\":\"HISOB_API_TOKEN is not configured\"}", .serverNotConfigured),
                (500, "{\"error\":\"Internal error\"}", .server(status: 500))
            ]

            for (status, body, expected) in cases {
                MockURLProtocol.reset(with: [.ok(body, status: status)])
                await #expect(throws: expected) {
                    _ = try await makeRemoteRepository().load()
                }
            }
        }

        @Test("Текст ошибки валидации доходит до пользователя")
        func surfacesValidationMessage() async {
            MockURLProtocol.reset(with: [
                .ok("{\"error\":\"Укажите либо amount, либо непустой items\"}", status: 400)
            ])
            await #expect(throws: APIError.invalidRequest("Укажите либо amount, либо непустой items")) {
                _ = try await makeRemoteRepository().load()
            }
        }

        @Test("Обрыв связи отличается от ошибки сервера")
        func mapsTransportFailure() async {
            MockURLProtocol.reset(with: [.offline()])
            do {
                _ = try await makeRemoteRepository().load()
                Issue.record("Ожидалась ошибка транспорта")
            } catch let error as APIError {
                guard case .transport = error else {
                    Issue.record("Получено \(error) вместо .transport")
                    return
                }
            } catch {
                Issue.record("Неожиданный тип ошибки: \(error)")
            }
        }
    }

    @Suite("Кэш поверх сети")
    struct CachedLedgerRepositoryTests {
        private func makeStore() throws -> (LedgerSnapshotStore, URL) {
            let directory = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("hisob-tests-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("snapshot.json")
            return (LedgerSnapshotStore(fileURL: url), directory)
        }

        @Test("Успешная загрузка сохраняет снимок")
        func savesSnapshotOnLoad() async throws {
            let (snapshots, directory) = try makeStore()
            defer { try? FileManager.default.removeItem(at: directory) }

            MockURLProtocol.reset(with: [.ok(ledgerJSON)])
            let cached = CachedLedgerRepository(remote: makeRemoteRepository(), snapshots: snapshots)
            _ = try await cached.load()

            let stored = await snapshots.load()
            #expect(stored?.expenses.count == 2)
            #expect(stored?.sources.count == 2)
        }

        @Test("Без сети отдаётся последний снимок")
        func fallsBackToSnapshotOffline() async throws {
            let (snapshots, directory) = try makeStore()
            defer { try? FileManager.default.removeItem(at: directory) }

            // Первый заход — сеть есть, снимок сохранён.
            MockURLProtocol.reset(with: [.ok(ledgerJSON)])
            let cached = CachedLedgerRepository(remote: makeRemoteRepository(), snapshots: snapshots)
            _ = try await cached.load()

            // Второй — сети нет.
            MockURLProtocol.reset(with: [.offline()])
            let offline = try await cached.load()
            #expect(offline.expenses.count == 2)
            #expect(offline.sources.count == 2)
            // Суммы переживают сериализацию снимка без потери точности.
            #expect(offline.expenses.first { $0.isGroup }?.total == money("1923.63"))
        }

        @Test("Без сети и без снимка ошибка пробрасывается")
        func failsWithoutSnapshot() async throws {
            let (snapshots, directory) = try makeStore()
            defer { try? FileManager.default.removeItem(at: directory) }

            MockURLProtocol.reset(with: [.offline()])
            let cached = CachedLedgerRepository(remote: makeRemoteRepository(), snapshots: snapshots)
            await #expect(throws: APIError.self) {
                _ = try await cached.load()
            }
        }

        @Test("На 401 снимок не подставляется")
        func doesNotMaskUnauthorized() async throws {
            let (snapshots, directory) = try makeStore()
            defer { try? FileManager.default.removeItem(at: directory) }

            MockURLProtocol.reset(with: [.ok(ledgerJSON)])
            let cached = CachedLedgerRepository(remote: makeRemoteRepository(), snapshots: snapshots)
            _ = try await cached.load()

            // Токен отозвали: показывать данные дальше нельзя, даже если снимок есть.
            MockURLProtocol.reset(with: [.ok("{\"error\":\"Unauthorized\"}", status: 401)])
            await #expect(throws: APIError.unauthorized) {
                _ = try await cached.load()
            }
        }

        @Test("Запись без сети падает, а не копится молча")
        func writeFailsOffline() async throws {
            let (snapshots, directory) = try makeStore()
            defer { try? FileManager.default.removeItem(at: directory) }

            MockURLProtocol.reset(with: [.offline()])
            let cached = CachedLedgerRepository(remote: makeRemoteRepository(), snapshots: snapshots)
            await #expect(throws: APIError.self) {
                try await cached.add(expense("100", on: day(2026, 8, 1)))
            }
        }
    }
}
