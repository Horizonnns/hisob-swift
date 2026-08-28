import SwiftUI
import UIKit

/// Распознаватель горизонтальной протяжки, уживающийся с прокруткой списка.
///
/// `DragGesture` здесь не работает: список забирает протяжку себе — и обычную,
/// и через `simultaneousGesture`, и через `highPriorityGesture` (проверено,
/// касания до карточки доходят — тап срабатывает, а протяжка нет). UIKit-жест
/// решает это честно: он объявляет себя совместимым с чужими распознавателями
/// и стартует только когда движение действительно горизонтальное, поэтому
/// вертикальная прокрутка остаётся у списка.
struct HorizontalSwipe: UIViewRepresentable {
    var onChange: (CGFloat) -> Void
    var onEnd: (CGFloat) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handle(_:))
        )
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.onChange = onChange
        context.coordinator.onEnd = onEnd
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange, onEnd: onEnd)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChange: (CGFloat) -> Void
        var onEnd: (CGFloat) -> Void

        init(onChange: @escaping (CGFloat) -> Void, onEnd: @escaping (CGFloat) -> Void) {
            self.onChange = onChange
            self.onEnd = onEnd
        }

        @objc func handle(_ pan: UIPanGestureRecognizer) {
            let dx = pan.translation(in: pan.view).x
            switch pan.state {
            case .changed:
                onChange(dx)
            case .ended:
                onEnd(dx)
            case .cancelled, .failed:
                onEnd(0)
            default:
                break
            }
        }

        /// Не отбираем жест у списка — работаем рядом.
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            true
        }

        /// Стартуем только на горизонтальном движении: вертикальное — прокрутка.
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }
    }
}
