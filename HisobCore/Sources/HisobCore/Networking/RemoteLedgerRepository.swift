import Foundation

/// Хранилище поверх HTTP API.
public struct RemoteLedgerRepository: LedgerRepository {
    private let client: HisobAPIClient
    private let calendar: Calendar

    public init(client: HisobAPIClient, calendar: Calendar = .current) {
        self.client = client
        self.calendar = calendar
    }

    public init(configuration: APIConfiguration, session: URLSession? = nil, calendar: Calendar = .current) {
        self.init(client: HisobAPIClient(configuration: configuration, session: session), calendar: calendar)
    }

    public func load() async throws -> Ledger {
        let dto = try await client.get("/api/ledger", as: LedgerDTO.self)
        return try dto.toDomain(calendar: calendar)
    }

    public func add(_ expense: Expense) async throws {
        _ = try await client.send(
            "/api/expenses",
            method: "POST",
            body: ExpenseDTO(expense, calendar: calendar),
            as: ExpenseDTO.self
        )
    }

    public func update(_ expense: Expense) async throws {
        _ = try await client.send(
            "/api/expenses/\(expense.id.wirePath)",
            method: "PATCH",
            body: ExpenseDTO(expense, calendar: calendar),
            as: ExpenseDTO.self
        )
    }

    public func delete(expenseID: Expense.ID) async throws {
        try await client.send("/api/expenses/\(expenseID.wirePath)", method: "DELETE")
    }

    public func add(_ receipt: Receipt) async throws {
        _ = try await client.send(
            "/api/receipts",
            method: "POST",
            body: ReceiptDTO(receipt, calendar: calendar),
            as: ReceiptDTO.self
        )
    }

    public func update(_ receipt: Receipt) async throws {
        _ = try await client.send(
            "/api/receipts/\(receipt.id.wirePath)",
            method: "PATCH",
            body: ReceiptDTO(receipt, calendar: calendar),
            as: ReceiptDTO.self
        )
    }

    public func delete(receiptID: Receipt.ID) async throws {
        try await client.send("/api/receipts/\(receiptID.wirePath)", method: "DELETE")
    }

    public func save(_ source: IncomeSource) async throws {
        _ = try await client.send(
            "/api/sources/\(source.id.wirePath)",
            method: "PUT",
            body: IncomeSourceDTO(source, calendar: calendar),
            as: IncomeSourceDTO.self
        )
    }

    public func delete(sourceID: IncomeSource.ID) async throws {
        try await client.send("/api/sources/\(sourceID.wirePath)", method: "DELETE")
    }

    public func setCurrency(_ currency: CurrencyCode) async throws {
        _ = try await client.send(
            "/api/settings",
            method: "PATCH",
            body: SettingsDTO(currency: currency.rawValue),
            as: SettingsDTO.self
        )
    }
}

private struct SettingsDTO: Codable, Sendable {
    var currency: String
}
