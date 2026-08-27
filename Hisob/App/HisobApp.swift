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
                    if isCovered {
                        LockScreen(lock: lock)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isCovered)
                // Холодный старт: сцена уже активна, спрашиваем сразу.
                .task {
                    if lock.isLocked { await lock.authenticate() }
                }
                .onChange(of: scenePhase) { previous, phase in
                    switch phase {
                    case .background:
                        lock.lock()
                    case .active:
                        // Только после настоящего фона. Возврат из `.inactive`
                        // — это чаще всего закрытый системный запрос Face ID,
                        // и спрашивать заново значило бы зациклить отмену.
                        if previous == .background, lock.isLocked {
                            Task { await lock.authenticate() }
                        }
                    default:
                        break
                    }
                }
        }
    }

    /// Содержимое закрыто: либо вход не подтверждён, либо сцена не активна —
    /// тогда экран прикрыт, чтобы суммы не мелькнули в переключателе
    /// приложений. Прикрыть и спросить — разные вещи: второе делает только
    /// `onChange`, и только при возврате из фона.
    private var isCovered: Bool {
        lock.isLocked || (lock.isEnabled && scenePhase != .active)
    }
}
