import SwiftUI

// MARK: - SpotlightOverlay

/// Dims the screen with a translucent black layer and punches a rounded
/// rectangular hole around the currently highlighted element.
///
/// Uses `Canvas` + `.destinationOut` blend mode for efficient GPU rendering.
/// `.allowsHitTesting(false)` keeps the overlay non-interactive so taps pass
/// through to the underlying UI (the tip bubble handles its own hit testing).
struct SpotlightOverlay: View {

    let highlightRect: CGRect?
    let cornerRadius: CGFloat
    let dimOpacity: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        highlightRect: CGRect?,
        cornerRadius: CGFloat = RadiusTokens.card,
        dimOpacity: Double = 0.6
    ) {
        self.highlightRect = highlightRect
        self.cornerRadius = cornerRadius
        self.dimOpacity = dimOpacity
    }

    var body: some View {
        Canvas { context, size in
            // 1. Dim everything.
            let full = Path(CGRect(origin: .zero, size: size))
            context.fill(full, with: .color(.black.opacity(dimOpacity)))

            // 2. Cut out the spotlight rect.
            guard let rect = highlightRect, rect != .zero else { return }

            let inset = rect.insetBy(dx: -8, dy: -8)
            let hole = Path(roundedRect: inset, cornerRadius: cornerRadius)

            var cutout = context
            cutout.blendMode = .destinationOut
            cutout.fill(hole, with: .color(.white))
        }
        .compositingGroup()
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .animation(
            reduceMotion ? .linear(duration: 0.15) : MotionTokens.outQuick,
            value: highlightRect
        )
    }
}

// MARK: - Preview

#Preview("Spotlight") {
    ZStack {
        ColorTokens.Kid.bg.ignoresSafeArea()
        VStack {
            Text("Привет! Я подсвечен.")
                .padding(24)
                .background(ColorTokens.Kid.surface, in: RoundedRectangle(cornerRadius: 20))
        }
        SpotlightOverlay(
            highlightRect: CGRect(x: 60, y: 320, width: 260, height: 80)
        )
    }
}
