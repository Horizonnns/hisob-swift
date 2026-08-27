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
        /// Удаление. Глубже, чем красный расхода: это не цифра, а действие,
        /// и оно не должно выглядеть как ещё одна сумма.
        static let destructive = dynamic(light: 0xB3261E, dark: 0xD22B2B)
        /// Остаток.
        static let remaining = dynamic(light: 0x2563EB, dark: 0x3B82F6)
        /// Перенос из прошлого месяца.
        static let carryover = dynamic(light: 0x4F46E5, dark: 0x6366F1)

        /// Фон экрана. В тёмной теме — чистый чёрный, как в ночной теме
        /// Telegram: на OLED он гаснет полностью, и карточки читаются
        /// как приподнятые слои, а не как пятна на сером.
        static let background = dynamic(light: 0xF2F3F7, dark: 0x000000)
        /// Поверхность карточки — первый слой над чёрным.
        static let surface = dynamic(light: 0xFFFFFF, dark: 0x131315)
        /// Приподнятая поверхность — поля ввода, чипы.
        static let surfaceElevated = dynamic(light: 0xEDEFF3, dark: 0x1F1F23)
        /// Разделитель. На чёрном достаточно едва заметного.
        static let separator = dynamic(light: 0xE3E5EA, dark: 0x2A2A2E)

        /// Палитра общего назначения.
        static let chart: [Color] = [
            dynamic(light: 0x4F46E5, dark: 0x5B4FFF),
            dynamic(light: 0x2563EB, dark: 0x3B82F6),
            dynamic(light: 0x059669, dark: 0x10B981),
            dynamic(light: 0xD97706, dark: 0xF59E0B),
            dynamic(light: 0xDC2626, dark: 0xEF4444),
            dynamic(light: 0xDB2777, dark: 0xEC4899)
        ]

        /// Отдельный оттенок на каждую из встроенных категорий.
        ///
        /// Палитры из шести цветов не хватало: индексы категорий сходились
        /// по модулю, и на кольцевой диаграмме соседние секторы (Кредит и
        /// Транспорт) красились одинаково. Порядок строго совпадает с
        /// `ExpenseCategory.builtIn`.
        static let categoryTints: [Color] = [
            dynamic(light: 0xEA580C, dark: 0xFB923C), // Еда
            dynamic(light: 0x2563EB, dark: 0x3B82F6), // Транспорт
            dynamic(light: 0x7C3AED, dark: 0xA78BFA), // Аренда
            dynamic(light: 0xCA8A04, dark: 0xFACC15), // Коммуналка
            dynamic(light: 0x0891B2, dark: 0x22D3EE), // Связь/Интернет
            dynamic(light: 0xDC2626, dark: 0xF87171), // Здоровье
            dynamic(light: 0x0D9488, dark: 0x2DD4BF), // Гигиена
            dynamic(light: 0xDB2777, dark: 0xF472B6), // Косметика
            dynamic(light: 0x4F46E5, dark: 0x818CF8), // Одежда
            dynamic(light: 0xC026D3, dark: 0xE879F9), // Развлечения
            dynamic(light: 0x16A34A, dark: 0x4ADE80), // Образование
            dynamic(light: 0xE11D48, dark: 0xFB7185), // Подарки
            dynamic(light: 0x059669, dark: 0x34D399), // Благотворительность
            dynamic(light: 0x9F1239, dark: 0xE11D48), // Кредит
            dynamic(light: 0x047857, dark: 0x10B981), // Сбережения
            dynamic(light: 0x64748B, dark: 0x94A3B8)  // Прочее
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
