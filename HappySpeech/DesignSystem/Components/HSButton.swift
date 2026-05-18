import SwiftUI

// MARK: - HSButton

/// Основная кнопка-CTA, используемая во всём приложении.
///
/// `HSButton` автоматически адаптируется к трём контурам (kid / parent / specialist)
/// через `@Environment(\.circuitContext)`. Поддерживает четыре стиля оформления,
/// три размера и состояние загрузки. При `isLoading = true` заменяет текст
/// на `ProgressView` и блокирует повторные нажатия.
///
/// Поддерживает `@Environment(\.accessibilityReduceMotion)` — нажатие без
/// анимации пружины, если пользователь включил Reduced Motion.
///
/// ## Пример
/// ```swift
/// HSButton("Начать урок", style: .primary, size: .large) {
///     interactor.startLesson()
/// }
///
/// HSButton("Удалить", style: .danger, size: .medium, icon: "trash") {
///     interactor.deleteProfile()
/// }
/// ```
///
/// ## See Also
/// - ``HSCard``
/// - ``ColorTokens``
/// - ``SpacingTokens``
public struct HSButton: View {

    public enum Style {
        case primary    // filled coral CTA
        case secondary  // outlined
        case ghost      // text only
        case danger     // red destructive action
    }

    public enum ButtonSize {
        case large      // full-width CTA
        case medium     // inline
        case small      // compact
    }

    private let title: String
    private let style: Style
    private let size: ButtonSize
    private let icon: String?
    private let isLoading: Bool
    private let action: () -> Void

    @Environment(\.circuitContext) private var circuit

    public init(
        _ title: String,
        style: Style = .primary,
        size: ButtonSize = .large,
        icon: String? = nil,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.size = size
        self.icon = icon
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: {
            if !isLoading { action() }
        }) {
            HStack(spacing: SpacingTokens.sp2) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(foregroundColor)
                        .scaleEffect(0.8)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: iconSize, weight: .semibold))
                    }
                    Text(title)
                        .font(TypographyTokens.cta())
                        .ctaTextStyle()
                }
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: size == .large ? .infinity : nil)
            .padding(.horizontal, horizontalPad)
            .frame(height: height)
            .background(backgroundShape)
            .overlay(borderShape)
            .opacity(isLoading ? 0.7 : 1.0)
        }
        // v29 — shared interactive press feedback (scale + light haptic).
        // Filled CTA keeps its accent-coloured shadow via the modifier below.
        .buttonStyle(HSCTAButtonStyle(shadowColor: ctaShadowColor))
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .disabled(isLoading)
    }

    // MARK: - Computed Properties

    private var height: CGFloat {
        switch size {
        case .large:  return 56
        case .medium: return 44
        case .small:  return 36
        }
    }

    private var horizontalPad: CGFloat {
        switch size {
        case .large:  return SpacingTokens.large
        case .medium: return SpacingTokens.regular
        case .small:  return SpacingTokens.small
        }
    }

    private var iconSize: CGFloat {
        switch size {
        case .large:  return 18
        case .medium: return 16
        case .small:  return 14
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:   return .white
        case .secondary: return accentColor
        case .ghost:     return accentColor
        case .danger:    return .white
        }
    }

    private var accentColor: Color {
        switch circuit {
        case .kid:        return ColorTokens.Brand.primary
        case .parent:     return ColorTokens.Parent.accent
        case .specialist: return ColorTokens.Spec.accent
        }
    }

    @ViewBuilder
    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: RadiusTokens.button, style: .continuous)
            .fill(backgroundColor)
    }

    @ViewBuilder
    private var borderShape: some View {
        if style == .secondary {
            RoundedRectangle(cornerRadius: RadiusTokens.button, style: .continuous)
                .strokeBorder(accentColor, lineWidth: 1.5)
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return accentColor
        case .secondary:
            return Color.clear
        case .ghost:
            return Color.clear
        case .danger:
            return ColorTokens.Semantic.error
        }
    }

    /// Цвет тени filled-CTA. Для secondary/ghost — прозрачная (нет фона → нет тени).
    private var ctaShadowColor: Color {
        switch style {
        case .primary:
            return accentColor.opacity(0.35)
        case .danger:
            return ColorTokens.Semantic.error.opacity(0.35)
        case .secondary, .ghost:
            return Color.clear
        }
    }
}

// MARK: - HSCTAButtonStyle
//
// Press feedback for the filled-CTA: shared scale + light haptic, plus an
// accent-coloured drop shadow that tightens on press so the button reads
// as a physically depressible control.

private struct HSCTAButtonStyle: ButtonStyle {

    let shadowColor: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.hapticService) private var hapticService

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            // D-21 v27 — насыщенная filled-CTA «выступает» мягкой тенью своего
            // акцентного цвета; на press тень собирается к поверхности.
            .shadow(
                color: shadowColor,
                radius: pressed ? 4 : 10,
                x: 0,
                y: pressed ? 2 : 5
            )
            .scaleEffect((pressed && !reduceMotion) ? 0.97 : 1.0)
            .animation(MotionTokens.pressSpring(reduceMotion: reduceMotion), value: pressed)
            .onChange(of: pressed) { _, isPressed in
                guard isPressed else { return }
                let service = hapticService
                Task { await service.play(pattern: .buttonTap) }
            }
    }
}

// MARK: - Preview

#Preview("HSButton States") {
    VStack(spacing: 16) {
        HSButton("Начать занятие", style: .primary, icon: "play.fill") {}
        HSButton("Настройки", style: .secondary) {}
        HSButton("Отмена", style: .ghost) {}
        HSButton("Удалить", style: .danger, icon: "trash") {}
        HSButton("Загрузка...", isLoading: true) {}
        HSButton("Компактная", size: .small) {}
    }
    .padding()
    .environment(\.circuitContext, .kid)
}
