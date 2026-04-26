import SwiftUI

// MARK: - HSLiquidGlassStyle

public enum HSLiquidGlassStyle: Sendable, Equatable {
    /// Translucent white glass (default surface).
    case primary
    /// More opaque variant for dense content — main CTA cards, modal sheets.
    case elevated
    /// Tinted glass with a custom hue — stats, progress, accent sections.
    case tinted(Color)
}

// MARK: - HSLiquidGlassCard

/// Glassmorphism card that adapts to the OS version:
/// - iOS 26+: uses native `.glassEffect()` API for true system-level glass.
/// - iOS 17–25: falls back to `.ultraThinMaterial` + tint overlay + hairline border.
///
/// Padding and corner radius come from `SpacingTokens` / `RadiusTokens` so
/// the card is always consistent with the rest of the design system.
public struct HSLiquidGlassCard<Content: View>: View {

    private let style: HSLiquidGlassStyle
    private let padding: CGFloat
    private let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        style: HSLiquidGlassStyle = .primary,
        padding: CGFloat = SpacingTokens.regular,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.style = style
        self.padding = padding
        self.content = content
    }

    public var body: some View {
        // На iOS 26 используем нативный glassEffect, если только не включён Reduced Motion.
        // При reduceMotion переходим на статичный legacyBody (ultraThinMaterial без blur-анимаций).
        if #available(iOS 26, *), !reduceMotion {
            ios26Body
        } else {
            legacyBody
        }
    }

    // MARK: - iOS 26 body

    @available(iOS 26, *)
    private var ios26Body: some View {
        let shape = RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
        return Group {
            switch style {
            case .primary:
                content()
                    .padding(padding)
                    .glassEffect(.regular, in: shape)
                    .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
            case .elevated:
                content()
                    .padding(padding)
                    .glassEffect(.regular, in: shape)
                    .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
            case .tinted(let color):
                content()
                    .padding(padding)
                    .glassEffect(.regular.tint(color.opacity(0.28)), in: shape)
                    .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
            }
        }
    }

    // MARK: - Legacy body (iOS 17–25)

    private var legacyBody: some View {
        content()
            .padding(padding)
            .background(legacyBackground)
            .overlay(borderOverlay)
            .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous))
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
    }

    @ViewBuilder
    private var legacyBackground: some View {
        ZStack {
            // Material layer guarantees blur on iOS 17–25.
            Rectangle().fill(legacyMaterial)
            tintLayer
        }
    }

    private var legacyMaterial: Material {
        switch style {
        case .primary:   return .ultraThinMaterial
        case .elevated:  return .ultraThickMaterial
        case .tinted:    return .ultraThinMaterial
        }
    }

    @ViewBuilder
    private var tintLayer: some View {
        switch style {
        case .primary:
            Color.white.opacity(0.18)
        case .elevated:
            Color.white.opacity(0.32)
        case .tinted(let color):
            color.opacity(0.22)
        }
    }

    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
    }

    // MARK: - Shadow tokens per style

    private var shadowColor: Color {
        switch style {
        case .primary:           return .black.opacity(0.08)
        case .elevated:          return .black.opacity(0.15)
        case .tinted(let color): return color.opacity(0.18)
        }
    }

    private var shadowRadius: CGFloat {
        switch style {
        case .elevated: return 20
        default:        return 12
        }
    }

    private var shadowY: CGFloat {
        switch style {
        case .elevated: return 10
        default:        return 4
        }
    }
}

// MARK: - Preview

#Preview("HSLiquidGlassCard styles") {
    ZStack {
        LinearGradient(
            colors: [ColorTokens.Brand.lilac, ColorTokens.Brand.sky],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: SpacingTokens.large) {
            HSLiquidGlassCard(style: .primary) {
                VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                    Text("Primary glass")
                        .font(TypographyTokens.headline())
                    Text("Translucent surface for kid circuit")
                        .font(TypographyTokens.body())
                }
            }
            HSLiquidGlassCard(style: .elevated) {
                Text("Elevated glass")
                    .font(TypographyTokens.headline())
            }
            HSLiquidGlassCard(style: .tinted(ColorTokens.Brand.mint)) {
                Text("Tinted glass")
                    .font(TypographyTokens.headline())
            }
        }
        .padding()
    }
}
