import Foundation
import HisobCore

/// Собирает хранилище по текущим настройкам подключения.
enum RepositoryFactory {
    /// Настроенное подключение — сеть со снимком и очередью неотправленного.
    /// Ненастроенное — демонстрационные данные в памяти, чтобы приложение
    /// можно было посмотреть до подключения к серверу.
    @MainActor
    static func make(for settings: ConnectionSettings) -> any LedgerRepository {
        guard let configuration = settings.configuration else {
            return InMemoryLedgerRepository(ledger: PreviewData.ledger)
        }
        return makeRemote(configuration: configuration)
    }

    static func makeRemote(configuration: APIConfiguration) -> any LedgerRepository {
        let remote = RemoteLedgerRepository(configuration: configuration)

        guard let snapshotURL = try? LedgerSnapshotStore.defaultURL(),
              let queueURL = try? PendingOperationQueue.defaultURL()
        else {
            // Без доступа к папке приложения ни снимка, ни очереди быть
            // не может — работаем напрямую по сети.
            return remote
        }

        return OfflineFirstLedgerRepository(
            remote: remote,
            snapshots: LedgerSnapshotStore(fileURL: snapshotURL),
            queue: PendingOperationQueue(fileURL: queueURL)
        )
    }
}
