import HisobCore
import SwiftUI

/// Строка поступления.
///
/// Отличается от траты знаком и цветом суммы: в общем списке дня взгляд должен
/// с ходу отделять пришедшее от ушедшего. Иконка в зелёной плашке — по виду
/// поступления, подпись под названием говорит, что это за деньги.
struct ReceiptRow: View {
    let receipt: Receipt
    let currency: CurrencyCode

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            icon

            VStack(alignment: .leading, spacing: 2) {
                Text(receipt.title.isEmpty ? ReceiptPresentation.title(receipt.kind) : receipt.title)
                    .font(DS.Typography.body)
                    .lineLimit(1)

                if !receipt.title.isEmpty {
                    Text(ReceiptPresentation.title(receipt.kind))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: DS.Spacing.s)

            Text("+\(MoneyFormat.string(receipt.amount, currency: currency))")
                .font(DS.Typography.amountCompact)
                .foregroundStyle(DS.Palette.income)
                .lineLimit(1)
        }
        .padding(.vertical, DS.Spacing.s)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(L.Receipt.title): \(receipt.title)")
        .accessibilityValue("+\(MoneyFormat.string(receipt.amount, currency: currency))")
    }

    private var icon: some View {
        Image(systemName: ReceiptPresentation.symbol(receipt.kind))
            .font(.system(size: DS.IconSize.regular, weight: .medium))
            .foregroundStyle(ReceiptPresentation.tint)
            .frame(width: 32, height: 32)
            .background(
                ReceiptPresentation.tint.opacity(0.14),
                in: RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
            )
    }
}
