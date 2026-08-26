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
            #expect(sent.id.value == expense.id)
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
            #expect(request.url?.path == "/api/expenses/\(id.wirePath)")
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
            #expect(request.url?.path == "/api/sources/\(source.id.wirePath)")

            let sent = try JSONDecoder().decode(IncomeSourceDTO.self, from: #require(request.httpBody))
            #expect(sent.endedAt == "2026-12")
            #expect(sent.salaries.first?.effectiveFrom == "2026-06-10")
            #expect(sent.salaries.first?.amount == "9980")
        }

        @Test("Идентификаторы уходят в нижнем регистре — и в пути, и в теле")
        func identifiersAreLowercased() async throws {
            // UUID.uuidString в Swift прописной, а идентификаторы в базе строчные.
            // PostgreSQL сравнивает строки с учётом регистра: прописной запрос
            // не нашёл бы запись и создал дубликат вместо изменения.
            MockURLProtocol.reset(with: [.ok("{}")])
            let source = IncomeSource(
                name: "OD",
                salaryHistory: [salary("9980", from: day(2026, 6, 10))]
            )
            _ = try? await makeRemoteRepository().save(source)

            let request = try #require(MockURLProtocol.recorded.first)
            let path = try #require(request.url?.path)
            #expect(path == path.lowercased(), "путь содержит прописные символы: \(path)")

            let body = try #require(request.httpBody)
            let json = try #require(String(data: body, encoding: .utf8))
            let sent = try JSONDecoder().decode(IncomeSourceDTO.self, from: body)
            #expect(json.contains(sent.id.wireValue), "идентификатор в теле должен быть строчным")
            #expect(sent.id.wireValue == sent.id.wireValue.lowercased())
            #expect(sent.salaries.allSatisfy { $0.id.wireValue == $0.id.wireValue.lowercased() })
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

    @Suite("Работа без сети")
    struct OfflineTests {
        private func makeStores() throws -> (LedgerSnapshotStore, PendingOperationQueue, URL) {
            let directory = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("hisob-offline-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return (
                LedgerSnapshotStore(fileURL: directory.appendingPathComponent("snapshot.json")),
                PendingOperationQueue(fileURL: directory.appendingPathComponent("queue.json")),
                directory
            )
        }

        private func makeRepository(
            _ snapshots: LedgerSnapshotStore,
            _ queue: PendingOperationQueue
        ) -> OfflineFirstLedgerRepository {
            OfflineFirstLedgerRepository(remote: makeRemoteRepository(), snapshots: snapshots, queue: queue)
        }

        // MARK: - Чтение

        @Test("Успешная загрузка сохраняет снимок")
        func savesSnapshot() async throws {
            let (snapshots, queue, directory) = try makeStores()
            defer { try? FileManager.default.removeItem(at: directory) }

            MockURLProtocol.reset(with: [.ok(ledgerJSON)])
            _ = try await makeRepository(snapshots, queue).load()

            #expect(await snapshots.load()?.expenses.count == 2)
        }

        @Test("Без сети отдаётся снимок")
        func fallsBackToSnapshot() async throws {
            let (snapshots, queue, directory) = try makeStores()
            defer { try? FileManager.default.removeItem(at: directory) }
            let repository = makeRepository(snapshots, queue)

            MockURLProtocol.reset(with: [.ok(ledgerJSON)])
            _ = try await repository.load()

            MockURLProtocol.reset(with: [.offline()])
            let offline = try await repository.load()
            #expect(offline.expenses.count == 2)
            #expect(offline.expenses.first { $0.isGroup }?.total == money("1923.63"))
        }

        @Test("На 401 снимок не подставляется")
        func doesNotMaskUnauthorized() async throws {
            let (snapshots, queue, directory) = try makeStores()
            defer { try? FileManager.default.removeItem(at: directory) }
            let repository = makeRepository(snapshots, queue)

            MockURLProtocol.reset(with: [.ok(ledgerJSON)])
            _ = try await repository.load()

            MockURLProtocol.reset(with: [.ok("{\"error\":\"Unauthorized\"}", status: 401)])
            await #expect(throws: APIError.unauthorized) { _ = try await repository.load() }
        }

        // MARK: - Запись

        @Test("Запись без сети не падает, а встаёт в очередь")
        func queuesWriteOffline() async throws {
            let (snapshots, queue, directory) = try makeStores()
            defer { try? FileManager.default.removeItem(at: directory) }
            let repository = makeRepository(snapshots, queue)

            MockURLProtocol.reset(with: [.ok(ledgerJSON)])
            _ = try await repository.load()

            MockURLProtocol.reset(with: [.offline()])
            try await repository.add(expense("100", on: day(2026, 8, 20), title: "офлайн"))

            #expect(await queue.count == 1)
        }

        @Test("Неотправленная трата видна в списке до появления связи")
        func pendingWriteIsVisible() async throws {
            let (snapshots, queue, directory) = try makeStores()
            defer { try? FileManager.default.removeItem(at: directory) }
            let repository = makeRepository(snapshots, queue)

            MockURLProtocol.reset(with: [.ok(ledgerJSON)])
            _ = try await repository.load()

            MockURLProtocol.reset(with: [.offline()])
            try await repository.add(expense("100", on: day(2026, 8, 20), title: "офлайн"))

            // Ещё раз без сети. Два ответа: `load()` при непустой очереди
            // сначала пытается её разгрузить, и только потом читает.
            MockURLProtocol.reset(with: [.offline(), .offline()])
            let ledger = try await repository.load()
            #expect(ledger.expenses.count == 3)
            #expect(ledger.expenses.contains { $0.title == "офлайн" })
        }

        @Test("Отказ сервера остаётся ошибкой и в очередь не попадает")
        func serverRejectionStillThrows() async throws {
            let (snapshots, queue, directory) = try makeStores()
            defer { try? FileManager.default.removeItem(at: directory) }
            let repository = makeRepository(snapshots, queue)

            MockURLProtocol.reset(with: [.ok("{\"error\":\"Expense already exists\"}", status: 409)])
            await #expect(throws: APIError.conflict) {
                try await repository.add(expense("100", on: day(2026, 8, 20)))
            }
            #expect(await queue.isEmpty)
        }

        @Test("При следующей загрузке очередь уходит на сервер")
        func flushesOnNextLoad() async throws {
            let (snapshots, queue, directory) = try makeStores()
            defer { try? FileManager.default.removeItem(at: directory) }
            let repository = makeRepository(snapshots, queue)

            MockURLProtocol.reset(with: [.ok(ledgerJSON)])
            _ = try await repository.load()

            MockURLProtocol.reset(with: [.offline()])
            try await repository.add(expense("100", on: day(2026, 8, 20), title: "офлайн"))
            #expect(await queue.count == 1)

            // Связь вернулась. Чтение очередь не трогает — она уходит
            // отдельным вызовом, чтобы неудачная отправка не задерживала показ.
            MockURLProtocol.reset(with: [.ok(ledgerJSON)])
            _ = try await repository.load()
            #expect(await queue.count == 1, "чтение не должно отправлять очередь")

            MockURLProtocol.reset(with: [.ok("{}", status: 201)])
            #expect(await repository.flushPending())
            #expect(await queue.isEmpty)
        }

        @Test("Изменение источника без сети видно в списке до отправки")
        func queuedSourceChangeIsVisible() async throws {
            let (snapshots, queue, directory) = try makeStores()
            defer { try? FileManager.default.removeItem(at: directory) }
            let repository = makeRepository(snapshots, queue)

            MockURLProtocol.reset(with: [.ok(ledgerJSON)])
            let before = try await repository.load()
            var od = try #require(before.sources.first { $0.name == "OD" })
            #expect(od.endedAt == nil)

            // Завершаем работу без связи.
            od.endedAt = ym(2026, 8)
            MockURLProtocol.reset(with: [.offline()])
            try await repository.save(od)
            #expect(await queue.count == 1)

            // Читаем снова: сервер по-прежнему отдаёт старое состояние,
            // но неотправленное изменение должно быть наложено сверху.
            MockURLProtocol.reset(with: [.offline(), .ok(ledgerJSON)])
            let after = try await repository.load()
            let stored = try #require(after.sources.first { $0.name == "OD" })
            #expect(stored.endedAt == ym(2026, 8), "неотправленное завершение работы должно быть видно")
        }

        @Test("Очередь переживает перезапуск приложения")
        func queueSurvivesRestart() async throws {
            let (snapshots, queue, directory) = try makeStores()
            defer { try? FileManager.default.removeItem(at: directory) }
            let queueURL = directory.appendingPathComponent("queue.json")

            MockURLProtocol.reset(with: [.ok(ledgerJSON)])
            _ = try await makeRepository(snapshots, queue).load()

            MockURLProtocol.reset(with: [.offline()])
            try await makeRepository(snapshots, queue)
                .add(expense("100", on: day(2026, 8, 20), title: "офлайн"))

            // Новый экземпляр читает очередь с диска — как после перезапуска.
            let restored = PendingOperationQueue(fileURL: queueURL)
            #expect(await restored.count == 1)
        }
    }
}
