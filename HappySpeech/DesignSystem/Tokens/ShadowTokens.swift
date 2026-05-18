import SwiftUI

// MARK: - ShadowTokens
// Translated from tokens.jsx kid/parent shadow definitions.

public enum ShadowTokens {

    // MARK: - Shadow Levels

    public enum Level {
        case flat, subtle, card, elevated, floating
    }

    public struct ShadowStyle: Sendable {
        public let color: Color
        public let radius: CGFloat
        public let x: CGFloat
        public let y: CGFloat
        public let opacity: Double
    }

    // MARK: - Kid Circuit Shadows (warm, soft)

    public enum Kid {
        public static let card = ShadowStyle(
            color: Color(red: 0.23, green: 0.16, blue: 0.11),
            radius: 16,
            x: 0, y: 6,
            opacity: 0.11
        )
        public static let cardLg = ShadowStyle(
            color: Color(red: 0.23, green: 0.16, blue: 0.11),
            radius: 28,
            x: 0, y: 12,
            opacity: 0.13
        )
        public static let tile = ShadowStyle(
            color: Color(red: 0.23, green: 0.16, blue: 0.11),
            radius: 10,
            x: 0, y: 3,
            opacity: 0.08
        )
    }

    // MARK: - Parent Circuit Shadows (clean, minimal)

    public enum Parent {
        public static let card = ShadowStyle(
            color: Color(red: 0.06, green: 0.09, blue: 0.16),
            radius: 8,
            x: 0, y: 3,
            opacity: 0.07
        )
        public static let elevated = ShadowStyle(
            color: Color(red: 0.06, green: 0.09, blue: 0.16),
            radius: 16,
            x: 0, y: 6,
            opacity: 0.10
        )
    }

    // MARK: - Depth Shadows (v29 — two-layer contact + ambient)
    //
    // Modern iOS depth reads as TWO stacked shadows: a tight, darker
    // "contact" shadow grounding the element, plus a soft, wide "ambient"
    // shadow describing its height above the base. Use ``DepthShadow`` for
    // raised cards to give them a believable z-axis position.

    public struct DepthShadow: Sendable {
        public let contact: ShadowStyle
        public let ambient: ShadowStyle
    }

    /// Kid circuit — warm-toned, soft depth for raised cards.
    public static let kidDepth = DepthShadow(
        contact: ShadowStyle(
            color: Color(red: 0.23, green: 0.16, blue: 0.11),
            radius: 3, x: 0, y: 2, opacity: 0.10
        ),
        ambient: ShadowStyle(
            color: Color(red: 0.23, green: 0.16, blue: 0.11),
            radius: 22, x: 0, y: 12, opacity: 0.12
        )
    )

    /// Parent / specialist circuit — cool-toned, restrained depth.
    public static let parentDepth = DepthShadow(
        contact: ShadowStyle(
            color: Color(red: 0.06, green: 0.09, blue: 0.16),
            radius: 2, x: 0, y: 1, opacity: 0.08
        ),
        ambient: ShadowStyle(
            color: Color(red: 0.06, green: 0.09, blue: 0.16),
            radius: 16, x: 0, y: 8, opacity: 0.10
        )
    )
}

// MARK: - View Modifier

public struct ShadowModifier: ViewModifier {
    let style: ShadowTokens.ShadowStyle

    public func body(content: Content) -> some View {
        content
            .shadow(
                color: style.color.opacity(style.opacity),
                radius: style.radius,
                x: style.x,
                y: style.y
            )
    }
}

// MARK: - Depth Shadow Modifier (two-layer)

public struct DepthShadowModifier: ViewModifier {
    let depth: ShadowTokens.DepthShadow
    /// 0…1 — press progress; collapses both shadows toward the surface.
    var pressProgress: Double = 0

    public func body(content: Content) -> some View {
        let collapse = 1.0 - pressProgress * 0.65
        return content
            .shadow(
                color: depth.contact.color.opacity(depth.contact.opacity * collapse),
                radius: depth.contact.radius * collapse,
                x: depth.contact.x,
                y: depth.contact.y * collapse
            )
            .shadow(
                color: depth.ambient.color.opacity(depth.ambient.opacity * collapse),
                radius: depth.ambient.radius * collapse,
                x: depth.ambient.x,
                y: depth.ambient.y * collapse
            )
    }
}

public extension View {
    func kidCardShadow() -> some View {
        modifier(ShadowModifier(style: ShadowTokens.Kid.card))
    }
    func kidTileShadow() -> some View {
        modifier(ShadowModifier(style: ShadowTokens.Kid.tile))
    }
    func parentCardShadow() -> some View {
        modifier(ShadowModifier(style: ShadowTokens.Parent.card))
    }
    func parentElevatedShadow() -> some View {
        modifier(ShadowModifier(style: ShadowTokens.Parent.elevated))
    }

    /// Two-layer depth shadow (tight contact + soft ambient).
    /// - Parameter pressProgress: 0…1, collapses the shadow on press.
    func depthShadow(
        _ depth: ShadowTokens.DepthShadow,
        pressProgress: Double = 0
    ) -> some View {
        modifier(DepthShadowModifier(depth: depth, pressProgress: pressProgress))
    }

    /// Two-layer depth shadow selected by circuit context.
    func depthShadow(
        for circuit: CircuitContext,
        pressProgress: Double = 0
    ) -> some View {
        let depth: ShadowTokens.DepthShadow = (circuit == .kid)
            ? ShadowTokens.kidDepth
            : ShadowTokens.parentDepth
        return modifier(DepthShadowModifier(depth: depth, pressProgress: pressProgress))
    }
}
