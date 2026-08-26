import Foundation
import HisobCore

/// Собирает хранилище по текущим настройкам подключения.
enum RepositoryFactory {
    /// Настроенное подключение — сеть с локальным снимком.
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

        guard let url = try? LedgerSnapshotStore.defaultURL() else {
            // Без доступа к папке приложения кэш недоступен — работаем
            // напрямую по сети, это хуже, но не смертельно.
            return remote
        }
        return CachedLedgerRepository(
            remote: remote,
            snapshots: LedgerSnapshotStore(fileURL: url)
        )
    }
}
