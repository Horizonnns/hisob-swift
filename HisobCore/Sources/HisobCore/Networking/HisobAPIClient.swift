import Foundation

/// Тонкий HTTP-клиент к API.
public struct HisobAPIClient: Sendable {
    private let configuration: APIConfiguration
    private let session: URLSession

    public init(configuration: APIConfiguration, session: URLSession? = nil) {
        self.configuration = configuration
        self.session = session ?? Self.makeSession()
    }

    /// Сессия с коротким таймаутом.
    ///
    /// По умолчанию `URLSession` ждёт ответа 60 секунд, а ресурс — неделю.
    /// Для приложения, где кнопка «Сохранить» блокируется на время запроса,
    /// это выглядит как зависание: пользователь не понимает, идёт ли что-то.
    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }

    // MARK: - Запросы

    func get<Response: Decodable>(_ path: String, as type: Response.Type) async throws -> Response {
        try await perform(request(path: path, method: "GET", body: Optional<Never>.none), as: type)
    }

    func send<Body: Encodable, Response: Decodable>(
        _ path: String,
        method: String,
        body: Body,
        as type: Response.Type
    ) async throws -> Response {
        try await perform(request(path: path, method: method, body: body), as: type)
    }

    func send(_ path: String, method: String) async throws {
        _ = try await perform(
            request(path: path, method: method, body: Optional<Never>.none),
            as: EmptyResponse.self
        )
    }

    /// Проверка связи и токена: дёргает защищённый роут и убеждается,
    /// что ответ пришёл и разобрался.
    public func checkConnection() async throws {
        _ = try await get("/api/ledger", as: LedgerDTO.self)
    }

    // MARK: - Внутреннее

    private func request<Body: Encodable>(
        path: String,
        method: String,
        body: Body?
    ) throws -> URLRequest {
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("Bearer \(configuration.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        return request
    }

    private func perform<Response: Decodable>(
        _ request: URLRequest,
        as type: Response.Type
    ) async throws -> Response {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await send(request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.decoding("Ответ без HTTP-статуса")
        }

        guard (200..<300).contains(http.statusCode) else {
            throw mapFailure(status: http.statusCode, data: data)
        }

        if Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }

    /// Отправляет запрос, повторяя один раз при обрыве соединения.
    ///
    /// Сервер и промежуточные узлы закрывают простаивающие keep-alive
    /// соединения, а `URLSession` успевает переиспользовать уже закрытое —
    /// запрос падает с `networkConnectionLost`. Идемпотентные GET система
    /// повторяет сама, а POST/PUT/PATCH/DELETE — нет.
    ///
    /// Наши записи идемпотентны по построению: идентификатор задаёт клиент,
    /// PUT перезаписывает целиком, повторный POST отвечает 409. Поэтому
    /// повтор безопасен.
    private func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError where Self.isRetryable(error) {
            try await Task.sleep(for: .milliseconds(300))
            return try await session.data(for: request)
        }
    }

    private static func isRetryable(_ error: URLError) -> Bool {
        [.networkConnectionLost, .timedOut, .cannotConnectToHost, .dnsLookupFailed]
            .contains(error.code)
    }

    private func mapFailure(status: Int, data: Data) -> APIError {
        let message = (try? JSONDecoder().decode(ErrorEnvelope.self, from: data))?.error

        switch status {
        case 401: return .unauthorized
        case 404: return .notFound
        case 409: return .conflict
        case 503: return .serverNotConfigured
        case 400: return .invalidRequest(message ?? "Некорректный запрос")
        default: return .server(status: status)
        }
    }
}

private struct ErrorEnvelope: Decodable {
    let error: String
}

/// Ответы вида `{ "ok": true }`, содержимое которых не нужно.
struct EmptyResponse: Decodable {}
