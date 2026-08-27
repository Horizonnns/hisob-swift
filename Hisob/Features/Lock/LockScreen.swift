import SwiftUI

/// Экран поверх приложения, пока вход не подтверждён.
struct LockScreen: View {
    let lock: BiometricLock

    var body: some View {
        ZStack {
            DS.Palette.background.ignoresSafeArea()

            VStack(spacing: DS.Spacing.xl) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(DS.Palette.brand)
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: DS.Spacing.s) {
                    Text(L.Lock.title)
                        .font(DS.Typography.sectionTitle)

                    Text(L.Lock.subtitle)
                        .font(DS.Typography.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if let message = lock.lastError {
                    Text(message)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Palette.expense)
                        .multilineTextAlignment(.center)
                }

                DSButton(
                    title: lock.biometryName ?? L.Lock.passcode,
                    symbol: "faceid",
                    kind: .primary,
                    isLoading: lock.isAuthenticating
                ) {
                    Task { await lock.authenticate() }
                }
                .frame(maxWidth: 260)
            }
            .padding(DS.Spacing.xl)
        }
        // Первый запрос — сразу, без лишнего нажатия.
        .task { await lock.authenticate() }
    }
}
