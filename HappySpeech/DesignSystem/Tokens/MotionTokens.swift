import SwiftUI

// MARK: - MotionTokens
// Translated from tokens.jsx ease: { outQuick, spring, bounce }
// Expanded in v29 Phase 7 — semantic, Apple-aligned spring vocabulary.

public enum MotionTokens {

    // MARK: - Durations

    public enum Duration {
        public static let instant: Double = 0.10
        public static let quick: Double = 0.20
        public static let standard: Double = 0.30
        public static let moderate: Double = 0.45
        public static let slow: Double = 0.60
        public static let pageTransition: Double = 0.35
    }

    // MARK: - SwiftUI Animations (legacy — kept for compatibility)

    /// Fast deceleration — UI feedback, micro-interactions.
    public static let outQuick = Animation.timingCurve(0.16, 1, 0.3, 1, duration: Duration.quick)

    /// Spring with slight overshoot — cards, tiles appearing.
    public static let spring = Animation.spring(response: 0.45, dampingFraction: 0.7)

    /// Bouncy — rewards, stickers, celebrations.
    public static let bounce = Animation.spring(response: 0.4, dampingFraction: 0.55)

    /// Smooth ease-out for page-level transitions.
    public static let page = Animation.easeOut(duration: Duration.pageTransition)

    /// Hero transition for game templates.
    public static let hero = Animation.spring(response: 0.5, dampingFraction: 0.8)

    /// Subtle pulse for idle mascot.
    public static let idlePulse = Animation.easeInOut(duration: 1.8).repeatForever(autoreverses: true)

    // MARK: - Semantic Springs (v29 — Apple-aligned)
    //
    // Guidance: `response` 0.25–0.35 for finger-touched elements,
    // 0.45–0.6 for screen transitions. Higher bounce only for rewards /
    // kid circuit, never parent/specialist UI.

    /// Press feedback on tappable surfaces — tight, controlled, no overshoot.
    public static let pressSpring = Animation.spring(response: 0.30, dampingFraction: 0.78)

    /// Release / settle after press — gentle bounce as element returns to rest.
    public static let settleSpring = Animation.spring(response: 0.32, dampingFraction: 0.72)

    /// Snappy — quick state changes, toggles, selection.
    public static let snappy = Animation.snappy(duration: 0.25)

    /// Smooth — content reflow, scroll-driven effects, list updates.
    public static let smooth = Animation.smooth(duration: 0.35)

    /// Playful — kid-circuit only; bouncy entrance for tiles and stickers.
    public static let playful = Animation.bouncy(duration: 0.5, extraBounce: 0.15)

    /// Presentation — sheets, full-screen covers, hero transitions.
    public static let presentation = Animation.spring(response: 0.55, dampingFraction: 0.82)

    /// Reward pop — rewards and celebrations; pronounced overshoot.
    public static let rewardPop = Animation.spring(response: 0.40, dampingFraction: 0.50)

    // MARK: - Scroll-driven entrance

    public enum Scroll {
        /// Scale of a tile as it enters the viewport.
        public static let enterScale: CGFloat = 0.92
        /// Opacity of a tile fully outside the viewport.
        public static let enterOpacity: Double = 0.0
        /// Reduced saturation for off-screen tiles.
        public static let saturationLow: Double = 0.85
    }

    // MARK: - Mascot micro-interactions

    public enum Mascot {
        /// Idle breathe loop length.
        public static let breatheDuration: Double = 2.4
        /// Average interval between idle blinks.
        public static let blinkInterval: Double = 4.0
        /// Celebration spring — pronounced bounce.
        public static let celebrateSpring = Animation.spring(response: 0.45, dampingFraction: 0.55)
    }

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

    /// Press feedback animation, toned down under Reduce Motion.
    public static func pressSpring(reduceMotion: Bool) -> Animation? {
        reduceMotion ? .easeOut(duration: 0.12) : pressSpring
    }

    /// Reward animation, toned down under Reduce Motion (keep haptic + sound).
    public static func reward(reduceMotion: Bool) -> Animation? {
        reduceMotion ? .easeOut(duration: 0.2) : rewardPop
    }

    /// Scroll-driven transition animation, opacity-only under Reduce Motion.
    public static func scrollTransition(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.2) : smooth
    }

    /// Presentation animation, toned down under Reduce Motion.
    public static func presentation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? .easeOut(duration: 0.2) : presentation
    }
}
