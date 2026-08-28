import HisobCore
import SwiftUI

/// Создание и правка разового поступления.
struct ReceiptEditor: View {
    @State private var draft: ReceiptDraft
    @State private var isSaving = false
    @State private var saveError: String?
    @FocusState private var isAmountFocused: Bool

    let currency: CurrencyCode
    /// Переключатель показывается только при создании: у существующей записи
    /// вид уже определён, и менять расход на поступление на лету нельзя.
    private let mode: Binding<EntryMode>?
    let onSave: (Receipt) async -> Bool

    @Environment(\.dismiss) private var dismiss

    init(
        editing receipt: Receipt,
        currency: CurrencyCode,
        onSave: @escaping (Receipt) async -> Bool
    ) {
        _draft = State(initialValue: ReceiptDraft(editing: receipt))
        self.currency = currency
        self.mode = nil
        self.onSave = onSave
    }

    init(
        defaultDate: Date,
        currency: CurrencyCode,
        mode: Binding<EntryMode>? = nil,
        onSave: @escaping (Receipt) async -> Bool
    ) {
        _draft = State(initialValue: ReceiptDraft(defaultDate: defaultDate))
        self.currency = currency
        self.mode = mode
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                if let mode {
                    Section { EntryModePicker(mode: mode) }
                }

                Section {
                    TextField(L.AddExpense.amount, text: $draft.amountText)
                        .keyboardType(.decimalPad)
                        .font(DS.Typography.amount)
                        .focused($isAmountFocused)

                    TextField(L.Receipt.sourcePrompt, text: $draft.title, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section {
                    Picker(L.Receipt.kind, selection: $draft.kind) {
                        ForEach(ReceiptKind.builtIn, id: \.self) { item in
                            Label(
                                ReceiptPresentation.title(item),
                                systemImage: ReceiptPresentation.symbol(item)
                            )
                            .tag(item)
                        }
                    }

                    DatePicker(L.AddExpense.date, selection: $draft.date, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                }

                if let saveError {
                    Section {
                        Label(saveError, systemImage: "exclamationmark.triangle.fill")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Palette.expense)
                    }
                }
            }
            // Короткий заголовок: «Добавить поступление» не влезает в панель
            // и обрезается многоточием.
            .navigationTitle(L.Receipt.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.AddExpense.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(draft.isNew ? L.AddExpense.save : L.Sources.save, action: save)
                            .disabled(!draft.canSave)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { if draft.isNew { isAmountFocused = true } }
    }

    private func save() {
        guard let receipt = draft.build() else { return }
        isSaving = true
        saveError = nil

        Task {
            // Форма закрывается только после успеха: иначе запись молча
            // терялась бы, а человек считал бы её сохранённой.
            let saved = await onSave(receipt)
            isSaving = false
            if saved { dismiss() } else { saveError = L.Error.saveFailed }
        }
    }
}
