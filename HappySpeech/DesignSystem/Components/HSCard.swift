import SwiftUI

// MARK: - HSCardStyle (standalone enum to avoid generic type constraints)

public enum HSCardStyle {
    case elevated   // card with shadow
    case flat       // no shadow, subtle border
    case tinted(Color)  // coloured background
    /// Warm gradient fill over the surface colour (v32 design-modernisation).
    /// Use one of the `GradientTokens.card*` presets.
    case gradientTinted(LinearGradient)
}

// MARK: - HSCard

/// Переиспользуемый контейнер-карточка. Адаптирует тень и поверхность к контексту контура.
///
/// `HSCard` — базовый строительный блок UI HappySpeech. Принимает любой SwiftUI `Content`
/// через `@ViewBuilder` и оборачивает его в скруглённый прямоугольник с правильным отступом,
/// тенью и цветом поверхности для текущего контура (kid / parent / specialist).
///
/// Три стиля через ``HSCardStyle``:
/// - `.elevated` — карточка с тенью (по умолчанию)
/// - `.flat` — без тени, с тонкой границей
/// - `.tinted(Color)` — тонированный фон с произвольным цветом
///
/// ## Пример
/// ```swift
/// HSCard(style: .elevated) {
///     VStack(alignment: .leading) {
///         Text("Сегодняшний урок").font(TypographyTokens.headline())
///         Text("Звук С — слоги").font(TypographyTokens.body())
///     }
/// }
///
/// HSCard(style: .tinted(ColorTokens.Brand.mint.opacity(0.15))) {
///     Text("Отличный результат!")
/// }
/// ```
///
/// ## See Also
/// - ``HSLiquidGlassCard``
/// - ``HSCardStyle``
/// - ``ColorTokens``
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
            .overlay(hairlineBorder)
            .applyShadow(for: circuit, style: style)
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .elevated:
            // В dark режиме тень почти не видна над тёмным фоном — лёгкий светлый
            // overlay создаёт ощущение материала и подъёма (см. v27-spec, тех. примечания).
            surfaceColor
                .overlay(colorScheme == .dark ? Color.white.opacity(0.04) : Color.clear)
        case .flat:
            surfaceColor
        case .tinted(let color):
            color
        case .gradientTinted(let gradient):
            // Surface colour base + warm gradient overlay (v32).
            // Gradients have low opacity (≤0.22) so they never overpower text.
            ZStack {
                surfaceColor
                    .overlay(colorScheme == .dark ? Color.white.opacity(0.04) : Color.clear)
                gradient
            }
        }
    }

    /// Тонкий hairline-бордер 0.5pt — даёт «приподнятость» карточки над фоном
    /// (сигнатура iOS 26 material style). В light режиме — полупрозрачный white,
    /// в dark — едва различимый светлый край.
    @ViewBuilder
    private var hairlineBorder: some View {
        switch style {
        case .elevated, .gradientTinted:
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .strokeBorder(hairlineColor, lineWidth: 0.5)
        case .flat, .tinted:
            EmptyView()
        }
    }

    private var hairlineColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color.white.opacity(0.7)
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
        case .elevated, .gradientTinted:
            // v29/v32 — raised cards (including gradient-tinted) use a two-layer
            // depth shadow so they read clearly above the opaque base layer.
            self.depthShadow(for: circuit)
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
        HSCard(style: .gradientTinted(GradientTokens.cardCoralButter)) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Градиентная карточка")
                    .font(TypographyTokens.kidCardTitle())
                Text("Тёплый коралл → butter")
                    .font(TypographyTokens.kidBody())
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
        }
        HSCard(style: .gradientTinted(GradientTokens.cardGold)) {
            Text("Стрик / достижения")
                .font(TypographyTokens.kidCardTitle())
        }
    }
    .padding()
    .background(ColorTokens.Kid.bg)
    .environment(\.circuitContext, .kid)
}
