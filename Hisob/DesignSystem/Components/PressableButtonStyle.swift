import SwiftUI

/// Нажатие с уменьшением и лёгким затуханием.
///
/// Ключевое — пружина: если отпустить и сразу нажать снова, анимация
/// подхватывается с текущего кадра, а не начинается заново.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.94

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? scale : 1))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(DS.Motion.quick, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
    static func pressable(scale: CGFloat) -> PressableButtonStyle {
        PressableButtonStyle(scale: scale)
    }
}
