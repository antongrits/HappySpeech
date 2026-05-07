import SwiftUI

// MARK: - HSSkeletonShimmer
//
// Block O v16 — kavsoft-style shimmer placeholder.
//
// ViewModifier `.hsShimmer(active:)` накладывает анимированный градиентный
// блик поверх содержимого. Применяется вместе с `.redacted(reason: .placeholder)`
// для skeleton loading-состояний (ChildHomeView, SessionHistoryView, ParentHome).
//
// Усиление-анимация — LinearGradient с тремя стопами (base → highlight → base),
// маска накладывается на содержимое, startPoint анимируется от (-1, 0.5) до (2, 0.5)
// за 1.4 секунды `repeatForever`.
//
// Usage:
// ```swift
// VStack {
//     HSCard { ... }   // или любой контент
// }
// .redacted(reason: isLoading ? .placeholder : [])
// .hsShimmer(active: isLoading)
// ```
//
// References:
// - Patreon SwiftUI Skeleton View (Kavsoft)
// - github.com/markiv/SwiftUI-Shimmer (MIT)
// - Medium — Skeleton Shimmer SwiftUI

@available(iOS 17.0, *)
public struct HSSkeletonShimmer: ViewModifier {

    public let active: Bool
    public let bandWidth: CGFloat
    public let duration: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    public init(active: Bool = true, bandWidth: CGFloat = 0.4, duration: Double = 1.4) {
        self.active = active
        self.bandWidth = bandWidth
        self.duration = duration
    }

    public func body(content: Content) -> some View {
        content
            .overlay {
                if active {
                    shimmerLayer
                        .blendMode(.overlay)
                        .allowsHitTesting(false)
                }
            }
            .onAppear {
                guard active, !reduceMotion else { return }
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }

    @ViewBuilder
    private var shimmerLayer: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            LinearGradient(
                colors: [
                    .clear,
                    ColorTokens.Overlay.highlight,
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: width * bandWidth)
            .offset(x: -width * bandWidth + (width + width * bandWidth) * phase)
            .frame(width: width, alignment: .leading)
            .clipped()
        }
    }
}

// MARK: - View Extension

@available(iOS 17.0, *)
public extension View {
    /// Накладывает shimmer-эффект поверх view.
    /// Обычно сочетается с `.redacted(reason: .placeholder)`.
    func hsShimmer(active: Bool = true) -> some View {
        self.modifier(HSSkeletonShimmer(active: active))
    }
}

// MARK: - HSSkeletonRow / Block

/// Готовая «карточка-скелет» для строки списка.
@available(iOS 17.0, *)
public struct HSSkeletonRow: View {
    public let height: CGFloat

    public init(height: CGFloat = 20) {
        self.height = height
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: RadiusTokens.xs, style: .continuous)
            .fill(ColorTokens.Overlay.dimmer)
            .frame(height: height)
    }
}

/// Готовая «карточка-скелет» уровня Card.
@available(iOS 17.0, *)
public struct HSSkeletonCard: View {

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            HSSkeletonRow(height: 18)
                .frame(maxWidth: 180)
            HSSkeletonRow(height: 12)
            HSSkeletonRow(height: 12)
                .frame(maxWidth: 220)
        }
        .padding(SpacingTokens.cardPad)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(ColorTokens.Kid.surface)
        )
    }
}

// MARK: - Preview

#Preview("HSSkeletonShimmer") {
    VStack(spacing: SpacingTokens.regular) {
        HSSkeletonCard()
        HSSkeletonCard()
        HSSkeletonCard()
    }
    .padding()
    .hsShimmer(active: true)
    .background(ColorTokens.Kid.bg)
}
