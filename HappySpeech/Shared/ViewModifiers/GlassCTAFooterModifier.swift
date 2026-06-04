import SwiftUI

// MARK: - GlassCTAFooterModifier (P0.5 v32)
//
// Оборачивает произвольный контент CTA в стеклянный фут-пилл,
// прикреплённый к safeAreaInset(.bottom). Стандартизует паттерн
// «game screen CTA footer» из design-modernisation plan P0.5.
//
// Usage:
// ```swift
// ScrollView { ... }
//     .glassCTAFooter {
//         HSButton("Начать", style: .primary, size: .large) { start() }
//     }
// ```

public struct GlassCTAFooterModifier<CTA: View>: ViewModifier {

    private let cta: () -> CTA

    public init(@ViewBuilder cta: @escaping () -> CTA) {
        self.cta = cta
    }

    public func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                HSLiquidGlassCard(style: .primary, padding: SpacingTokens.regular) {
                    cta()
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.tiny)
            }
    }
}

// MARK: - View Extension

public extension View {
    /// Добавляет стеклянный glass-футер с CTA кнопкой к ScrollView / ZStack экрана.
    ///
    /// Реализует паттерн P0.5 из design-modernisation plan v32:
    /// `HSLiquidGlassCard(.primary)` в `safeAreaInset(.bottom)`.
    ///
    /// - Parameter cta: CTA-контент (обычно `HSButton(.primary, size: .large)`).
    func glassCTAFooter<CTA: View>(@ViewBuilder cta: @escaping () -> CTA) -> some View {
        modifier(GlassCTAFooterModifier(cta: cta))
    }
}
