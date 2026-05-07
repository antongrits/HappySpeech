import Foundation

// MARK: - GuidedTourModels (VIP Use-Cases)
//
// Block I v16 — VIP Use-Case structs (Request/Response/ViewModel).
// Каждый use-case — отдельный namespace внутри `GuidedTourModels`.
//
// Use-cases:
//   1. LoadTour       — старт тура (с проверкой gating + persistence)
//   2. NextStep       — переход к следующему шагу
//   3. PreviousStep   — возврат к предыдущему шагу (для accessibility / debug)
//   4. SkipTour       — пропуск тура (analytics: tour_skipped)
//   5. CompleteTour   — финал тура (persist completed flag)
//   6. ResetTour      — сброс persistence (для QA / Settings re-trigger)
//   7. AutoAdvance    — таймерный auto-advance (internal)

enum GuidedTourModels {

    // MARK: - LoadTour

    enum LoadTour {

        struct Request {
            /// Принудительно стартовать (Settings → "Снова показать тур"),
            /// игнорируя `hasCompleted` и gating-правила.
            let force: Bool
            /// childId — для gating: показывать только если ребёнок прошёл ≥N сессий.
            /// `nil` → пропустить gating-check (для onboarding-сценария).
            let childId: String?

            init(force: Bool = false, childId: String? = nil) {
                self.force = force
                self.childId = childId
            }
        }

        struct Response {
            let kind: Kind
            let steps: [TourStep]
            let initialIndex: Int

            enum Kind: Sendable {
                /// Тур стартовал — показать первый шаг.
                case started
                /// Тур уже был пройден ранее, force=false → не запускаем.
                case alreadyCompleted
                /// Gating: ребёнок ещё не прошёл минимум сессий — отложить.
                case gatedBySessionCount(required: Int, current: Int)
            }
        }

        struct ViewModel {
            let isVisible: Bool
            let currentStep: TourStep?
            let stepNumber: Int
            let totalSteps: Int
            let progressFraction: Double
            let isLastStep: Bool
        }
    }

    // MARK: - NextStep

    enum NextStep {

        struct Request {}

        struct Response {
            let kind: Kind
            let steps: [TourStep]
            let newIndex: Int?

            enum Kind: Sendable {
                /// Переход на следующий шаг.
                case advanced
                /// Был последний шаг — тур завершён.
                case completed
                /// Тур не был активен — no-op.
                case noop
            }
        }

        struct ViewModel {
            let isVisible: Bool
            let currentStep: TourStep?
            let stepNumber: Int
            let totalSteps: Int
            let progressFraction: Double
            let isLastStep: Bool
        }
    }

    // MARK: - PreviousStep

    enum PreviousStep {

        struct Request {}

        struct Response {
            let kind: Kind
            let steps: [TourStep]
            let newIndex: Int?

            enum Kind: Sendable {
                /// Возврат на предыдущий шаг.
                case retreated
                /// Уже на первом шаге — некуда возвращаться.
                case atFirstStep
                /// Тур не активен.
                case noop
            }
        }

        struct ViewModel {
            let isVisible: Bool
            let currentStep: TourStep?
            let stepNumber: Int
            let totalSteps: Int
            let progressFraction: Double
            let isLastStep: Bool
        }
    }

    // MARK: - SkipTour

    enum SkipTour {

        struct Request {}

        struct Response {
            /// Индекс шага, на котором пользователь нажал "Пропустить".
            let skippedAtIndex: Int
            /// Общее число шагов тура (для analytics).
            let totalSteps: Int
        }

        struct ViewModel {
            let isVisible: Bool
        }
    }

    // MARK: - CompleteTour

    enum CompleteTour {

        struct Request {}

        struct Response {
            /// Прошёл ли пользователь все шаги (true) или вышел до последнего (false).
            let reachedFinalStep: Bool
        }

        struct ViewModel {
            let isVisible: Bool
        }
    }

    // MARK: - ResetTour (QA + Settings re-trigger)

    enum ResetTour {

        struct Request {}

        struct Response {}

        struct ViewModel {
            let isVisible: Bool
        }
    }

    // MARK: - AutoAdvance (internal — driven by timer)

    enum AutoAdvance {

        struct Request {
            /// Индекс шага, для которого был запланирован таймер.
            /// Защита от race-condition: если пользователь уже нажал next вручную,
            /// indexAtSchedule != currentIndex → no-op.
            let scheduledForIndex: Int
        }

        struct Response {
            let kind: Kind
            let steps: [TourStep]
            let newIndex: Int?

            enum Kind: Sendable {
                case advanced
                case completed
                case stale       // index изменился — no-op
            }
        }

        struct ViewModel {
            let isVisible: Bool
            let currentStep: TourStep?
            let stepNumber: Int
            let totalSteps: Int
            let progressFraction: Double
            let isLastStep: Bool
        }
    }
}

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

// MARK: - TourFlavor

/// Поддержка multi-tour management — сейчас активен только `.onboarding`,
/// остальные зарезервированы под расширение (план M.x post-v1.0).
enum TourFlavor: String, Sendable, CaseIterable {
    case onboarding   // 11-шаговый базовый тур (kid circuit)
    case settings     // мини-тур по экрану настроек
    case lesson       // мини-тур по плееру урока
}

// MARK: - TourSteps

/// Canonical 11-step onboarding tour of the HappySpeech kid circuit.
/// Strings are resolved from the String Catalog via `String(localized:)`.
enum TourSteps {

    static var all: [TourStep] {
        steps(for: .onboarding)
    }

    static func steps(for flavor: TourFlavor) -> [TourStep] {
        switch flavor {
        case .onboarding:
            return onboardingSteps
        case .settings, .lesson:
            // Зарезервировано под post-v1.0; пока возвращаем onboarding-список
            // чтобы не ломать flow при экспериментах.
            return onboardingSteps
        }
    }

    private static var onboardingSteps: [TourStep] {
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
            )
        ]
    }
}
