import HisobCore
import SwiftUI

struct MonthView: View {
    @State var viewModel: MonthViewModel
    @State private var expandedIDs: Set<Expense.ID> = []
    @State private var editingExpense: Expense?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        List {
            Section {
                header
            }
            .listRowInsets(EdgeInsets(top: DS.Spacing.s, leading: DS.Spacing.screen,
                                      bottom: DS.Spacing.s, trailing: DS.Spacing.screen))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            content
        }
        .listStyle(.plain)
        // Разделов стало много (по одному на день), и стандартный зазор между
        // ними разрывал список на куски.
        .listSectionSpacing(.compact)
        .scrollContentBackground(.hidden)
        .background(DS.Palette.background)
        // Заголовка нет, но панель навигации нужна: в ней живёт поиск.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.query.text, prompt: L.Month.search)
        .sheet(item: $editingExpense) { expense in
            ExpenseEditor(editing: expense, currency: viewModel.currency) { updated in
                await viewModel.updateExpense(updated)
            }
        }
        .task { await viewModel.load() }
        // Полная перезагрузка: заодно отправляет накопленную очередь.
        // Без неё неотправленные изменения ждали бы перезапуска приложения.
        .refreshable { await viewModel.reload() }
        .onChange(of: viewModel.month) { _, _ in viewModel.monthDidChange() }
        .sensoryFeedback(.success, trigger: viewModel.monthExpenses.count)
        .overlay(alignment: .bottom) { errorBanner }
        .animation(
            DS.Motion.resolved(DS.Motion.smooth, reduceMotion: reduceMotion),
            value: viewModel.visibleExpenses
        )
    }

    // MARK: - Шапка

    @ViewBuilder
    private var header: some View {
        VStack(spacing: DS.Spacing.l) {
            MonthSwitcher(
                month: viewModel.month,
                isCurrent: viewModel.isCurrentMonth,
                onPrevious: viewModel.goToPreviousMonth,
                onNext: viewModel.goToNextMonth,
                onCurrent: viewModel.goToCurrentMonth
            )

            // Во время загрузки плашки не показываем: нули вместо сумм
            // читаются как настоящие данные.
            if viewModel.state != .loading {
                statTiles

                if !viewModel.categoryCounts.isEmpty {
                    categoryFilter
                }
            }
        }
    }

    private var statTiles: some View {
        MonthSummaryCard(summary: viewModel.summary, showsCarryover: viewModel.showsCarryover)
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
            // строки списка: так видно, что её можно листать. Края растворяем —
            // иначе крайний чип срезается посреди слова и выглядит как брак.
            .padding(.horizontal, -DS.Spacing.screen)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.03),
                        .init(color: .black, location: 0.97),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )

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
                MonthSkeleton()
                    .listRowInsets(EdgeInsets(top: 0, leading: DS.Spacing.screen,
                                              bottom: DS.Spacing.l, trailing: DS.Spacing.screen))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
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
                // Раздел на день вместо одного общего «Траты»: заголовок
                // прилипает при прокрутке и всё время говорит, какой день
                // перед глазами и сколько за него ушло.
                ForEach(viewModel.visibleDays) { day in
                    Section {
                        ForEach(day.expenses) { expense in
                            expenseRow(expense)
                        }
                    } header: {
                        dayHeader(day)
                    }
                }
            }
        }
    }

    private func dayHeader(_ day: MonthViewModel.DaySection) -> some View {
        HStack(spacing: DS.Spacing.s) {
            Text(viewModel.dayTitle(day.date))
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Spacer(minLength: DS.Spacing.s)

            Text(MoneyFormat.string(day.total, currency: viewModel.currency))
                .font(DS.Typography.label.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func expenseRow(_ expense: Expense) -> some View {
        ExpenseRow(expense: expense, currency: viewModel.currency,
                   expandedIDs: $expandedIDs)
            .listRowBackground(Color.clear)
            // Нажатие с удержанием: фон размывается, строка поднимается
            // отдельной карточкой, меню раскрывается рядом. Превью задаём
            // своё — иначе система приподнимает строку как есть, без
            // подложки, и она сливается с фоном.
            .contextMenu {
                // Иконки в меню система красит акцентом приложения — оба
                // пункта выходили янтарными. Правке возвращаем цвет текста
                // (белый на тёмном, чёрный на светлом), удалению — красный.
                Button {
                    editingExpense = expense
                } label: {
                    Label(L.Common.edit, systemImage: "pencil")
                }
                .tint(Color.primary)

                Button(role: .destructive) {
                    Task { await viewModel.deleteExpense(expense) }
                } label: {
                    Label(L.Common.delete, systemImage: "trash")
                }
                .tint(DS.Palette.destructive)
            } preview: {
                ExpenseRow(
                    expense: expense,
                    currency: viewModel.currency,
                    expandedIDs: .constant([expense.id])
                )
                .padding(.horizontal, DS.Spacing.l)
                .frame(width: 320)
                .background(DS.Palette.surfaceElevated)
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

}
