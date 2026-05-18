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

/// Glassmorphism-карточка с адаптацией к версии ОС.
///
/// `HSLiquidGlassCard` автоматически выбирает рендер в зависимости от iOS:
/// - **iOS 26+**: нативный `.glassEffect()` API — настоящее системное стекло с размытием.
/// - **iOS 17–25**: fallback через `.ultraThinMaterial` + tint overlay + hairline border.
///
/// При `@Environment(\.accessibilityReduceMotion) == true` всегда переключается на
/// статичный legacyBody без blur-анимаций — требование accessibility.
///
/// Отступы и радиус скругления берутся из ``SpacingTokens`` и ``RadiusTokens``,
/// поэтому карточка всегда согласована с остальным Design System.
///
/// ## Пример
/// ```swift
/// HSLiquidGlassCard(style: .primary) {
///     LyalyaMascotView(state: .happy, size: 120)
///     Text("Привет!").font(TypographyTokens.headline())
/// }
///
/// HSLiquidGlassCard(style: .tinted(ColorTokens.Brand.lilac)) {
///     Text("AR-режим активен")
/// }
/// ```
///
/// ## See Also
/// - ``HSCard``
/// - ``HSLiquidGlassStyle``
/// - ``SpacingTokens``
/// - ``RadiusTokens``
public struct HSLiquidGlassCard<Content: View>: View {

    private let style: HSLiquidGlassStyle
    private let padding: CGFloat
    private let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

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

    /// Light overlay для светлого режима делает стекло светящимся; в dark режиме
    /// белый tint «загрязняет» материал, поэтому используем едва заметный осветляющий слой.
    @ViewBuilder
    private var tintLayer: some View {
        switch style {
        case .primary:
            Color.white.opacity(colorScheme == .dark ? 0.06 : 0.18)
        case .elevated:
            Color.white.opacity(colorScheme == .dark ? 0.10 : 0.32)
        case .tinted(let color):
            color.opacity(colorScheme == .dark ? 0.30 : 0.22)
        }
    }

    /// Hairline border: светлый край в light режиме создаёт «приподнятость»,
    /// в dark режиме слегка светлее — иначе край сливается с фоном.
    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
            .strokeBorder(
                Color.white.opacity(colorScheme == .dark ? 0.14 : 0.32),
                lineWidth: 0.5
            )
    }

    // MARK: - Shadow tokens per style

    private var shadowColor: Color {
        switch style {
        case .primary:           return .black.opacity(0.11)
        case .elevated:          return .black.opacity(0.16)
        case .tinted(let color): return color.opacity(0.20)
        }
    }

    private var shadowRadius: CGFloat {
        switch style {
        case .elevated: return 24
        default:        return 16
        }
    }

    private var shadowY: CGFloat {
        switch style {
        case .elevated: return 12
        default:        return 6
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
