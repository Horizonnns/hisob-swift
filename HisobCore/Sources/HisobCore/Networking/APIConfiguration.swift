import Foundation

/// Адрес и токен доступа к API.
public struct APIConfiguration: Hashable, Sendable {
    public let baseURL: URL
    public let token: String

    public init(baseURL: URL, token: String) {
        self.baseURL = baseURL
        self.token = token
    }

    /// Разбирает адрес, введённый пользователем: дописывает схему и убирает
    /// хвостовой слэш, чтобы «hisob.vercel.app/» и «https://hisob.vercel.app»
    /// давали один и тот же результат.
    public init?(rawURL: String, token: String) {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !token.isEmpty else { return nil }

        let withScheme = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        let withoutTrailingSlash = withScheme.hasSuffix("/")
            ? String(withScheme.dropLast())
            : withScheme

        guard let url = URL(string: withoutTrailingSlash), url.host != nil else { return nil }
        self.init(baseURL: url, token: token)
    }
}

/// Ошибки обращения к API.
public enum APIError: Error, Equatable, Sendable {
    /// Токен неверен или не передан.
    case unauthorized
    /// На сервере не задан `HISOB_API_TOKEN`.
    case serverNotConfigured
    case notFound
    case conflict
    /// Сервер отклонил тело запроса; текст пригоден для показа.
    case invalidRequest(String)
    case server(status: Int)
    /// Сеть недоступна.
    case transport(String)
    case decoding(String)
}

extension APIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            "Неверный токен доступа"
        case .serverNotConfigured:
            "На сервере не задан токен доступа"
        case .notFound:
            "Запись не найдена"
        case .conflict:
            "Такая запись уже существует"
        case .invalidRequest(let message):
            message
        case .server(let status):
            "Ошибка сервера (\(status))"
        case .transport:
            "Нет связи с сервером"
        case .decoding:
            "Сервер вернул неожиданный ответ"
        }
    }
}
