import Foundation
import HisobCore

/// Черновик поступления. Сумма держится строкой по той же причине, что и у
/// траты: в процессе набора это ещё не число.
@Observable
final class ReceiptDraft {
    let id: UUID
    let isNew: Bool

    var amountText: String
    var title: String
    var kind: ReceiptKind
    var date: Date

    init(editing receipt: Receipt) {
        self.id = receipt.id
        self.isNew = false
        self.amountText = ExpenseDraft.format(receipt.amount)
        self.title = receipt.title
        self.kind = receipt.kind
        self.date = receipt.date
    }

    init(defaultDate: Date) {
        self.id = UUID()
        self.isNew = true
        self.amountText = ""
        self.title = ""
        self.kind = .gift
        self.date = defaultDate
    }

    var canSave: Bool {
        guard let amount = ExpenseDraft.parse(amountText) else { return false }
        return amount > .zero
    }

    func build() -> Receipt? {
        guard let amount = ExpenseDraft.parse(amountText), amount > .zero else { return nil }
        return Receipt(
            id: id,
            date: date,
            kind: kind,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount
        )
    }
}
