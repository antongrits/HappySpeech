import Foundation

// MARK: - SessionShell VIP Models
//
// SessionShell оборачивает игровую сессию HUD'ом, FeedbackOverlay, PauseSheet и
// прокидывает фазы (loading / playing / paused / fatigue / completed) во View.
//
// VIP-стек:
//   View → Interactor.startSession()      → Presenter.presentStartSession() → ViewModel
//   View → Interactor.completeActivity()  → Presenter.presentCompleteActivity()
//   View → Interactor.pauseSession()      → Presenter.presentPauseSession()
//
// Фичи под капотом:
//   • прогрессбар (0…1) — Float по индексу активности;
//   • таймер mm:ss — TimelineView во View, синхронизация startTime от Interactor;
//   • 3 сердечка усталости — каждые 3 подряд неправильных ответа списываем 1;
//   • Pause sheet — мотивационная фраза от Ляли + 2 действия;
//   • Feedback overlay — зелёный flash / красная рамка + shake (auto-dismiss 0.8s);
//   • Reduced Motion — все анимации в Binder уважают environment.

enum SessionShellModels {

    // MARK: - StartSession

    enum StartSession {
        struct Request {
            let childId: String
            let targetSoundId: String
            let sessionType: SessionType
            /// Когда задано — Interactor создаёт сессию из одного шаблона
            /// (используется при deep link / debug-routes lessonPlayer(templateType:)).
            /// При nil — обычный adaptive / default подбор шаблонов.
            let forcedGameType: GameType?

            init(
                childId: String,
                targetSoundId: String,
                sessionType: SessionType,
                forcedGameType: GameType? = nil
            ) {
                self.childId = childId
                self.targetSoundId = targetSoundId
                self.sessionType = sessionType
                self.forcedGameType = forcedGameType
            }
        }
        struct Response {
            let activities: [SessionActivity]
            let totalSteps: Int
            let estimatedMinutes: Int
            let sessionStartTime: Date
        }
        struct ViewModel {
            let activities: [SessionActivity]
            let totalSteps: Int
            let progressTitle: String
            let sessionStartTime: Date
        }
    }

    // MARK: - CompleteActivity

    enum CompleteActivity {
        struct Request {
            let activityId: String
            let score: Float
            let durationSeconds: Int
            let errorCount: Int
        }
        struct Response {
            let nextActivity: SessionActivity?
            let isSessionComplete: Bool
            let earnedReward: SessionReward?
            let fatigueDetected: Bool
            /// Кол-во оставшихся «сердечек усталости» (0…3). Каждые 3 подряд
            /// ошибочных ответа списывают одно сердце.
            let fatigueHearts: Int
            /// `correct` если score >= 0.5, иначе `incorrect`. Управляет
            /// FeedbackOverlay (flash / shake).
            let feedback: ActivityFeedback
        }
        struct ViewModel {
            let shouldAdvance: Bool
            let shouldShowFatigueAlert: Bool
            let shouldShowReward: Bool
            let reward: RewardViewModel?
            let feedbackState: FeedbackState
            let fatigueHearts: Int
            let mascotState: MascotState
        }
    }

    // MARK: - PauseSession

    enum PauseSession {
        struct Request {}
        struct Response {
            let currentProgress: Float
            let activeSeconds: TimeInterval
        }
        struct ViewModel {
            let progressPercentage: Float
            let timeSpentFormatted: String
            let motivationalPhrase: String
        }
    }

    // MARK: - Feedback states

    /// State of the feedback overlay rendered above the game content.
    enum FeedbackState: Equatable, Sendable {
        case none
        case correct
        case incorrect
    }

    /// Domain-level result of a single activity. Maps 1:1 onto `FeedbackState`
    /// inside the Presenter.
    enum ActivityFeedback: Sendable, Equatable {
        case correct
        case incorrect
    }

    /// Lyalya mood requested by the Presenter for the current shell state.
    /// View picks the matching `MascotMood` via `mascotMood(for:)`.
    enum MascotState: Sendable, Equatable {
        case idle
        case encouraging
        case celebrating
        case thinking
        case explaining
        case waving
    }
}

// MARK: - Domain

struct SessionActivity: Identifiable, Sendable, Equatable {
    let id: String
    let gameType: GameType
    let lessonId: String
    let soundTarget: String
    let difficulty: Int
    var isCompleted: Bool
    var score: Float?
}

/// Все 17 шаблонов игр, поддерживаемых проектом. Дублирование с
/// `TemplateType` (контент-слой) — намеренно: фиче-слой и контент-слой
/// разделены через мост `SessionShellInteractor.gameType(from:)`.
enum GameType: String, Sendable, CaseIterable {
    case listenAndChoose        = "ListenAndChoose"
    case repeatAfterModel       = "RepeatAfterModel"
    case minimalPairs           = "MinimalPairs"
    case dragAndMatch           = "DragAndMatch"
    case memory                 = "Memory"
    case bingo                  = "Bingo"
    case breathing              = "Breathing"
    case rhythm                 = "Rhythm"
    case sorting                = "Sorting"
    case puzzleReveal           = "PuzzleReveal"
    case soundHunter            = "SoundHunter"
    case narrativeQuest         = "NarrativeQuest"
    case visualAcoustic         = "VisualAcoustic"
    case storyCompletion        = "StoryCompletion"
    case articulationImitation  = "ArticulationImitation"
    case arActivity             = "ARActivity"
    /// Block K (v12): 17-й шаблон — поиск предметов через Vision + VNClassifyImageRequest.
    case objectHunt             = "ObjectHunt"
    /// Block Q (v12): 18-й шаблон — написание буквы PencilKit + Vision handwriting recognition.
    case letterTracing          = "LetterTracing"

    /// Маппинг kebab-case route-строк → GameType для deep links / debug-routes.
    /// Возвращает nil если строка пустая или не распознана (тогда вызывается
    /// обычный adaptive подбор).
    static func fromTemplateRoute(_ raw: String) -> GameType? {
        switch raw.lowercased() {
        case "":                            return nil
        case "listen-and-choose":           return .listenAndChoose
        case "repeat-after-model":          return .repeatAfterModel
        case "minimal-pairs":               return .minimalPairs
        case "drag-and-match":              return .dragAndMatch
        case "memory":                      return .memory
        case "bingo":                       return .bingo
        case "breathing":                   return .breathing
        case "rhythm":                      return .rhythm
        case "sorting":                     return .sorting
        case "puzzle-reveal":               return .puzzleReveal
        case "sound-hunter":                return .soundHunter
        case "narrative-quest":             return .narrativeQuest
        case "visual-acoustic":             return .visualAcoustic
        case "story-completion":            return .storyCompletion
        case "articulation-imitation":     return .articulationImitation
        case "ar-activity":                 return .arActivity
        case "object-hunt":                 return .objectHunt
        case "letter-tracing":              return .letterTracing
        default:                            return nil
        }
    }
}

enum SessionType: String, Sendable {
    case adaptive
    case quickPractice
    case screening
    case homeworkTask
}

struct SessionReward: Sendable, Equatable {
    let kind: Kind
    enum Kind: String, Sendable { case star, badge, sticker }
    static let star = SessionReward(kind: .star)
}

struct RewardViewModel: Sendable, Equatable {
    let emoji: String
    let title: String
    let subtitle: String
}
