import SwiftUI

// MARK: - HSScrollDrivenShape
//
// Step 9 / Diploma plan — `Shape` whose geometry morphs between two configs
// (e.g. circle ↔ rounded rect) based on a scroll-driven `progress: CGFloat`
// (0…1). The morph is achieved by sampling N control points on each path and
// linearly interpolating between corresponding samples.
//
// Designed to pair with `.scrollPosition(id:)` via `HSScrollDrivenShapeModifier`,
// so a hero banner card can round its corners more as the user scrolls up.

/// A `Shape` that interpolates between a start and end path based on `progress`.
///
/// Use this for hero banners, expanding pill controls or any UI surface
/// whose silhouette must respond to scroll position. The two endpoint
/// shapes are described as `(rect → Path)` closures, sampled at
/// `sampleCount` points, then tweened linearly.
///
/// ## Example — hero card that rounds its corners as you scroll up
/// ```swift
/// HSScrollDrivenShape(
///     progress: progress,
///     start: { RoundedRectangle(cornerRadius: RadiusTokens.lg).path(in: $0) },
///     end:   { RoundedRectangle(cornerRadius: RadiusTokens.full).path(in: $0) }
/// )
/// .fill(ColorTokens.Brand.primary)
/// .frame(height: 220)
/// ```
///
/// ## See Also
/// - ``HSScrollDrivenShapeModifier``
public struct HSScrollDrivenShape: Shape {

    /// Morph progress, 0 = `start` path, 1 = `end` path.
    public var progress: CGFloat

    /// Closure producing the start path for the rect supplied by `path(in:)`.
    private let start: @Sendable (CGRect) -> Path
    /// Closure producing the end path for the rect supplied by `path(in:)`.
    private let end: @Sendable (CGRect) -> Path
    /// Number of equally-spaced samples taken on each path before interpolation.
    private let sampleCount: Int

    public init(
        progress: CGFloat,
        sampleCount: Int = 64,
        start: @escaping @Sendable (CGRect) -> Path,
        end: @escaping @Sendable (CGRect) -> Path
    ) {
        self.progress = progress
        self.sampleCount = max(8, sampleCount)
        self.start = start
        self.end = end
    }

    public var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    public func path(in rect: CGRect) -> Path {
        let clamped = min(max(progress, 0), 1)
        let startPath = start(rect)
        let endPath = end(rect)

        // Fast paths — skip sampling when at an endpoint.
        if clamped <= 0 { return startPath }
        if clamped >= 1 { return endPath }

        let startSamples = HSScrollDrivenShape.sample(startPath, count: sampleCount)
        let endSamples = HSScrollDrivenShape.sample(endPath, count: sampleCount)

        guard startSamples.count == endSamples.count, !startSamples.isEmpty else {
            // Fallback if sampling failed for either endpoint.
            return clamped < 0.5 ? startPath : endPath
        }

        var morphed = Path()
        for index in startSamples.indices {
            let interpolated = HSScrollDrivenShape.interpolate(
                from: startSamples[index],
                to: endSamples[index],
                progress: clamped
            )
            if index == 0 {
                morphed.move(to: interpolated)
            } else {
                morphed.addLine(to: interpolated)
            }
        }
        morphed.closeSubpath()
        return morphed
    }

    // MARK: - Private helpers

    /// Samples a closed path at `count` equally-spaced positions along its perimeter.
    ///
    /// Uses `trimmedPath(from:to:)` to extract a tiny sub-segment around each
    /// fraction along the path, then takes its bounding-box centre as the
    /// sample. Works for every standard SwiftUI shape (rect, rounded rect,
    /// circle, capsule, ellipse).
    private static func sample(_ path: Path, count: Int) -> [CGPoint] {
        var points: [CGPoint] = []
        points.reserveCapacity(count)
        for index in 0..<count {
            let fraction = CGFloat(index) / CGFloat(count)
            let upper = min(fraction + 0.0005, 1)
            let segment = path.trimmedPath(from: fraction, to: upper)
            let box = segment.boundingRect
            if box.isNull || box.isEmpty {
                // Fallback to origin of segment's cgPath bounding box.
                points.append(segment.cgPath.boundingBox.origin)
            } else {
                points.append(CGPoint(x: box.midX, y: box.midY))
            }
        }
        return points
    }

    /// Linearly interpolates between two points by `progress` (0…1).
    private static func interpolate(from start: CGPoint, to end: CGPoint, progress: CGFloat) -> CGPoint {
        CGPoint(
            x: start.x + (end.x - start.x) * progress,
            y: start.y + (end.y - start.y) * progress
        )
    }
}

// MARK: - HSScrollDrivenShapeModifier

/// View modifier that drives a `progress` binding from a scroll container's
/// position. Pair with `.scrollPosition(id:)` to feed the offset into a
/// child `HSScrollDrivenShape`.
///
/// ## Example
/// ```swift
/// @State private var visibleId: String? = "hero"
/// @State private var progress: CGFloat = 0
///
/// ScrollView {
///     HeroBanner(progress: progress)
///         .id("hero")
///     LazyVStack { ... }
/// }
/// .scrollPosition(id: $visibleId)
/// .modifier(HSScrollDrivenShapeModifier(progressKey: "hero",
///                                       visibleId: visibleId,
///                                       progress: $progress))
/// ```
public struct HSScrollDrivenShapeModifier: ViewModifier {

    /// Identifier whose visibility drives `progress`.
    public let progressKey: String
    /// Current visible scroll target. When equal to `progressKey`, progress = 0.
    public let visibleId: String?
    /// Output progress (0 = `progressKey` fully visible, 1 = scrolled past).
    @Binding public var progress: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(progressKey: String, visibleId: String?, progress: Binding<CGFloat>) {
        self.progressKey = progressKey
        self.visibleId = visibleId
        self._progress = progress
    }

    public func body(content: Content) -> some View {
        content
            .onChange(of: visibleId) { _, newValue in
                let target: CGFloat = newValue == progressKey ? 0 : 1
                if reduceMotion {
                    progress = target
                } else {
                    withAnimation(MotionTokens.smooth) {
                        progress = target
                    }
                }
            }
    }
}

// MARK: - Preview

#Preview("HSScrollDrivenShape — morph") {
    struct PreviewHost: View {
        @State private var progress: CGFloat = 0
        var body: some View {
            VStack(spacing: SpacingTokens.large) {
                HSScrollDrivenShape(
                    progress: progress,
                    start: { rect in
                        RoundedRectangle(cornerRadius: RadiusTokens.lg).path(in: rect)
                    },
                    end: { rect in
                        Circle().path(in: rect)
                    }
                )
                .fill(ColorTokens.Brand.primary)
                .frame(width: 220, height: 220)

                Slider(value: $progress, in: 0...1)
                    .padding(.horizontal, SpacingTokens.screenEdge)

                Text("progress: \(progress, specifier: "%.2f")")
                    .font(TypographyTokens.body())
            }
            .padding(SpacingTokens.large)
        }
    }
    return PreviewHost()
}
