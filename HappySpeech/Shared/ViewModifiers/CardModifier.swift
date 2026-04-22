import SwiftUI

// MARK: - HSCardModifier

public struct HSCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    var shadowTokens: Bool
    var circuit: CircuitContext

    public func body(content: Content) -> some View {
        let shadow: ShadowTokens.ShadowStyle = circuit == .kid
            ? ShadowTokens.Kid.card
            : ShadowTokens.Parent.card
        return content
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(
                color: shadowTokens ? shadow.color.opacity(shadow.opacity) : .clear,
                radius: shadowTokens ? shadow.radius : 0,
                x: shadowTokens ? shadow.x : 0,
                y: shadowTokens ? shadow.y : 0
            )
    }
}

public extension View {
    func hsCard(cornerRadius: CGFloat = RadiusTokens.md, shadow: Bool = true, circuit: CircuitContext = .kid) -> some View {
        modifier(HSCardModifier(cornerRadius: cornerRadius, shadowTokens: shadow, circuit: circuit))
    }
}

// MARK: - PressEffect Modifier

public struct PressEffectModifier: ViewModifier {
    @State private var isPressed = false

    public func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(MotionTokens.spring, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

public extension View {
    func pressEffect() -> some View {
        modifier(PressEffectModifier())
    }
}

// MARK: - ShakeEffect Modifier (error feedback)

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 8
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: amount * sin(animatableData * .pi * shakesPerUnit),
            y: 0
        ))
    }
}

public extension View {
    func shake(trigger: Bool) -> some View {
        modifier(AnimatedShakeModifier(trigger: trigger))
    }
}

private struct AnimatedShakeModifier: ViewModifier {
    var trigger: Bool
    @State private var shakeValue: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .modifier(ShakeEffect(animatableData: shakeValue))
            .onChange(of: trigger) { _, newVal in
                if newVal {
                    withAnimation(.default.repeatCount(3, autoreverses: true).speed(6)) {
                        shakeValue = 1
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        shakeValue = 0
                    }
                }
            }
    }
}
