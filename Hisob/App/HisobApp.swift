import HisobCore
import SwiftUI

@main
struct HisobApp: App {
    @State private var connection: ConnectionSettings
    @State private var store: LedgerStore
    @State private var lock = BiometricLock()

    @Environment(\.scenePhase) private var scenePhase

    init() {
        let connection = ConnectionSettings()
        _connection = State(initialValue: connection)
        _store = State(initialValue: LedgerStore(repository: RepositoryFactory.make(for: connection)))
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(store: store, connection: connection, lock: lock)
                .overlay {
                    if lock.isLocked {
                        LockScreen(lock: lock)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: lock.isLocked)
                .onChange(of: scenePhase) { _, phase in
                    // Запираем при уходе в фон, а не при возврате: иначе
                    // содержимое мелькнёт в переключателе приложений.
                    if phase != .active { lock.lock() }
                }
        }
    }
}
