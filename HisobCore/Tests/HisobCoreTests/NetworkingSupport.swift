import Foundation
@testable import HisobCore

let testConfiguration = APIConfiguration(
    baseURL: URL(string: "https://hisob.example.com")!,
    token: "test-token"
)

func makeRemoteRepository() -> RemoteLedgerRepository {
    RemoteLedgerRepository(
        client: HisobAPIClient(configuration: testConfiguration, session: MockURLProtocol.makeSession()),
        calendar: utc
    )
}

/// Ответ `/api/ledger` с двумя источниками и двумя тратами — одиночной
/// и групповой.
let ledgerJSON = """
{
  "currency": "TJS",
  "sources": [
    {
      "id": "11111111-1111-4111-8111-111111111111",
      "name": "OD",
      "role": "Team-Lead",
      "endedAt": null,
      "salaries": [
        { "id": "aaaaaaaa-1111-4111-8111-111111111111",
          "effectiveFrom": "2026-06-10", "amount": "9980.00" },
        { "id": "aaaaaaaa-2222-4222-8222-222222222222",
          "effectiveFrom": "2026-08-01", "amount": "10120.00" }
      ]
    },
    {
      "id": "22222222-2222-4222-8222-222222222222",
      "name": "asrmall",
      "role": "Frontend Engineer",
      "endedAt": "2026-07",
      "salaries": [
        { "id": "bbbbbbbb-1111-4111-8111-111111111111",
          "effectiveFrom": "2026-01-01", "amount": "5000.00" }
      ]
    }
  ],
  "expenses": [
    {
      "id": "33333333-3333-4333-8333-333333333333",
      "date": "2026-08-02", "category": "food", "title": "rc-cola",
      "amount": "13.00", "items": [], "incomeSourceId": null
    },
    {
      "id": "44444444-4444-4444-8444-444444444444",
      "date": "2026-08-02", "category": "loan", "title": "хумо",
      "amount": null,
      "items": [
        { "id": "cccccccc-1111-4111-8111-111111111111",
          "amount": "1000.00", "title": "основной платёж" },
        { "id": "cccccccc-2222-4222-8222-222222222222",
          "amount": "923.63", "title": "проценты" }
      ],
      "incomeSourceId": null
    }
  ]
}
"""
