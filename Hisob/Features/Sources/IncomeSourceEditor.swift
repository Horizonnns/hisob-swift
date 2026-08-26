import HisobCore
import SwiftUI

/// Редактор источника дохода: название, должность, история оклада и
/// дата завершения работы.
struct IncomeSourceEditor: View {
    let currency: CurrencyCode
    let onSave: (IncomeSource) async -> Void

    @State private var draft: IncomeSource
    @State private var isEnded: Bool
    @State private var endedDate: Date
    @State private var newSalaryAmount = ""
    @State private var newSalaryDate = Date.now
    @State private var isSaving = false

    private let isNew: Bool

    @Environment(\.dismiss) private var dismiss

    init(
        source: IncomeSource?,
        currency: CurrencyCode,
        onSave: @escaping (IncomeSource) async -> Void
    ) {
        let resolved = source ?? IncomeSource(name: "")
        _draft = State(initialValue: resolved)
        _isEnded = State(initialValue: resolved.endedAt != nil)
        _endedDate = State(
            initialValue: resolved.endedAt?.startDate() ?? Date.now
        )
        self.isNew = source == nil
        self.currency = currency
        self.onSave = onSave
    }

    private var parsedNewSalary: Money? {
        let normalized = newSalaryAmount
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: " ", with: "")
        guard let value = Money.parse(normalized), value > .zero else { return nil }
        return value
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L.Sources.namePlaceholder, text: $draft.name)
                    TextField(L.Sources.rolePlaceholder, text: $draft.role)
                }

                salarySection

                Section {
                    Toggle(L.Sources.ended, isOn: $isEnded.animation(DS.Motion.snappy))

                    if isEnded {
                        DatePicker(
                            L.Sources.endedAt,
                            selection: $endedDate,
                            displayedComponents: .date
                        )
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                    }
                } footer: {
                    if isEnded {
                        // Объясняем, почему дата окончания вообще нужна.
                        Text(L.Sources.endedFooter)
                    }
                }
            }
            .navigationTitle(isNew ? L.Sources.newSource : L.Sources.editSource)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.AddExpense.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.Sources.save, action: save)
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var salarySection: some View {
        Section {
            ForEach(draft.sortedHistory()) { entry in
                HStack {
                    Text(entry.effectiveFrom.formatted(
                        .dateTime.day().month(.abbreviated).year()
                            .locale(Locale(identifier: "ru_RU"))
                    ))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)

                    Spacer()

                    Text(MoneyFormat.string(entry.amount, currency: currency))
                        .font(DS.Typography.amountCompact)
                }
                .accessibilityElement(children: .combine)
            }
            .onDelete(perform: deleteSalaryEntries)

            HStack(spacing: DS.Spacing.m) {
                DatePicker(
                    L.Sources.effectiveFrom,
                    selection: $newSalaryDate,
                    displayedComponents: .date
                )
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "ru_RU"))

                TextField(L.Sources.amount, text: $newSalaryAmount)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)

                Button {
                    addSalaryEntry()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(parsedNewSalary == nil ? Color.secondary : DS.Palette.brand)
                .disabled(parsedNewSalary == nil)
                .accessibilityLabel(L.Sources.addSalary)
            }
        } header: {
            Text(L.Sources.salaryHistory)
        } footer: {
            Text(L.Sources.salaryFooter)
        }
    }

    private func addSalaryEntry() {
        guard let amount = parsedNewSalary else { return }
        withAnimation(DS.Motion.snappy) {
            draft.salaryHistory.append(
                SalaryEntry(effectiveFrom: newSalaryDate, amount: amount)
            )
        }
        newSalaryAmount = ""
    }

    private func deleteSalaryEntries(at offsets: IndexSet) {
        // sortedHistory() отдаёт другой порядок, чем хранимый массив,
        // поэтому удаляем по идентификаторам, а не по индексам.
        let sorted = draft.sortedHistory()
        let doomed = Set(offsets.map { sorted[$0].id })
        withAnimation(DS.Motion.snappy) {
            draft.salaryHistory.removeAll { doomed.contains($0.id) }
        }
    }

    private func save() {
        var result = draft
        result.name = result.name.trimmingCharacters(in: .whitespacesAndNewlines)
        result.role = result.role.trimmingCharacters(in: .whitespacesAndNewlines)
        result.endedAt = isEnded ? YearMonth(date: endedDate) : nil

        isSaving = true
        Task {
            await onSave(result)
            isSaving = false
            dismiss()
        }
    }
}
