import HisobCore
import SwiftUI

/// Подписи и иконки видов разовых поступлений.
///
/// Цвет у всех один — зелёный дохода. Виды различаются иконкой: пёстрые
/// поступления в списке спорили бы с категориями трат, а важно как раз то,
/// что это деньги пришли, а не ушли.
enum ReceiptPresentation {
    static func title(_ kind: ReceiptKind) -> String {
        switch kind {
        case .gift: "Подарок"
        case .refund: "Возврат"
        case .sale: "Продажа"
        case .bonus: "Премия"
        case .other: "Прочее"
        default: kind.rawValue
        }
    }

    static func symbol(_ kind: ReceiptKind) -> String {
        switch kind {
        case .gift: "gift.fill"
        case .refund: "arrow.uturn.left"
        case .sale: "tag.fill"
        case .bonus: "star.fill"
        case .other: "plus"
        default: "plus"
        }
    }

    static let tint = DS.Palette.income
}
