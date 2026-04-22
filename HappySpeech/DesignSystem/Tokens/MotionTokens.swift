import SwiftUI

// MARK: - MotionTokens
// Translated from tokens.jsx ease: { outQuick, spring, bounce }

public enum MotionTokens {

    // MARK: - Durations

    public enum Duration {
        public static let instant:  Double = 0.10
        public static let quick:    Double = 0.20
        public static let standard: Double = 0.30
        public static let moderate: Double = 0.45
        public static let slow:     Double = 0.60
        public static let pageTransition: Double = 0.35
    }

    // MARK: - SwiftUI Animations

    /// Fast deceleration — UI feedback, micro-interactions.
    public static let outQuick  = Animation.timingCurve(0.16, 1, 0.3, 1, duration: Duration.quick)

    /// Spring with slight overshoot — cards, tiles appearing.
    public static let spring    = Animation.spring(response: 0.45, dampingFraction: 0.7)

    /// Bouncy — rewards, stickers, celebrations.
    public static let bounce    = Animation.spring(response: 0.4, dampingFraction: 0.55)

    /// Smooth ease-out for page-level transitions.
    public static let page      = Animation.easeOut(duration: Duration.pageTransition)

    /// Hero transition for game templates.
    public static let hero      = Animation.spring(response: 0.5, dampingFraction: 0.8)

    /// Subtle pulse for idle mascot.
    public static let idlePulse = Animation.easeInOut(duration: 1.8).repeatForever(autoreverses: true)

    // MARK: - Reduced Motion Fallbacks

    /// Returns standard animation or nil if reduceMotion is on.
    public static func spring(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : spring
    }

    public static func bounce(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : bounce
    }

    public static func page(reduceMotion: Bool) -> Animation? {
        reduceMotion ? .linear(duration: 0.15) : page
    }
}
