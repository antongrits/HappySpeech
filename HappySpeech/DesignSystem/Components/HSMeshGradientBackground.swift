import SwiftUI

// MARK: - HSMeshGradientBackground
//
// Block O v16 (бонусный компонент) — анимированный mesh gradient фон.
//
// Полноэкранный мягкий фон для kid-контура. На iOS 18+ использует `MeshGradient`
// 3×3 с медленной анимацией control points (autoreverse каждые 4 сек).
// На iOS 17 — деградация до `RadialGradient` (без анимации точек).
//
// Идеально для ChildHomeView, OnboardingView, RewardsView, CelebrationOverlay.
// При Reduce Motion — статический gradient без анимации.
//
// Usage:
// ```swift
// ZStack {
//     HSMeshGradientBackground(palette: .kidWarm)
//         .ignoresSafeArea()
//     content
// }
// ```
//
// References:
// - Hacking with Swift — MeshGradient
// - Donny Wals — Animating MeshGradient iOS 18

@available(iOS 17.0, *)
public struct HSMeshGradientBackground: View {

    // MARK: - Palette

    public enum Palette {
        case kidWarm
        case kidWarmDark
        case kidCool
        case rewards
        case calm

        var colors: [Color] {
            switch self {
            case .kidWarm:
                return [
                    ColorTokens.Brand.primaryLo, ColorTokens.Brand.butter, ColorTokens.Brand.rose,
                    ColorTokens.Kid.bgSofter, ColorTokens.Brand.primaryLo.opacity(0.7), ColorTokens.Brand.butter,
                    ColorTokens.Brand.rose, ColorTokens.Kid.bg, ColorTokens.Brand.primary.opacity(0.4)
                ]
            case .kidWarmDark:
                // Тёплый глубокий тёмный фон для ChildHome в dark режиме —
                // вместо монотонного коричневого (v27-spec, изменение #1).
                return [
                    ColorTokens.Brand.primary.opacity(0.25), ColorTokens.Brand.rose.opacity(0.20), ColorTokens.Kid.bgDeep,
                    ColorTokens.Brand.rose.opacity(0.18), ColorTokens.Kid.bgDeep, ColorTokens.Brand.primary.opacity(0.16),
                    ColorTokens.Kid.bgDeep, ColorTokens.Brand.primary.opacity(0.22), ColorTokens.Brand.rose.opacity(0.20)
                ]
            case .kidCool:
                return [
                    ColorTokens.Brand.sky, ColorTokens.Brand.lilac, ColorTokens.Brand.mint,
                    ColorTokens.Kid.bgSoft, ColorTokens.Brand.sky.opacity(0.5), ColorTokens.Brand.lilac.opacity(0.5),
                    ColorTokens.Brand.mint, ColorTokens.Kid.bg, ColorTokens.Brand.sky
                ]
            case .rewards:
                return [
                    ColorTokens.Brand.gold, ColorTokens.Brand.butter, ColorTokens.Brand.primaryLo,
                    ColorTokens.Brand.butter, ColorTokens.Kid.bgSofter, ColorTokens.Brand.gold.opacity(0.6),
                    ColorTokens.Brand.primaryLo, ColorTokens.Brand.butter, ColorTokens.Brand.gold
                ]
            case .calm:
                return [
                    ColorTokens.Brand.mint, ColorTokens.Brand.sky.opacity(0.5), ColorTokens.Brand.mint.opacity(0.6),
                    ColorTokens.Brand.lilac.opacity(0.4), ColorTokens.Kid.bgSofter, ColorTokens.Brand.mint,
                    ColorTokens.Brand.sky.opacity(0.4), ColorTokens.Brand.mint, ColorTokens.Brand.lilac.opacity(0.3)
                ]
            }
        }
    }

    // MARK: - Public API

    public let palette: Palette
    public let animated: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(palette: Palette = .kidWarm, animated: Bool = true) {
        self.palette = palette
        self.animated = animated
    }

    // MARK: - Body

    public var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                meshLayer
            } else {
                fallbackLayer
            }
        }
    }

    // MARK: - iOS 18 Mesh
    //
    // Control points drift organically along independent sine paths with
    // prime-ratio periods, so the loop never visibly repeats (~18s feel).
    // `TimelineView` drives a continuous phase; Reduce Motion freezes it.

    @available(iOS 18.0, *)
    @ViewBuilder
    private var meshLayer: some View {
        if animated && !reduceMotion {
            TimelineView(.animation) { timeline in
                let phase = timeline.date.timeIntervalSinceReferenceDate
                MeshGradient(
                    width: 3, height: 3,
                    points: driftingPoints(phase: phase),
                    colors: palette.colors
                )
            }
        } else {
            MeshGradient(width: 3, height: 3, points: staticPoints, colors: palette.colors)
        }
    }

    /// Nine mesh control points; the four edge-midpoints and the centre drift
    /// on independent slow sine paths. Corners stay pinned for clean edges.
    @available(iOS 18.0, *)
    private func driftingPoints(phase: Double) -> [SIMD2<Float>] {
        func drift(_ period: Double, _ amp: Float, _ seed: Double) -> Float {
            Float(sin(phase / period + seed)) * amp
        }
        let tMid = SIMD2<Float>(0.5 + drift(7.3, 0.10, 0), drift(9.1, 0.05, 1.2))
        let lMid = SIMD2<Float>(drift(8.7, 0.04, 2.0), 0.5 + drift(6.5, 0.11, 0.4))
        let rMid = SIMD2<Float>(1 + drift(8.1, 0.04, 3.1), 0.5 + drift(7.7, 0.10, 2.6))
        let bMid = SIMD2<Float>(0.5 + drift(9.5, 0.09, 1.8), 1 + drift(6.9, 0.05, 0.9))
        let centre = SIMD2<Float>(0.5 + drift(11.0, 0.08, 0.6), 0.5 + drift(10.3, 0.08, 3.4))
        return [
            SIMD2(0, 0),  tMid,    SIMD2(1, 0),
            lMid,         centre,  rMid,
            SIMD2(0, 1),  bMid,    SIMD2(1, 1)
        ]
    }

    @available(iOS 18.0, *)
    private var staticPoints: [SIMD2<Float>] {
        [
            SIMD2(0, 0),   SIMD2(0.5, 0),   SIMD2(1, 0),
            SIMD2(0, 0.5), SIMD2(0.5, 0.5), SIMD2(1, 0.5),
            SIMD2(0, 1),   SIMD2(0.5, 1),   SIMD2(1, 1)
        ]
    }

    // MARK: - iOS 17 Fallback

    @ViewBuilder
    private var fallbackLayer: some View {
        let cols = palette.colors
        ZStack {
            LinearGradient(
                colors: [cols[0], cols[4], cols[8]],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [cols[2].opacity(0.6), .clear],
                center: UnitPoint(x: 0.85, y: 0.15),
                startRadius: 50,
                endRadius: 320
            )
            RadialGradient(
                colors: [cols[6].opacity(0.5), .clear],
                center: UnitPoint(x: 0.1, y: 0.85),
                startRadius: 40,
                endRadius: 280
            )
        }
    }
}

// MARK: - Preview

#Preview("HSMeshGradientBackground") {
    VStack(spacing: 0) {
        HSMeshGradientBackground(palette: .kidWarm)
            .frame(height: 200)
        HSMeshGradientBackground(palette: .kidCool)
            .frame(height: 200)
        HSMeshGradientBackground(palette: .rewards)
            .frame(height: 200)
        HSMeshGradientBackground(palette: .calm)
            .frame(height: 200)
    }
}
