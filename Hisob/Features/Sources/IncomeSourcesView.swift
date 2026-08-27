import HisobCore
import SwiftUI

struct IncomeSourcesView: View {
    @State var viewModel: IncomeSourcesViewModel
    @State private var editing: EditorTarget?

    /// Что открыто в редакторе: существующий источник или новый.
    private enum EditorTarget: Identifiable {
        case new
        case existing(IncomeSource)

        var id: String {
            switch self {
            case .new: "new"
            case .existing(let source): source.id.uuidString
            }
        }

        var source: IncomeSource? {
            switch self {
            case .new: nil
            case .existing(let source): source
            }
        }
    }

    var body: some View {
        List {
            switch viewModel.state {
            case .loading:
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonBlock(height: 52)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

            case .failed(let message):
                ErrorStateView(message: message) {
                    Task { await viewModel.reload() }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            case .loaded:
                if viewModel.isEmpty {
                    EmptyStateView(
                        symbol: "briefcase",
                        title: L.Sources.emptyTitle,
                        message: L.Sources.emptyMessage,
                        actionTitle: L.Sources.add,
                        action: { editing = .new }
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(viewModel.sources) { source in
                        row(source)
                    }

                    // Пояснение обычной строкой, а не футером секции:
                    // в .plain-списке футер рисуется на собственной подложке
                    // и выбивается из тёмной темы.
                    Text(L.Sources.deleteExplanation)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, DS.Spacing.s)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(DS.Palette.background)
        .navigationTitle(L.Sources.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editing = .new } label: { Image(systemName: "plus") }
                    .accessibilityLabel(L.Sources.add)
            }
        }
        .sheet(item: $editing) { target in
            IncomeSourceEditor(source: target.source, currency: viewModel.currency) { source in
                await viewModel.save(source)
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.reload() }
    }

    /// «Август 2026» — для подписи о завершении.
    private func monthName(_ month: YearMonth) -> String {
        Self.monthFormatter.string(from: month.startDate()).capitalizedFirst
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    /// Содержимое строки без обёртки-кнопки.
    ///
    /// Вынесено отдельно, потому что превью контекстного меню не может
    /// вызывать `row` — тип определялся бы через самого себя.
    @ViewBuilder
    private func rowContent(
        _ source: IncomeSource,
        isActive: Bool,
        salary: Money
    ) -> some View {
        HStack(spacing: DS.Spacing.m) {
            Image(systemName: "briefcase.fill")
                .font(.system(size: DS.IconSize.regular))
                .foregroundStyle(isActive ? DS.Palette.income : .secondary)
                .frame(width: 32, height: 32)
                .background(
                    (isActive ? DS.Palette.income : Color.secondary).opacity(0.14),
                    in: RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DS.Spacing.s) {
                    Text(source.name)
                        .font(DS.Typography.body)
                        .lineLimit(1)

                    if let endedAt = source.endedAt {
                        // Для ещё не наступившего окончания подпись другая:
                        // «Завершён» о работе, которая платит в этом месяце,
                        // было бы неправдой.
                        Text(isActive
                            ? "\(L.Sources.endingBadge) \(monthName(endedAt))"
                            : L.Sources.endedBadge)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, DS.Spacing.s)
                            .padding(.vertical, 2)
                            .background(
                                (isActive ? DS.Palette.carryover : Color.secondary).opacity(0.18),
                                in: Capsule()
                            )
                            .foregroundStyle(isActive ? DS.Palette.carryover : .secondary)
                    }
                }

                Text(source.role.isEmpty ? L.Sources.subtitle : source.role)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: DS.Spacing.s)

            VStack(alignment: .trailing, spacing: 2) {
                if salary > .zero {
                    Text(MoneyFormat.string(salary, currency: viewModel.currency))
                        .font(DS.Typography.amountCompact)
                } else if let last = viewModel.lastSalary(source) {
                    // У завершённой работы оклад был — просто больше не
                    // начисляется. Писать «не задан» было бы неправдой.
                    Text(MoneyFormat.string(last, currency: viewModel.currency))
                        .font(DS.Typography.amountCompact)
                        .foregroundStyle(.secondary)
                    Text(L.Sources.lastSalary)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                } else {
                    Text(L.Sources.noSalary)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func row(_ source: IncomeSource) -> some View {
        let isActive = viewModel.isActiveNow(source)
        let salary = viewModel.currentSalary(source)

        return Button {
            editing = .existing(source)
        } label: {
            rowContent(source, isActive: isActive, salary: salary)
            .padding(.vertical, DS.Spacing.s)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                Task { await viewModel.delete(source) }
            } label: {
                Label(L.Common.delete, systemImage: "trash")
            }
        }
        .contextMenu {
            Button {
                editing = .existing(source)
            } label: {
                Label(L.Common.edit, systemImage: "pencil")
            }

            Button(role: .destructive) {
                Task { await viewModel.delete(source) }
            } label: {
                Label(L.Common.delete, systemImage: "trash")
            }
        } preview: {
            rowContent(source, isActive: isActive, salary: salary)
                .padding(DS.Spacing.l)
                .frame(width: 320)
                .background(DS.Palette.surfaceElevated)
        }
    }
}
