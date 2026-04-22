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
            radius: 12,
            x: 0, y: 4,
            opacity: 0.08
        )
        public static let cardLg = ShadowStyle(
            color: Color(red: 0.23, green: 0.16, blue: 0.11),
            radius: 20,
            x: 0, y: 8,
            opacity: 0.10
        )
        public static let tile = ShadowStyle(
            color: Color(red: 0.23, green: 0.16, blue: 0.11),
            radius: 8,
            x: 0, y: 2,
            opacity: 0.06
        )
    }

    // MARK: - Parent Circuit Shadows (clean, minimal)

    public enum Parent {
        public static let card = ShadowStyle(
            color: Color(red: 0.06, green: 0.09, blue: 0.16),
            radius: 3,
            x: 0, y: 1,
            opacity: 0.05
        )
        public static let elevated = ShadowStyle(
            color: Color(red: 0.06, green: 0.09, blue: 0.16),
            radius: 8,
            x: 0, y: 2,
            opacity: 0.08
        )
    }
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
}
