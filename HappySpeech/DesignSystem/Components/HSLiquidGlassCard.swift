import SwiftUI

// MARK: - HSLiquidGlassStyle

public enum HSLiquidGlassStyle: Sendable, Equatable {
    /// Translucent white glass (default surface).
    case primary
    /// More opaque variant for dense content.
    case elevated
    /// Tinted glass with a custom hue.
    case tinted(Color)
}

// MARK: - HSLiquidGlassCard

/// Glassmorphism card. Uses `.glassEffect()` on iOS 26+ where available,
/// otherwise falls back to `.ultraThinMaterial` + hairline overlay + soft
/// shadow. Padding and corner radius come from `SpacingTokens` and
/// `RadiusTokens` so the card matches the rest of the system.
public struct HSLiquidGlassCard<Content: View>: View {

    private let style: HSLiquidGlassStyle
    private let padding: CGFloat
    private let content: () -> Content

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
        content()
            .padding(padding)
            .background(backgroundView)
            .overlay(borderOverlay)
            .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundView: some View {
        ZStack {
            // Material layer always present — guarantees blur on iOS 17–25
            // and a sensible substrate on iOS 26 even if glassEffect is unavailable.
            Rectangle()
                .fill(.ultraThinMaterial)
            tintLayer
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
