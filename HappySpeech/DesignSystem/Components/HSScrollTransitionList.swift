import SwiftUI

// MARK: - HSScrollTransitionList
//
// Block O v16 (бонусный компонент) — обёртка над `.scrollTransition` (iOS 17+).
//
// Готовые scroll-эффекты для списков и галерей. Каждый элемент при выходе
// из viewport анимируется по выбранному пресету:
// - `.fade` — opacity-фейд
// - `.scaleFade` — scale + opacity
// - `.parallax` — offset Y по фазе скролла
// - `.tiltCarousel` — rotation + scale (App Store-style)
//
// Usage:
// ```swift
// ScrollView {
//     LazyVStack {
//         ForEach(items) { item in
//             ItemCard(item)
//                 .hsScrollEffect(.scaleFade)
//         }
//     }
// }
// ```
//
// References:
// - Apple WWDC23 — Beyond scroll views
// - AppCoda — ScrollView Transition iOS 17

@available(iOS 17.0, *)
public enum HSScrollEffectStyle {
    /// Простой fade-out при выходе элемента из видимой области.
    case fade
    /// Scale + fade — карточка «отходит» при скролле.
    case scaleFade
    /// Параллакс — элемент смещается по Y относительно фазы.
    case parallax
    /// Tilt carousel — App Store style.
    case tiltCarousel
}

@available(iOS 17.0, *)
public extension View {
    /// Применяет один из готовых scroll-эффектов к view внутри ScrollView.
    @ViewBuilder
    func hsScrollEffect(_ style: HSScrollEffectStyle) -> some View {
        modifier(HSScrollEffectModifier(style: style))
    }
}

@available(iOS 17.0, *)
private struct HSScrollEffectModifier: ViewModifier {
    let style: HSScrollEffectStyle

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            switch style {
            case .fade:
                content.scrollTransition(.interactive) { effect, phase in
                    effect.opacity(1.0 - abs(phase.value) * 0.6)
                }
            case .scaleFade:
                content.scrollTransition(.interactive) { effect, phase in
                    effect
                        .scaleEffect(1.0 - abs(phase.value) * 0.15)
                        .opacity(1.0 - abs(phase.value) * 0.5)
                        // Off-screen tiles slightly de-saturate so the focused
                        // content reads as the brightest layer (research #5).
                        .saturation(1.0 - abs(phase.value) * (1.0 - MotionTokens.Scroll.saturationLow))
                }
            case .parallax:
                content.scrollTransition(.interactive) { effect, phase in
                    effect.offset(y: phase.value * 24)
                }
            case .tiltCarousel:
                content.scrollTransition(.interactive) { effect, phase in
                    effect
                        .scaleEffect(0.85 + (1.0 - abs(phase.value)) * 0.15)
                        .rotation3DEffect(
                            .degrees(phase.value * -8),
                            axis: (x: 0, y: 1, z: 0),
                            perspective: 0.4
                        )
                        .opacity(1.0 - abs(phase.value) * 0.3)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("HSScrollTransitionList") {
    ScrollView {
        VStack(spacing: SpacingTokens.regular) {
            ForEach(0..<20, id: \.self) { idx in
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(ColorTokens.Brand.primary.opacity(0.6))
                    .frame(height: 120)
                    .overlay(
                        Text("Карточка \(idx)")
                            .font(TypographyTokens.headline())
                            .foregroundStyle(.white)
                    )
                    .hsScrollEffect(.tiltCarousel)
            }
        }
        .padding()
    }
    .background(ColorTokens.Kid.bg)
}
