import HisobCore
import SwiftUI

/// Добавление одиночной траты.
/// Групповая трата (несколько позиций) — следующим шагом.
struct AddExpenseSheet: View {
    let defaultDate: Date
    let onSave: (Money, ExpenseCategory, Date, String) async -> Void

    @State private var amountText = ""
    @State private var category: ExpenseCategory = .food
    @State private var date: Date
    @State private var title = ""
    @State private var isSaving = false
    @FocusState private var isAmountFocused: Bool

    @Environment(\.dismiss) private var dismiss

    init(
        defaultDate: Date,
        onSave: @escaping (Money, ExpenseCategory, Date, String) async -> Void
    ) {
        self.defaultDate = defaultDate
        self.onSave = onSave
        _date = State(initialValue: defaultDate)
    }

    /// Сумма считается валидной только строго положительной.
    private var parsedAmount: Money? {
        let normalized = amountText
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: " ", with: "")
        guard let value = Money.parse(normalized), value > .zero else { return nil }
        return value
    }

    private var canSave: Bool { parsedAmount != nil && !isSaving }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L.AddExpense.amount, text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(DS.Typography.amount)
                        .focused($isAmountFocused)
                }

                Section {
                    Picker(L.AddExpense.category, selection: $category) {
                        ForEach(ExpenseCategory.builtIn, id: \.self) { item in
                            Label(
                                CategoryPresentation.title(item),
                                systemImage: CategoryPresentation.symbol(item)
                            )
                            .tag(item)
                        }
                    }

                    DatePicker(
                        L.AddExpense.date,
                        selection: $date,
                        displayedComponents: .date
                    )
                    .environment(\.locale, Locale(identifier: "ru_RU"))
                }

                Section {
                    TextField(L.AddExpense.descriptionPlaceholder, text: $title, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text(L.AddExpense.description)
                }
            }
            .navigationTitle(L.AddExpense.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.AddExpense.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.AddExpense.save, action: save)
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
            .sensoryFeedback(.success, trigger: isSaving) { old, new in old && !new }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { isAmountFocused = true }
    }

    private func save() {
        guard let amount = parsedAmount else { return }
        isSaving = true
        Task {
            await onSave(amount, category, date, title)
            isSaving = false
            dismiss()
        }
    }
}
