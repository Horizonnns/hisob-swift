import HisobCore
import SwiftUI

/// Полка над панелью вкладок.
///
/// Держим её на всех вкладках, и не только ради содержимого: система подгоняет
/// ширину таб-бара под полку. С ней панель занимает 25…385 pt на любой вкладке,
/// без неё сжимается по своим подписям — 280 pt на «Месяце» и 305 pt на
/// «Аналитике», отчего вкладки заметно съезжались при переходе.
///
/// Кнопка добавления при этом живёт только на «Месяце»: на других вкладках
/// полка показывает остаток месяца — то, ради чего в приложение и заходят.
///
/// До iOS 26 полки нет, там кнопка просто плавает над панелью.
struct TabAccessory: ViewModifier {
    let showsAdd: Bool
    let remaining: Money
    let currency: CurrencyCode
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.tabViewBottomAccessory {
                AccessoryContent(
                    showsAdd: showsAdd,
                    remaining: remaining,
                    currency: currency,
                    action: action
                )
            }
        } else {
            content.overlay(alignment: .bottomTrailing) {
                if showsAdd {
                    floatingButton
                        .padding(.trailing, DS.Spacing.screen)
                        .padding(.bottom, 60)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(DS.Motion.resolved(DS.Motion.snappy, reduceMotion: reduceMotion),
                       value: showsAdd)
        }
    }

    private var floatingButton: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(DS.Palette.brand)
                .frame(width: 56, height: 56)
                .contentShape(.circle)
        }
        .buttonStyle(.pressable(scale: 0.94))
        .dsGlass(cornerRadius: 28, isInteractive: true)
        .accessibilityLabel(L.Month.addExpense)
    }
}

/// Содержимое полки. В свёрнутом виде места на подписи нет, и система сообщает
/// об этом через `tabViewBottomAccessoryPlacement`.
@available(iOS 26.0, *)
private struct AccessoryContent: View {
    let showsAdd: Bool
    let remaining: Money
    let currency: CurrencyCode
    let action: () -> Void

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    private var isInline: Bool { placement == .inline }

    var body: some View {
        Group {
            if showsAdd {
                Button(action: action) { addLabel }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L.Month.addExpense)
            } else {
                balance
            }
        }
        .padding(.horizontal, DS.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var addLabel: some View {
        HStack(spacing: DS.Spacing.s) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(DS.Palette.brand)

            if !isInline {
                Text(L.Month.addExpense)
                    .font(DS.Typography.body)
            }

            Spacer(minLength: 0)
        }
        .contentShape(.rect)
    }

    private var balance: some View {
        HStack(spacing: DS.Spacing.s) {
            Image(systemName: "wallet.bifold")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)

            if !isInline {
                Text(L.Month.remaining)
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            Spacer(minLength: DS.Spacing.s)

            Text(MoneyFormat.string(remaining, currency: currency))
                .font(DS.Typography.amountCompact)
                .foregroundStyle(remaining >= .zero ? .primary : DS.Palette.expense)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(L.Month.remaining): \(MoneyFormat.string(remaining, currency: currency))")
    }
}

extension View {
    /// Родное сжатие панели вкладок при прокрутке. Появилось в iOS 26, ниже
    /// панель просто не сжимается.
    @ViewBuilder
    func nativeTabBarMinimize() -> some View {
        if #available(iOS 26.0, *) {
            tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }

    /// Полка над панелью вкладок.
    func tabAccessory(
        showsAdd: Bool,
        remaining: Money,
        currency: CurrencyCode,
        action: @escaping () -> Void
    ) -> some View {
        modifier(TabAccessory(showsAdd: showsAdd, remaining: remaining,
                              currency: currency, action: action))
    }
}
