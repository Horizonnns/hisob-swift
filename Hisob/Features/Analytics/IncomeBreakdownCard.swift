import HisobCore
import SwiftUI

/// Из чего сложился доход месяца.
///
/// Карточка существует именно потому, что источников может быть несколько:
/// в переходные месяцы видно, что доход собрался с двух работ.
struct IncomeBreakdownCard: View {
    let shares: [IncomeShare]
    /// Разовые поступления месяца. Без них «Итого» не сходилось бы: доход
    /// теперь включает подарки и возвраты, а строки перечисляли только работы.
    let receipts: [ReceiptShare]
    let total: Money
    let currency: CurrencyCode

    private var rowCount: Int { shares.count + receipts.count }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            Text(L.Analytics.incomeSources)
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(shares) { share in
                HStack(spacing: DS.Spacing.m) {
                    Image(systemName: "briefcase.fill")
                        .font(.caption)
                        .foregroundStyle(DS.Palette.income)

                    Text(share.sourceName)
                        .font(DS.Typography.body)
                        .lineLimit(1)

                    Spacer(minLength: DS.Spacing.s)

                    Text(MoneyFormat.string(share.amount, currency: currency))
                        .font(DS.Typography.amountCompact)
                }
                .accessibilityElement(children: .combine)
            }

            ForEach(receipts) { share in
                HStack(spacing: DS.Spacing.m) {
                    Image(systemName: ReceiptPresentation.symbol(share.kind))
                        .font(.caption)
                        .foregroundStyle(DS.Palette.income)

                    Text(ReceiptPresentation.title(share.kind))
                        .font(DS.Typography.body)
                        .lineLimit(1)

                    Spacer(minLength: DS.Spacing.s)

                    Text(MoneyFormat.string(share.amount, currency: currency))
                        .font(DS.Typography.amountCompact)
                }
                .accessibilityElement(children: .combine)
            }

            if rowCount > 1 {
                Divider().overlay(DS.Palette.separator)

                HStack {
                    Text(L.Analytics.total)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Spacer()
                    Text(MoneyFormat.string(total, currency: currency))
                        .font(DS.Typography.amountCompact)
                        .foregroundStyle(DS.Palette.income)
                }
            }
        }
        .padding(DS.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsGlass()
    }
}
