import HisobCore
import SwiftUI

@main
struct HisobApp: App {
    /// Пока хранилище в памяти: слой представления от этого не зависит,
    /// подмена на SwiftData или сеть — замена одной реализации протокола.
    @State private var store = LedgerStore(
        repository: InMemoryLedgerRepository(ledger: PreviewData.ledger)
    )

    var body: some Scene {
        WindowGroup {
            RootTabView(store: store)
        }
    }
}
