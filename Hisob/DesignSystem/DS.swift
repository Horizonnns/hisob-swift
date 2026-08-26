import SwiftUI

/// Корень дизайн-системы. Значения только отсюда — хардкод во вью запрещён.
enum DS {}

// MARK: - Отступы и радиусы

extension DS {
    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32

        /// Поля экрана.
        static let screen: CGFloat = 16
    }

    enum Radius {
        static let card: CGFloat = 16
        static let tile: CGFloat = 12
        static let chip: CGFloat = 10
        static let button: CGFloat = 12
        static let control: CGFloat = 10
    }

    enum IconSize {
        static let regular: CGFloat = 17
        static let tile: CGFloat = 20
    }
}

// MARK: - Палитра

extension DS {
    enum Palette {
        /// Акцент бренда — унаследован от веб-версии.
        static let brand = dynamic(light: 0x4F46E5, dark: 0x5B4FFF)

        /// Доход.
        static let income = dynamic(light: 0x059669, dark: 0x10B981)
        /// Расход и перерасход.
        static let expense = dynamic(light: 0xDC2626, dark: 0xEF4444)
        /// Остаток.
        static let remaining = dynamic(light: 0x2563EB, dark: 0x3B82F6)
        /// Перенос из прошлого месяца.
        static let carryover = dynamic(light: 0x4F46E5, dark: 0x6366F1)

        /// Фон экрана. В тёмной теме — глубокий сине-чёрный, как в Telegram:
        /// он мягче чистого чёрного и даёт слоям читаемую иерархию.
        static let background = dynamic(light: 0xF2F3F7, dark: 0x0F1620)
        /// Поверхность карточки.
        static let surface = dynamic(light: 0xFFFFFF, dark: 0x18222D)
        /// Приподнятая поверхность — поля ввода, чипы.
        static let surfaceElevated = dynamic(light: 0xEDEFF3, dark: 0x1F2A36)
        /// Разделитель.
        static let separator = dynamic(light: 0xE3E5EA, dark: 0x253140)

        /// Палитра графиков. Индекс категории стабилен, цвет не «прыгает».
        static let chart: [Color] = [
            dynamic(light: 0x4F46E5, dark: 0x5B4FFF),
            dynamic(light: 0x2563EB, dark: 0x3B82F6),
            dynamic(light: 0x059669, dark: 0x10B981),
            dynamic(light: 0xD97706, dark: 0xF59E0B),
            dynamic(light: 0xDC2626, dark: 0xEF4444),
            dynamic(light: 0xDB2777, dark: 0xEC4899)
        ]

        private static func dynamic(light: UInt32, dark: UInt32) -> Color {
            Color(uiColor: UIColor { traits in
                UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
            })
        }
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Типографика

extension DS {
    enum Typography {
        static let screenTitle = Font.largeTitle.bold()
        static let sectionTitle = Font.title3.weight(.semibold)
        /// Крупная сумма в плашке статистики.
        static let amount = Font.title2.weight(.bold).monospacedDigit()
        /// Сумма в строке списка.
        static let amountCompact = Font.body.weight(.semibold).monospacedDigit()
        static let body = Font.body
        static let caption = Font.caption
        /// Подпись-метка над значением: «ДОХОД», «ОСТАТОК».
        static let label = Font.caption2.weight(.bold)
    }
}

// MARK: - Моторика

extension DS {
    /// Пружины вместо кривых длительности: анимация прерываема на любом кадре
    /// и не «доигрывает» после нового жеста — то, что даёт ощущение живого
    /// интерфейса в Telegram.
    enum Motion {
        /// Основная: смена месяца, появление плашек.
        static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.82)
        /// Спокойная: раскрытие секций, крупные перестроения.
        static let smooth = Animation.spring(response: 0.45, dampingFraction: 0.90)
        /// С отскоком: подтверждения, реакции на действие.
        static let bouncy = Animation.spring(response: 0.38, dampingFraction: 0.68)
        /// Мгновенная: нажатия, подсветка.
        static let quick = Animation.spring(response: 0.22, dampingFraction: 0.85)

        /// Анимация с учётом «Уменьшение движения».
        static func resolved(_ animation: Animation, reduceMotion: Bool) -> Animation? {
            reduceMotion ? nil : animation
        }
    }
}
