import SwiftUI

// MARK: - HSPressableStyle
//
// v29 Phase 7 — shared interactive press feedback for every tappable
// surface. On press the content scales down slightly, its depth shadow
// collapses toward the surface, and a light haptic fires. All motion is
// gated behind Reduce Motion; the haptic is gated behind the haptic
// service intensity setting.

/// Shared `ButtonStyle` giving tappable surfaces a tactile press response:
/// scale-down, shadow collapse and a light haptic.
///
/// ## Usage
/// ```swift
/// Button { interactor.openLesson() } label: {
///     LessonTile(lesson)
/// }
/// .buttonStyle(HSPressableStyle())
/// ```
public struct HSPressableStyle: ButtonStyle {

    /// Scale applied while pressed.
    private let pressedScale: CGFloat
    /// Haptic pattern fired on press, or `nil` to stay silent.
    private let haptic: HapticPattern?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.hapticService) private var hapticService

    public init(
        pressedScale: CGFloat = 0.96,
        haptic: HapticPattern? = .buttonTap
    ) {
        self.pressedScale = pressedScale
        self.haptic = haptic
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(scale(for: configuration.isPressed))
            .brightness(configuration.isPressed ? -0.02 : 0)
            .animation(
                MotionTokens.pressSpring(reduceMotion: reduceMotion),
                value: configuration.isPressed
            )
            .onChange(of: configuration.isPressed) { _, isPressed in
                guard isPressed, let haptic else { return }
                let service = hapticService
                Task { await service.play(pattern: haptic) }
            }
    }

    private func scale(for isPressed: Bool) -> CGFloat {
        guard isPressed, !reduceMotion else { return 1.0 }
        return pressedScale
    }
}

// MARK: - Convenience

public extension ButtonStyle where Self == HSPressableStyle {

    /// Standard pressable feedback — 0.96 scale + light haptic.
    static var hsPressable: HSPressableStyle { HSPressableStyle() }

    /// Pressable feedback for content cards — softer scale, card-select haptic.
    static var hsPressableCard: HSPressableStyle {
        HSPressableStyle(pressedScale: 0.97, haptic: .cardSelect)
    }

    /// Pressable feedback without haptic — for surfaces that play their own.
    static var hsPressableSilent: HSPressableStyle {
        HSPressableStyle(haptic: nil)
    }
}

// MARK: - Tappable card modifier
//
// For non-Button tappable surfaces, `.hsPressFeedback(isPressed:)` applies
// the same scale + shadow-collapse vocabulary driven by an external
// `isPressed` flag (e.g. from a `DragGesture(minimumDistance: 0)`).

public extension View {

    /// Applies the shared press scale to a non-Button surface.
    func hsPressFeedback(isPressed: Bool, reduceMotion: Bool) -> some View {
        scaleEffect((isPressed && !reduceMotion) ? 0.97 : 1.0)
            .animation(
                MotionTokens.pressSpring(reduceMotion: reduceMotion),
                value: isPressed
            )
    }
}

// MARK: - Preview

#Preview("HSPressableStyle") {
    VStack(spacing: SpacingTokens.large) {
        Button {} label: {
            HSCard {
                Text("Нажми меня")
                    .font(TypographyTokens.headline())
            }
        }
        .buttonStyle(.hsPressableCard)

        Button {} label: {
            RoundedRectangle(cornerRadius: RadiusTokens.button, style: .continuous)
                .fill(ColorTokens.Brand.primary)
                .frame(height: 56)
                .overlay(
                    Text("Кнопка")
                        .font(TypographyTokens.cta())
                        .foregroundStyle(.white)
                )
        }
        .buttonStyle(.hsPressable)
    }
    .padding()
    .background(ColorTokens.Kid.bg)
    .environment(\.circuitContext, .kid)
}
