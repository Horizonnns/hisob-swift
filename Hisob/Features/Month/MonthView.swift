import HisobCore
import SwiftUI

struct MonthView: View {
    @State var viewModel: MonthViewModel
    @State private var expandedIDs: Set<Expense.ID> = []
    @State private var isAddingExpense = false
    @State private var editingExpense: Expense?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        List {
            Section {
                header
            }
            .listRowInsets(EdgeInsets(top: DS.Spacing.s, leading: DS.Spacing.screen,
                                      bottom: DS.Spacing.m, trailing: DS.Spacing.screen))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            content
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(DS.Palette.background)
        .navigationTitle(L.Month.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isAddingExpense = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(L.Month.addExpense)
            }
        }
        .searchable(text: $viewModel.query.text, prompt: L.Month.search)
        .sheet(isPresented: $isAddingExpense) {
            ExpenseEditor(defaultDate: defaultDateForMonth, currency: viewModel.currency) { expense in
                await viewModel.addExpense(expense)
            }
        }
        .sheet(item: $editingExpense) { expense in
            ExpenseEditor(editing: expense, currency: viewModel.currency) { updated in
                await viewModel.updateExpense(updated)
            }
        }
        .task { await viewModel.load() }
        .onChange(of: viewModel.month) { _, _ in viewModel.monthDidChange() }
        .sensoryFeedback(.success, trigger: viewModel.monthExpenses.count)
        .overlay(alignment: .bottom) { errorBanner }
        .animation(
            DS.Motion.resolved(DS.Motion.smooth, reduceMotion: reduceMotion),
            value: viewModel.visibleExpenses
        )
    }

    // MARK: - Шапка

    private var header: some View {
        VStack(spacing: DS.Spacing.l) {
            MonthSwitcher(
                month: viewModel.month,
                isCurrent: viewModel.isCurrentMonth,
                onPrevious: viewModel.goToPreviousMonth,
                onNext: viewModel.goToNextMonth,
                onCurrent: viewModel.goToCurrentMonth
            )

            statTiles

            if !viewModel.categoryCounts.isEmpty {
                categoryFilter
            }
        }
    }

    private var statTiles: some View {
        let summary = viewModel.summary
        return LazyVGrid(
            columns: [GridItem(.flexible(), spacing: DS.Spacing.m),
                      GridItem(.flexible(), spacing: DS.Spacing.m)],
            spacing: DS.Spacing.m
        ) {
            StatTile(label: L.Month.income, amount: summary.income, currency: summary.currency,
                     symbol: "arrow.up.right", tint: DS.Palette.income)

            if viewModel.showsCarryover {
                StatTile(label: L.Month.carryover, amount: summary.carryover, currency: summary.currency,
                         symbol: "arrow.turn.down.right", tint: DS.Palette.carryover)
            }

            StatTile(label: L.Month.spent, amount: summary.spent, currency: summary.currency,
                     symbol: "arrow.down.right", tint: DS.Palette.expense)

            StatTile(label: L.Month.remaining, amount: summary.remaining, currency: summary.currency,
                     symbol: "wallet.bifold", tint: summary.remaining >= .zero ? DS.Palette.remaining : DS.Palette.expense)
        }
    }

    private var categoryFilter: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            ScrollView(.horizontal) {
                HStack(spacing: DS.Spacing.s) {
                    ForEach(viewModel.categoryCounts, id: \.category) { entry in
                        CategoryChip(
                            category: entry.category,
                            count: entry.count,
                            isSelected: viewModel.query.categories.contains(entry.category)
                        ) {
                            viewModel.toggleCategory(entry.category)
                        }
                    }
                }
                .padding(.vertical, 2)
                .padding(.horizontal, DS.Spacing.screen)
            }
            .scrollIndicators(.hidden)
            // Лента чипов уходит под края экрана, а не обрывается на поле
            // строки списка: так видно, что её можно листать.
            .padding(.horizontal, -DS.Spacing.screen)

            if viewModel.hasFilter {
                Button(L.Month.resetFilters, action: viewModel.clearFilters)
                    .font(DS.Typography.caption.weight(.semibold))
                    .foregroundStyle(DS.Palette.brand)
                    .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Содержимое

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            Section {
                ForEach(0..<5, id: \.self) { _ in
                    SkeletonBlock(height: 44)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }

        case .failed(let message):
            Section {
                ErrorStateView(message: message) {
                    Task { await viewModel.reload() }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

        case .loaded:
            if viewModel.visibleExpenses.isEmpty {
                Section {
                    emptyState
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            } else {
                Section {
                    ForEach(viewModel.visibleExpenses) { expense in
                        ExpenseRow(expense: expense, currency: viewModel.currency,
                                   expandedIDs: $expandedIDs)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteExpense(expense) }
                                } label: {
                                    Label(L.Common.delete, systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    editingExpense = expense
                                } label: {
                                    Label(L.Common.edit, systemImage: "pencil")
                                }
                                .tint(DS.Palette.brand)
                            }
                    }
                } header: {
                    Text(L.Month.expenses)
                        .font(DS.Typography.label)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if viewModel.hasFilter {
            EmptyStateView(
                symbol: "line.3.horizontal.decrease.circle",
                title: L.Empty.noMatchesTitle,
                message: L.Empty.noMatchesMessage,
                actionTitle: L.Month.resetFilters,
                action: viewModel.clearFilters
            )
        } else {
            // Без кнопки: добавление уже есть в «плюсе» на панели навигации,
            // а две кнопки для одного действия только сбивают.
            EmptyStateView(
                symbol: "tray",
                title: L.Empty.noExpensesTitle,
                message: L.Empty.noExpensesMessage
            )
        }
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let message = viewModel.operationError {
            Text(message)
                .font(DS.Typography.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, DS.Spacing.l)
                .padding(.vertical, DS.Spacing.m)
                .background(DS.Palette.expense, in: Capsule())
                .padding(.bottom, DS.Spacing.xl)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task {
                    try? await Task.sleep(for: .seconds(3))
                    viewModel.dismissOperationError()
                }
        }
    }

    /// Новая трата по умолчанию попадает в просматриваемый месяц, а не в сегодня:
    /// иначе при заполнении прошлого месяца каждая запись улетала бы в текущий.
    private var defaultDateForMonth: Date {
        viewModel.isCurrentMonth ? .now : viewModel.month.startDate()
    }
}
