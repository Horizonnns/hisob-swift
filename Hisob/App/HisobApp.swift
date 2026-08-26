import HisobCore
import SwiftUI

@main
struct HisobApp: App {
    /// Пока хранилище в памяти: слой представления от этого не зависит,
    /// подмена на SwiftData или сеть — замена одной реализации протокола.
    private let repository: any LedgerRepository = InMemoryLedgerRepository(ledger: PreviewData.ledger)

    var body: some Scene {
        WindowGroup {
            RootTabView(repository: repository)
        }
    }
}
