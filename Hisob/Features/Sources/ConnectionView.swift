import HisobCore
import SwiftUI

/// Настройка подключения к API: адрес и токен.
///
/// Токен вводит пользователь и хранится в Keychain; в коде и в сборке
/// его нет.
struct ConnectionView: View {
    let settings: ConnectionSettings
    let onApply: (APIConfiguration?) -> Void

    @State private var rawURL: String
    @State private var token: String
    @State private var check: CheckState = .idle

    @Environment(\.dismiss) private var dismiss

    private enum CheckState: Equatable {
        case idle
        case checking
        case success
        case failure(String)
    }

    init(settings: ConnectionSettings, onApply: @escaping (APIConfiguration?) -> Void) {
        self.settings = settings
        self.onApply = onApply
        _rawURL = State(initialValue: settings.rawURL)
        _token = State(initialValue: settings.token)
    }

    private var draftConfiguration: APIConfiguration? {
        APIConfiguration(rawURL: rawURL, token: token)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L.Connection.urlPlaceholder, text: $rawURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .onChange(of: rawURL) { _, _ in check = .idle }

                    SecureField(L.Connection.tokenPlaceholder, text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: token) { _, _ in check = .idle }
                } header: {
                    Text(L.Connection.title)
                } footer: {
                    Text(L.Connection.footer)
                }

                Section {
                    Button(action: runCheck) {
                        HStack {
                            if check == .checking {
                                ProgressView().controlSize(.small)
                            }
                            Text(L.Connection.check)
                            Spacer()
                            statusIcon
                        }
                    }
                    .disabled(draftConfiguration == nil || check == .checking)

                    if case .failure(let message) = check {
                        Text(message)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Palette.expense)
                    }
                }

                if settings.isConfigured {
                    Section {
                        Button(L.Connection.disconnect, role: .destructive) {
                            settings.clear()
                            onApply(nil)
                            dismiss()
                        }
                    } footer: {
                        Text(L.Connection.disconnectFooter)
                    }
                }
            }
            .navigationTitle(L.Connection.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.AddExpense.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.Sources.save, action: apply)
                        .disabled(draftConfiguration == nil)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch check {
        case .success:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(DS.Palette.income)
        case .failure:
            Image(systemName: "xmark.circle.fill").foregroundStyle(DS.Palette.expense)
        case .idle, .checking:
            EmptyView()
        }
    }

    private func runCheck() {
        guard let configuration = draftConfiguration else { return }
        check = .checking
        Task {
            do {
                try await HisobAPIClient(configuration: configuration).checkConnection()
                check = .success
            } catch {
                let message = (error as? APIError)?.errorDescription
                    ?? error.localizedDescription
                check = .failure(message)
            }
        }
    }

    private func apply() {
        settings.save(rawURL: rawURL, token: token)
        onApply(settings.configuration)
        dismiss()
    }
}
