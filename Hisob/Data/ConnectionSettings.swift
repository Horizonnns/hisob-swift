import Foundation
import HisobCore
import Observation

/// Адрес API и токен доступа.
///
/// Адрес — в UserDefaults, токен — в Keychain. Приложение однопользовательское,
/// поэтому пара одна.
@MainActor
@Observable
final class ConnectionSettings {
    private enum Keys {
        static let baseURL = "hisob.api.baseURL"
        static let token = "hisob.api.token"
    }

    private let defaults: UserDefaults

    private(set) var rawURL: String
    private(set) var token: String

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.rawURL = defaults.string(forKey: Keys.baseURL) ?? ""
        self.token = Keychain.get(Keys.token) ?? ""
    }

    var configuration: APIConfiguration? {
        APIConfiguration(rawURL: rawURL, token: token)
    }

    var isConfigured: Bool { configuration != nil }

    /// Адрес без схемы — для показа в настройках.
    var displayHost: String {
        configuration?.baseURL.host ?? rawURL
    }

    func save(rawURL: String, token: String) {
        self.rawURL = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        self.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(self.rawURL, forKey: Keys.baseURL)
        Keychain.set(self.token, for: Keys.token)
    }

    func clear() {
        rawURL = ""
        token = ""
        defaults.removeObject(forKey: Keys.baseURL)
        Keychain.remove(Keys.token)
    }
}
