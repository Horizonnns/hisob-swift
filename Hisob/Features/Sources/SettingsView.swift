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
            }

            Section {
                sourcesRow
            }

            Section {
                HStack {
                    Image(systemName: "coloncurrencysign.circle.fill")
                        .foregroundStyle(DS.Palette.brand)
                        .frame(width: 28)
                    Text(L.Settings.currency)
                    Spacer()
                    Text(store.ledger.currency.rawValue)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, DS.Spacing.xs)
                .listRowBackground(Color.clear)
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
