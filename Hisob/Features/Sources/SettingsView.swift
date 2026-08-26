import HisobCore
import SwiftUI

struct SettingsView: View {
    let store: LedgerStore
    let connection: ConnectionSettings
    @Binding var path: NavigationPath

    @State private var isEditingConnection = false

    var body: some View {
        List {
            Section {
                connectionRow

                if store.pendingCount > 0 {
                    pendingRow
                }
            }

            Section {
                sourcesRow
            }

            Section {
                currencyRow
                exportRow
            }

            Text(connection.isConfigured ? L.Settings.connectedNotice : L.Settings.demoNotice)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, DS.Spacing.s)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(DS.Palette.background)
        .navigationTitle(L.Tab.settings)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isEditingConnection) {
            ConnectionView(settings: connection) { configuration in
                Task {
                    let repository = configuration.map(RepositoryFactory.makeRemote)
                        ?? InMemoryLedgerRepository(ledger: PreviewData.ledger)
                    await store.use(repository)
                }
            }
        }
    }

    /// Валюта выбирается из списка, а не вводится текстом: API принимает
    /// ровно три буквы, и опечатка сломала бы отображение всех сумм.
    private var currencyRow: some View {
        HStack(spacing: DS.Spacing.m) {
            Image(systemName: "coloncurrencysign.circle.fill")
                .foregroundStyle(DS.Palette.brand)
                .frame(width: 28)

            Picker(L.Settings.currency, selection: currencyBinding) {
                ForEach(availableCurrencies, id: \.self) { code in
                    Text(code.rawValue).tag(code)
                }
            }
        }
        .padding(.vertical, DS.Spacing.xs)
        .listRowBackground(Color.clear)
    }

    private var currencyBinding: Binding<CurrencyCode> {
        Binding(
            get: { store.ledger.currency },
            set: { code in Task { await store.setCurrency(code) } }
        )
    }

    /// Текущая валюта добавляется в список, даже если её там не было —
    /// иначе Picker не смог бы показать выбранное значение.
    private var availableCurrencies: [CurrencyCode] {
        let common = [CurrencyCode.tjs, CurrencyCode(rawValue: "USD"),
                      CurrencyCode(rawValue: "EUR"), CurrencyCode(rawValue: "RUB")]
        return common.contains(store.ledger.currency) ? common : common + [store.ledger.currency]
    }

    /// `ShareLink` прямо строкой, без промежуточного листа: системный
    /// share-sheet открывается одним нажатием.
    @ViewBuilder
    private var exportRow: some View {
        if let file = try? LedgerExport.makeFile(from: store.ledger) {
            ShareLink(item: file, preview: SharePreview(file.name)) {
                HStack(spacing: DS.Spacing.m) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(DS.Palette.brand)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.Settings.export).font(DS.Typography.body)
                        Text(L.Settings.exportSubtitle)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, DS.Spacing.xs)
                .contentShape(.rect)
            }
            .foregroundStyle(.primary)
            .listRowBackground(Color.clear)
        }
    }

    /// Видимый признак того, что часть изменений ещё не на сервере.
    /// Без него молчаливая очередь выглядела бы как потеря данных.
    private var pendingRow: some View {
        Button {
            // Повторная загрузка сначала разгружает очередь.
            Task { await store.load() }
        } label: {
            pendingRowContent
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
    }

    private var pendingRowContent: some View {
        HStack(spacing: DS.Spacing.m) {
            Image(systemName: "arrow.up.circle.dotted")
                .foregroundStyle(DS.Palette.carryover)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(L.Settings.pendingChanges).font(DS.Typography.body)
                Text(L.Settings.pendingChangesFooter)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(store.pendingCount)")
                .font(DS.Typography.amountCompact)
                .foregroundStyle(DS.Palette.carryover)

            Image(systemName: "arrow.clockwise")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, DS.Spacing.xs)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint(L.Settings.pendingRetry)
    }

    private var connectionRow: some View {
        Button {
            isEditingConnection = true
        } label: {
            HStack(spacing: DS.Spacing.m) {
                Image(systemName: connection.isConfigured ? "icloud.fill" : "icloud.slash.fill")
                    .foregroundStyle(connection.isConfigured ? DS.Palette.income : .secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L.Settings.connection).font(DS.Typography.body)
                    Text(connection.isConfigured ? connection.displayHost : L.Settings.notConnected)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, DS.Spacing.xs)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
    }

    private var sourcesRow: some View {
        Button {
            path.append(AppRoute.incomeSources)
        } label: {
            HStack(spacing: DS.Spacing.m) {
                Image(systemName: "briefcase.fill")
                    .foregroundStyle(DS.Palette.income)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L.Sources.title).font(DS.Typography.body)
                    Text(L.Sources.subtitle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(store.ledger.sources.count)")
                    .font(DS.Typography.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, DS.Spacing.xs)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
    }
}
