import CoreTransferable
import Foundation
import HisobCore
import UniformTypeIdentifiers

/// Выгрузка всех данных в файл.
///
/// Страховка, не зависящая ни от сервера, ни от устройства: формат читаемый,
/// восстановить из него можно чем угодно, включая скрипт импорта.
enum LedgerExport {
    static func makeFile(from ledger: Ledger, now: Date = .now) throws -> ExportFile {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(ledger)

        let stamp = DayString.string(from: now)
        return ExportFile(name: "hisob-\(stamp).json", data: data)
    }
}

/// Файл, готовый к отправке в «Файлы» или куда угодно через share-sheet.
struct ExportFile: Transferable, Identifiable {
    let id = UUID()
    let name: String
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { file in
            file.data
        }
        .suggestedFileName { $0.name }
    }
}
