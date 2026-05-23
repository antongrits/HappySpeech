import SwiftUI

// MARK: - HSParallaxTile
//
// Step 9 / Diploma plan — `ViewModifier` that gives a tile a subtle
// Y-axis parallax offset based on its distance from the scroll-view's
// vertical centre. Intended for WorldMap islands, Rewards animal cards,
// AchievementWall trophies and similar gallery surfaces.

/// View modifier producing scroll-driven parallax.
///
/// The tile reads its own frame in the scroll-view coordinate space using a
/// `GeometryReader`, computes its distance from the scroll centre and
/// translates itself along Y by `distance × factor`.
///
/// `factor = 0` → no parallax. `factor = 0.3` (default) → soft, magazine-y
/// drift. `factor = 1.0` → lockstep.
///
/// All animation is gated behind `accessibilityReduceMotion` — when
/// reduced motion is active the modifier returns the tile unchanged.
public struct HSParallaxTileModifier: ViewModifier {

    /// Strength of the parallax. 0 = none, 1 = full lockstep.
    public let factor: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(factor: CGFloat = 0.3) {
        self.factor = max(0, min(factor, 1))
    }

    public func body(content: Content) -> some View {
        if reduceMotion || factor <= 0 {
            content
        } else {
            content
                .background(
                    GeometryReader { _ in
                        Color.clear.preference(
                            key: HSParallaxTilePreference.self,
                            value: 0
                        )
                    }
                )
                .modifier(
                    HSParallaxOffset(factor: factor)
                )
        }
    }
}

// MARK: - Offset modifier (driven by GeometryReader)

private struct HSParallaxOffset: ViewModifier {
    let factor: CGFloat

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .global)
            let screenMid = UIScreen.main.bounds.midY
            let distance = frame.midY - screenMid
            let offset = -distance * factor

            content
                .offset(y: offset)
        }
    }
}

// MARK: - Preference key

private struct HSParallaxTilePreference: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - View extension

public extension View {

    /// Applies a HappySpeech parallax effect: the view drifts along Y
    /// relative to its distance from the screen vertical centre.
    ///
    /// - Parameter factor: 0 = no parallax (default `0.3` = soft drift).
    ///
    /// ## Example — WorldMap island gallery
    /// ```swift
    /// ScrollView {
    ///     LazyVStack(spacing: SpacingTokens.large) {
    ///         ForEach(islands) { island in
    ///             IslandTile(island)
    ///                 .hsParallaxTile(factor: 0.25)
    ///         }
    ///     }
    /// }
    /// ```
    func hsParallaxTile(factor: CGFloat = 0.3) -> some View {
        modifier(HSParallaxTileModifier(factor: factor))
    }
}

// MARK: - Geometric helper (testable)

/// Pure geometry helper extracted for unit testing.
///
/// Computes the parallax Y offset for a tile whose centre is at `tileMidY`
/// on a screen of vertical midpoint `screenMidY`, given a `factor` between
/// 0 and 1.
public enum HSParallaxGeometry {

    /// Returns the Y offset to apply to a tile so that it drifts relative
    /// to the screen centre.
    public static func offset(
        tileMidY: CGFloat,
        screenMidY: CGFloat,
        factor: CGFloat
    ) -> CGFloat {
        let clampedFactor = max(0, min(factor, 1))
        let distance = tileMidY - screenMidY
        return -distance * clampedFactor
    }
}

// MARK: - Preview

#Preview("HSParallaxTile — 5-tile scroll") {
    ScrollView {
        LazyVStack(spacing: SpacingTokens.large) {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(ColorTokens.Brand.primary.opacity(0.6 + Double(index) * 0.08))
                    .frame(height: 160)
                    .overlay(
                        Text("Tile \(index + 1)")
                            .font(TypographyTokens.title())
                            .foregroundStyle(ColorTokens.Overlay.onAccent)
                    )
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .hsParallaxTile(factor: 0.25)
            }
        }
        .padding(.vertical, SpacingTokens.pageTop)
    }
}
