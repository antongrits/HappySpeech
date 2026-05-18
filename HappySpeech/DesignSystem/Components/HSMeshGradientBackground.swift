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

    @State private var t: CGFloat = 0

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
        .onAppear {
            guard animated, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                t = 1
            }
        }
    }

    // MARK: - iOS 18 Mesh

    @available(iOS 18.0, *)
    @ViewBuilder
    private var meshLayer: some View {
        let offset: Float = (animated && !reduceMotion) ? 0.18 : 0
        let tF = Float(t)
        let points: [SIMD2<Float>] = [
            SIMD2(0, 0),                       SIMD2(0.5, 0),                     SIMD2(1, 0),
            SIMD2(0, 0.5 - offset * tF),       SIMD2(0.5 + offset * tF, 0.5),     SIMD2(1, 0.5 + offset * tF),
            SIMD2(0, 1),                       SIMD2(0.5, 1),                     SIMD2(1, 1)
        ]
        MeshGradient(width: 3, height: 3, points: points, colors: palette.colors)
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
