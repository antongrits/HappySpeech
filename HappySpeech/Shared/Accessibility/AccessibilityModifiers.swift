import SwiftUI

// MARK: - Accessibility View Modifiers

public extension View {

    /// Adds a localized accessibility label and hint.
    func accessibilityElement(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
    }

    /// Marks interactive elements for VoiceOver with a combined label/value.
    func accessibilityInteractive(label: String, value: String) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityValue(value)
    }

    /// Applies reduced-motion animation guard.
    /// If accessibility reduce motion is enabled, returns identity instead of the animation.
    @ViewBuilder
    func reducedMotionAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        self.animation(animation, value: value)
    }
}

// MARK: - ReducedMotion Environment

struct ReducedMotionKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

public extension EnvironmentValues {
    var isReducedMotion: Bool {
        get { self[ReducedMotionKey.self] }
        set { self[ReducedMotionKey.self] = newValue }
    }
}

// MARK: - DynamicTypeSize Helper

public extension View {
    /// Limits Dynamic Type to a safe range for child-facing screens.
    func limitedDynamicType() -> some View {
        self.dynamicTypeSize(.small ... .accessibility2)
    }
}
