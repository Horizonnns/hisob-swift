import HisobCore
import SwiftUI

@main
struct HisobApp: App {
    @State private var connection: ConnectionSettings
    @State private var store: LedgerStore

    init() {
        let connection = ConnectionSettings()
        _connection = State(initialValue: connection)
        _store = State(initialValue: LedgerStore(repository: RepositoryFactory.make(for: connection)))
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(store: store, connection: connection)
        }
    }
}
