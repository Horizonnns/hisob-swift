import SwiftUI

/// Стеклянная поверхность.
///
/// На iOS 26 — нативный Liquid Glass (`glassEffect`), который сам считает
/// преломление и подстраивается под содержимое под собой. Ниже — материал
/// `.ultraThinMaterial`: визуально проще, но поведение слоёв то же, поэтому
/// вью об этом различии знать не нужно.
private struct GlassSurface: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?
    let isInteractive: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(iOS 26.0, *) {
            var glass = Glass.regular
            if let tint { glass = glass.tint(tint) }
            if isInteractive { glass = glass.interactive() }
            return AnyView(content.glassEffect(glass, in: shape))
        } else {
            return AnyView(
                content
                    .background(DS.Palette.surface.opacity(0.6), in: shape)
                    .background(.ultraThinMaterial, in: shape)
                    .overlay(shape.strokeBorder(DS.Palette.separator, lineWidth: 0.5))
            )
        }
    }
}

extension View {
    /// Стеклянная подложка со скруглением.
    /// - Parameter isInteractive: реагировать ли на касание — для кнопок и чипов.
    func dsGlass(
        cornerRadius: CGFloat = DS.Radius.card,
        tint: Color? = nil,
        isInteractive: Bool = false
    ) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius, tint: tint, isInteractive: isInteractive))
    }

    /// Непрозрачная карточка — там, где стекло мешает читаемости плотного текста.
    func dsSurface(cornerRadius: CGFloat = DS.Radius.card) -> some View {
        background(
            DS.Palette.surface,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }
}
