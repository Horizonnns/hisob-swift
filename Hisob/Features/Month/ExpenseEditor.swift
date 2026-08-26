import HisobCore
import SwiftUI

/// Создание и правка траты — одиночной или групповой.
///
/// Один экран на оба случая: поля совпадают, а расхождение форм для
/// «добавить» и «изменить» — источник расхождений в поведении.
struct ExpenseEditor: View {
    @State private var draft: ExpenseDraft
    @State private var isSaving = false
    @FocusState private var focus: Field?

    let currency: CurrencyCode
    let onSave: (Expense) async -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Field: Hashable {
        case amount
        case title
        case item(UUID)
    }

    init(
        editing expense: Expense,
        currency: CurrencyCode,
        onSave: @escaping (Expense) async -> Void
    ) {
        _draft = State(initialValue: ExpenseDraft(editing: expense))
        self.currency = currency
        self.onSave = onSave
    }

    init(
        defaultDate: Date,
        currency: CurrencyCode,
        onSave: @escaping (Expense) async -> Void
    ) {
        _draft = State(initialValue: ExpenseDraft(defaultDate: defaultDate))
        self.currency = currency
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(L.Expense.kind, selection: $draft.kind) {
                        Text(L.Expense.singleKind).tag(ExpenseDraft.Kind.single)
                        Text(L.Expense.groupKind).tag(ExpenseDraft.Kind.group)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: DS.Spacing.s, leading: 0,
                                              bottom: DS.Spacing.s, trailing: 0))
                }

                if draft.kind == .single {
                    singleSection
                } else {
                    groupSection
                }

                Section {
                    Picker(L.AddExpense.category, selection: $draft.category) {
                        ForEach(ExpenseCategory.builtIn, id: \.self) { item in
                            Label(
                                CategoryPresentation.title(item),
                                systemImage: CategoryPresentation.symbol(item)
                            )
                            .tag(item)
                        }
                    }

                    DatePicker(L.AddExpense.date, selection: $draft.date, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                }
            }
            .animation(DS.Motion.resolved(DS.Motion.snappy, reduceMotion: reduceMotion), value: draft.kind)
            .navigationTitle(draft.isNew ? L.AddExpense.title : L.Expense.editTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.AddExpense.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(draft.isNew ? L.AddExpense.save : L.Sources.save, action: save)
                        .disabled(!draft.canSave || isSaving)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents(draft.kind == .group ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { if draft.isNew { focus = .amount } }
    }

    // MARK: - Одиночная трата

    private var singleSection: some View {
        Section {
            TextField(L.AddExpense.amount, text: $draft.amountText)
                .keyboardType(.decimalPad)
                .font(DS.Typography.amount)
                .focused($focus, equals: .amount)

            TextField(L.AddExpense.descriptionPlaceholder, text: $draft.title, axis: .vertical)
                .lineLimit(1...3)
                .focused($focus, equals: .title)
        }
    }

    // MARK: - Группа

    private var groupSection: some View {
        Group {
            Section {
                TextField(L.Expense.groupTitlePlaceholder, text: $draft.title)
                    .focused($focus, equals: .title)
            } header: {
                Text(L.Expense.groupTitle)
            }

            Section {
                ForEach($draft.items) { $item in
                    HStack(spacing: DS.Spacing.m) {
                        TextField(L.Expense.itemTitle, text: $item.title)
                            .focused($focus, equals: .item(item.id))

                        TextField(L.AddExpense.amount, text: $item.amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 110)
                            .monospacedDigit()
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if draft.items.count > 1 {
                            Button(role: .destructive) {
                                withAnimation(DS.Motion.snappy) { draft.removeItem(item) }
                            } label: {
                                Label(L.Common.delete, systemImage: "trash")
                            }
                        }
                    }
                }

                Button {
                    withAnimation(DS.Motion.snappy) { draft.addItem() }
                    focus = .item(draft.items.last?.id ?? UUID())
                } label: {
                    Label(L.Expense.addItem, systemImage: "plus.circle.fill")
                }
            } header: {
                HStack {
                    Text(L.Expense.items)
                    Spacer()
                    // Итог считается из позиций и виден по мере набора —
                    // отдельного поля суммы у группы нет и быть не должно.
                    Text(MoneyFormat.string(draft.groupTotal, currency: currency))
                        .font(DS.Typography.caption.monospacedDigit())
                        .textCase(nil)
                }
            } footer: {
                Text(L.Expense.groupFooter)
            }
        }
    }

    private func save() {
        guard let expense = draft.build() else { return }
        isSaving = true
        Task {
            await onSave(expense)
            isSaving = false
            dismiss()
        }
    }
}
