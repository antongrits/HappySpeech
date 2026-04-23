import Foundation

// MARK: - TourStep

/// Single step of the interactive guided tour (coach marks + spotlight).
/// A step highlights a UI element (keyed via `highlightKey`) and shows a
/// coach mark bubble with a title/body. Optional Lyalya phrase plays in sync.
struct TourStep: Identifiable, Sendable, Hashable {

    let id: String

    /// Localized title shown inside the coach mark bubble.
    let title: String

    /// Localized body copy.
    let body: String

    /// Registry key of the UI element to spotlight. The element must call
    /// `.spotlightAnchor(key:)` so its global frame gets published through
    /// the `SpotlightKey` preference key.
    let highlightKey: String

    /// Optional Lyalya audio asset name (from Resources/Audio). When set, the
    /// tour coordinator triggers TTS / audio playback on step enter.
    let lyalyaPhrase: String?

    /// If set, the step advances automatically after the given delay.
    /// When `nil`, the tour waits for the user to tap "Next".
    let autoAdvanceAfter: TimeInterval?

    /// Whether the "Skip" affordance is available on this step.
    let allowSkip: Bool
}

// MARK: - TourSteps

/// Canonical 11-step onboarding tour of the HappySpeech kid circuit.
/// Strings are resolved from the String Catalog via `String(localized:)`.
enum TourSteps {

    static var all: [TourStep] {
        [
            TourStep(
                id: "welcome",
                title: String(localized: "tour.welcome.title"),
                body: String(localized: "tour.welcome.body"),
                highlightKey: "mascot_header",
                lyalyaPhrase: "greeting_01",
                autoAdvanceAfter: 3.0,
                allowSkip: true
            ),
            TourStep(
                id: "child_home",
                title: String(localized: "tour.child_home.title"),
                body: String(localized: "tour.child_home.body"),
                highlightKey: "daily_mission_card",
                lyalyaPhrase: nil,
                autoAdvanceAfter: nil,
                allowSkip: true
            ),
            TourStep(
                id: "streak",
                title: String(localized: "tour.streak.title"),
                body: String(localized: "tour.streak.body"),
                highlightKey: "streak_banner",
                lyalyaPhrase: nil,
                autoAdvanceAfter: nil,
                allowSkip: true
            ),
            TourStep(
                id: "start_lesson",
                title: String(localized: "tour.start_lesson.title"),
                body: String(localized: "tour.start_lesson.body"),
                highlightKey: "start_lesson_button",
                lyalyaPhrase: nil,
                autoAdvanceAfter: nil,
                allowSkip: true
            ),
            TourStep(
                id: "listen_game",
                title: String(localized: "tour.listen_game.title"),
                body: String(localized: "tour.listen_game.body"),
                highlightKey: "listen_game_area",
                lyalyaPhrase: "instruction_08",
                autoAdvanceAfter: 4.0,
                allowSkip: true
            ),
            TourStep(
                id: "record",
                title: String(localized: "tour.record.title"),
                body: String(localized: "tour.record.body"),
                highlightKey: "record_button",
                lyalyaPhrase: "instruction_04",
                autoAdvanceAfter: nil,
                allowSkip: true
            ),
            TourStep(
                id: "reward",
                title: String(localized: "tour.reward.title"),
                body: String(localized: "tour.reward.body"),
                highlightKey: "reward_area",
                lyalyaPhrase: "encouragement_01",
                autoAdvanceAfter: 3.0,
                allowSkip: true
            ),
            TourStep(
                id: "ar_zone",
                title: String(localized: "tour.ar_zone.title"),
                body: String(localized: "tour.ar_zone.body"),
                highlightKey: "ar_zone_tab",
                lyalyaPhrase: nil,
                autoAdvanceAfter: nil,
                allowSkip: true
            ),
            TourStep(
                id: "parent_home",
                title: String(localized: "tour.parent_home.title"),
                body: String(localized: "tour.parent_home.body"),
                highlightKey: "parent_dashboard",
                lyalyaPhrase: nil,
                autoAdvanceAfter: nil,
                allowSkip: true
            ),
            TourStep(
                id: "settings",
                title: String(localized: "tour.settings.title"),
                body: String(localized: "tour.settings.body"),
                highlightKey: "settings_tab",
                lyalyaPhrase: nil,
                autoAdvanceAfter: nil,
                allowSkip: true
            ),
            TourStep(
                id: "done",
                title: String(localized: "tour.done.title"),
                body: String(localized: "tour.done.body"),
                highlightKey: "mascot_header",
                lyalyaPhrase: "session_end_01",
                autoAdvanceAfter: 3.0,
                allowSkip: false
            ),
        ]
    }
}
