import SwiftUI

// MARK: - HSCardStyle (standalone enum to avoid generic type constraints)

public enum HSCardStyle {
    case elevated   // card with shadow
    case flat       // no shadow, subtle border
    case tinted(Color)  // coloured background
}

// MARK: - HSCard

/// Reusable card container. Adapts shadow/surface to circuit context.
public struct HSCard<Content: View>: View {

    private let style: HSCardStyle
    private let padding: CGFloat
    private let content: () -> Content

    @Environment(\.circuitContext) private var circuit
    @Environment(\.colorScheme) private var colorScheme

    public init(
        style: HSCardStyle = .elevated,
        padding: CGFloat = SpacingTokens.cardPad,
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
            .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous))
            .applyShadow(for: circuit, style: style)
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .elevated, .flat:
            surfaceColor
        case .tinted(let color):
            color
        }
    }

    private var surfaceColor: Color {
        switch circuit {
        case .kid:        return ColorTokens.Kid.surface
        case .parent:     return ColorTokens.Parent.surface
        case .specialist: return ColorTokens.Spec.surface
        }
    }
}

// MARK: - Shadow Helpers

private extension View {
    @ViewBuilder
    func applyShadow(for circuit: CircuitContext, style: HSCardStyle) -> some View {
        switch style {
        case .elevated:
            switch circuit {
            case .kid:
                self.kidCardShadow()
            case .parent, .specialist:
                self.parentCardShadow()
            }
        case .flat:
            self.overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
        case .tinted:
            self
        }
    }
}

// MARK: - Preview

#Preview("HSCard") {
    VStack(spacing: 16) {
        HSCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Звук Р")
                    .font(TypographyTokens.headline())
                Text("Сонорный согласный. Работаем на этапе слога.")
                    .font(TypographyTokens.body())
            }
        }
        HSCard(style: .flat) {
            Text("Плоская карточка")
        }
        HSCard(style: .tinted(ColorTokens.Brand.mint.opacity(0.2))) {
            Text("Тинтованная карточка")
        }
    }
    .padding()
    .background(ColorTokens.Kid.bg)
    .environment(\.circuitContext, .kid)
}
