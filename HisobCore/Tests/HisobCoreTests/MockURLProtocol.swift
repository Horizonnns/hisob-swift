import Foundation

/// Перехватывает запросы `URLSession` и отвечает заранее заданным ответом.
///
/// Так сетевой слой проверяется целиком — сборка запроса, заголовки, разбор
/// ответа и отображение статусов в ошибки — без сервера и без сети.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    struct Stub: Sendable {
        var status: Int
        var body: Data
        /// Ошибка транспорта вместо ответа — имитация отсутствия сети.
        var transportError: (any Error)?

        static func ok(_ json: String, status: Int = 200) -> Stub {
            Stub(status: status, body: Data(json.utf8), transportError: nil)
        }

        static func offline() -> Stub {
            Stub(
                status: 0,
                body: Data(),
                transportError: URLError(.notConnectedToInternet)
            )
        }
    }

    /// Записанные запросы — по ним проверяются метод, путь и заголовки.
    private(set) static nonisolated(unsafe) var recorded: [URLRequest] = []
    private static nonisolated(unsafe) var stubs: [Stub] = []
    private static let lock = NSLock()

    static func reset(with stubs: [Stub]) {
        lock.lock()
        defer { lock.unlock() }
        self.stubs = stubs
        recorded = []
    }

    static func nextStub() -> Stub {
        lock.lock()
        defer { lock.unlock() }
        return stubs.isEmpty ? .ok("{}") : stubs.removeFirst()
    }

    static func record(_ request: URLRequest) {
        lock.lock()
        defer { lock.unlock() }
        recorded.append(request)
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        // httpBody у перехваченного запроса пуст — тело доступно только
        // через поток, поэтому вычитываем его вручную для проверок в тестах.
        var recordable = request
        if recordable.httpBody == nil, let stream = request.httpBodyStream {
            recordable.httpBody = Self.readAll(stream)
        }
        Self.record(recordable)

        let stub = Self.nextStub()

        if let error = stub.transportError {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stub.status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func readAll(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        let size = 4096
        var buffer = [UInt8](repeating: 0, count: size)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: size)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
