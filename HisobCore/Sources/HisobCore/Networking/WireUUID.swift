import Foundation

/// Идентификатор в том виде, в каком он ходит по сети.
///
/// `UUID.uuidString` в Swift всегда прописной, а идентификаторы в базе —
/// строчные. PostgreSQL сравнивает строки с учётом регистра, поэтому
/// запрос с прописным идентификатором не находил существующую запись
/// и создавал дубликат вместо изменения.
///
/// Тип приводит регистр в одном месте — и при кодировании, и в путях URL.
struct WireUUID: Codable, Hashable, Sendable {
    let value: UUID

    init(_ value: UUID) {
        self.value = value
    }

    /// Строка для тела запроса и для пути.
    var wireValue: String {
        value.uuidString.lowercased()
    }

    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let parsed = UUID(uuidString: raw) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Некорректный UUID: \(raw)")
            )
        }
        self.value = parsed
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wireValue)
    }
}

extension UUID {
    /// Идентификатор для пути URL — в том же регистре, что и в теле запроса.
    var wirePath: String { uuidString.lowercased() }
}
