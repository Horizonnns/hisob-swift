import LocalAuthentication
import Observation
import SwiftUI

/// Блокировка входа по Face ID или Touch ID.
///
/// Данные о деньгах — из тех, что не стоит показывать первому взявшему
/// телефон в руки. Проверка идёт при запуске и при возврате из фона.
@MainActor
@Observable
final class BiometricLock {
    private enum Keys {
        static let enabled = "hisob.lock.enabled"
    }

    /// Заперто ли приложение прямо сейчас.
    private(set) var isLocked: Bool
    private(set) var lastError: String?
    /// Идёт ли проверка — чтобы не запускать вторую поверх первой.
    private(set) var isAuthenticating = false

    private let defaults: UserDefaults

    /// Хранилище отдельно от `isEnabled` не для красоты: макрос `@Observable`
    /// не трогает свойства с `didSet`, и переключатель в настройках менял
    /// модель, но не перерисовывал экран.
    private var enabledStorage: Bool

    var isEnabled: Bool {
        get { enabledStorage }
        set {
            enabledStorage = newValue
            defaults.set(newValue, forKey: Keys.enabled)
            // Выключили — открываем сразу, иначе экран останется запертым
            // до перезапуска.
            if !newValue { isLocked = false }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let enabled = defaults.bool(forKey: Keys.enabled)
        self.enabledStorage = enabled
        // Биометрию могли отключить уже после того, как замок включили. Без
        // этой проверки приложение осталось бы запертым навсегда.
        self.isLocked = enabled && LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// Что доступно на устройстве: Face ID, Touch ID или ничего.
    var biometryName: String? {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { return nil }
        return switch context.biometryType {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .opticID: "Optic ID"
        default: L.Lock.passcode
        }
    }

    var isAvailable: Bool { biometryName != nil }

    func lock() {
        guard isEnabled, isAvailable else { return }
        isLocked = true
    }

    /// Запрашивает подтверждение. Политика `deviceOwnerAuthentication`, а не
    /// `...WithBiometrics`: если Face ID не сработал, система сама предложит
    /// код-пароль — иначе из приложения не выйти.
    func authenticate() async {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        lastError = nil
        defer { isAuthenticating = false }

        let context = LAContext()
        context.localizedCancelTitle = L.Lock.cancel

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: L.Lock.reason
            )
            if success { isLocked = false }
        } catch let error as LAError {
            switch error.code {
            // Отмена — не ошибка: пользователь сам закрыл запрос.
            case .userCancel, .appCancel, .systemCancel:
                lastError = nil
            // Подтвердить нечем: биометрию отключили или сняли код-пароль уже
            // после того, как замок включили. Держать дверь запертой, когда от
            // неё нет ключа, — значит запереть человека от собственных данных.
            case .biometryNotAvailable, .biometryNotEnrolled, .passcodeNotSet:
                isEnabled = false
                lastError = L.Lock.turnedOff
            default:
                lastError = L.Lock.failed
            }
        } catch {
            lastError = L.Lock.failed
        }
    }
}
