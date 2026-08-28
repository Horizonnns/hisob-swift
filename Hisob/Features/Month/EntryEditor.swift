import HisobCore
import SwiftUI

/// Что заводим: расход или поступление.
enum EntryMode: Hashable {
    case expense
    case receipt
}

/// Обёртка над двумя редакторами.
///
/// Кнопка на экране одна, поэтому вид записи выбирается переключателем внутри
/// формы — как «одна сумма / несколько позиций». Смена вида пересоздаёт форму:
/// у расхода и поступления разные поля, и переносить между ними набранное
/// было бы враньём.
struct EntryEditor: View {
    let defaultDate: Date
    let currency: CurrencyCode
    let onSaveExpense: (Expense) async -> Bool
    let onSaveReceipt: (Receipt) async -> Bool

    @State private var mode: EntryMode = .expense

    var body: some View {
        switch mode {
        case .expense:
            ExpenseEditor(defaultDate: defaultDate, currency: currency,
                          mode: $mode, onSave: onSaveExpense)
        case .receipt:
            ReceiptEditor(defaultDate: defaultDate, currency: currency,
                          mode: $mode, onSave: onSaveReceipt)
        }
    }
}

/// Переключатель вида записи. Живёт отдельно, потому что показывается в обеих
/// формах и должен выглядеть одинаково.
struct EntryModePicker: View {
    @Binding var mode: EntryMode

    var body: some View {
        Picker(L.Receipt.title, selection: $mode) {
            Text(L.Receipt.modeExpense).tag(EntryMode.expense)
            Text(L.Receipt.modeReceipt).tag(EntryMode.receipt)
        }
        .pickerStyle(.segmented)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: DS.Spacing.s, leading: 0,
                                  bottom: DS.Spacing.s, trailing: 0))
    }
}
