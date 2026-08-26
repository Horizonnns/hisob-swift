import Foundation

/// Снимок данных на диске.
///
/// Нужен, чтобы приложение открывалось мгновенно и показывало последние
/// известные цифры без сети — в метро, в самолёте, при отвалившемся Neon.
public actor LedgerSnapshotStore {
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// Файл в Application Support: данные пользователя, а не кэш, который
    /// система вправе вычистить в любой момент.
    public static func defaultURL(
        fileManager: FileManager = .default
    ) throws -> URL {
        let directory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appendingPathComponent("Hisob", isDirectory: true)

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("ledger-snapshot.json")
    }

    public func save(_ ledger: Ledger) {
        // Снимок — вспомогательный: неудачная запись не должна ронять операцию,
        // которая уже успешно ушла на сервер.
        guard let data = try? JSONEncoder().encode(ledger) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    public func load() -> Ledger? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(Ledger.self, from: data)
    }

    public func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
