import HisobCore
import SwiftUI

struct SettingsView: View {
    let store: LedgerStore
    @Binding var path: NavigationPath

    var body: some View {
        List {
            Section {
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

            Text(L.Settings.storageNotice)
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
    }
}
