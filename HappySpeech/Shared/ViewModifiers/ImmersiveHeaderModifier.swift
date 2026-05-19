import SwiftUI

// MARK: - Immersive Header & Glass Edge Modifiers
//
// v30 Phase 7 — still-open research-spec items #13 and #16:
//  • `.backgroundExtensionEffect` — hero imagery bleeds under the nav glass
//    so headers feel immersive (iOS 26, gracefully degraded below).
//  • Soft specular edge — a faint 1px gradient stroke (bright top → clear
//    bottom) giving any surface the iOS 26 glass signature.
//
// All effects are purely visual: they survive Reduce Motion and Reduce
// Transparency without breaking layout.

public extension View {

    /// Lets hero imagery extend visually beneath translucent navigation
    /// chrome. On iOS 26 this uses the native `.backgroundExtensionEffect`;
    /// on iOS 17–25 the view simply ignores the top safe area so the same
    /// immersive bleed is achieved without the system mirroring.
    @ViewBuilder
    func immersiveHeader() -> some View {
        if #available(iOS 26, *) {
            self.backgroundExtensionEffect()
        } else {
            self.ignoresSafeArea(edges: .top)
        }
    }

    /// Soft specular edge — a 1px gradient hairline that is bright at the
    /// top (catching light) and fades to clear at the bottom. The signature
    /// detail that separates modern glass cards from flat 2019-era cards.
    ///
    /// - Parameters:
    ///   - cornerRadius: corner radius of the surface being stroked.
    ///   - intensity: 0…1 multiplier for the highlight brightness.
    func specularEdge(
        cornerRadius: CGFloat,
        intensity: Double = 1.0
    ) -> some View {
        modifier(SpecularEdgeModifier(cornerRadius: cornerRadius, intensity: intensity))
    }
}

// MARK: - Specular Edge Modifier

public struct SpecularEdgeModifier: ViewModifier {

    let cornerRadius: CGFloat
    let intensity: Double

    @Environment(\.colorScheme) private var colorScheme

    public func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(edgeGradient, lineWidth: 1)
        )
    }

    private var edgeGradient: LinearGradient {
        let top = (colorScheme == .dark ? 0.26 : 0.62) * intensity
        let bottom = (colorScheme == .dark ? 0.03 : 0.08) * intensity
        return LinearGradient(
            colors: [
                Color.white.opacity(top),
                Color.white.opacity(bottom)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Preview

#Preview("Specular edge") {
    ZStack {
        LinearGradient(
            colors: [ColorTokens.Brand.lilac, ColorTokens.Brand.sky],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
            .fill(.ultraThinMaterial)
            .frame(width: 240, height: 160)
            .specularEdge(cornerRadius: RadiusTokens.card)
    }
}
