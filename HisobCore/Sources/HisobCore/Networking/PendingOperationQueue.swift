import Foundation

/// Очередь неотправленных операций, переживающая перезапуск приложения.
public actor PendingOperationQueue {
    private let fileURL: URL
    private var operations: [PendingOperation]

    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.operations = Self.read(from: fileURL)
    }

    public static func defaultURL(fileManager: FileManager = .default) throws -> URL {
        try LedgerSnapshotStore.directoryURL(fileManager: fileManager)
            .appendingPathComponent("pending-operations.json")
    }

    public var pending: [PendingOperation] { operations }
    public var count: Int { operations.count }
    public var isEmpty: Bool { operations.isEmpty }

    func enqueue(_ operation: PendingOperation) {
        operations.append(operation)
        operations = operations.collapsed()
        persist()
    }

    /// Применяет накопленные операции к состоянию, пришедшему с сервера.
    func applying(to ledger: Ledger) -> Ledger {
        var result = ledger
        for operation in operations {
            operation.apply(to: &result)
        }
        return result
    }

    /// Отправляет очередь по порядку. Останавливается на первой же неудаче
    /// и сохраняет остаток: пропускать операцию нельзя — следующие могут
    /// от неё зависеть.
    func flush(to repository: any LedgerRepository) async throws {
        while let next = operations.first {
            do {
                try await next.send(to: repository)
            } catch let error as APIError {
                if case .transport = error { throw error }
                // Сервер ответил и отверг операцию — повторять её бессмысленно,
                // она будет отвергаться вечно и заблокирует очередь.
                operations.removeFirst()
                persist()
                continue
            }
            operations.removeFirst()
            persist()
        }
    }

    func clear() {
        operations = []
        persist()
    }

    // MARK: - Диск

    private func persist() {
        guard let data = try? JSONEncoder().encode(operations) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func read(from url: URL) -> [PendingOperation] {
        guard let data = try? Data(contentsOf: url),
              let stored = try? JSONDecoder().decode([PendingOperation].self, from: data)
        else { return [] }
        return stored
    }
}
