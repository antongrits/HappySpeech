import Foundation

// MARK: - StutteringModels
//
// VIP envelope types for the Stuttering module root screen and all sub-modes.

enum StutteringModels {

    // MARK: - LoadScreen
    enum LoadScreen {
        struct Request {}
        struct Response {
            var cards: [ExerciseCardData]
            var hasSeenWelcome: Bool
        }
        struct ViewModel {
            var cards: [ExerciseCardViewModel]
            var showWelcomeSheet: Bool
        }
    }

    // MARK: - SelectMode
    enum SelectMode {
        struct Request {
            var mode: StutteringMode
        }
        struct Response {
            var mode: StutteringMode
        }
        struct ViewModel {
            var mode: StutteringMode
        }
    }

    // MARK: - LoadProgress
    enum LoadProgress {
        struct Request {}
        struct Response {
            var featureProgress: [StutteringMode: FeatureProgress]
            var totalSessions: Int
            var fluencyImprovementPct: Float
        }
        struct ViewModel {
            var featureRows: [FeatureProgressViewModel]
            var totalSessionsLabel: String
            var fluencyLabel: String
        }
    }

    // MARK: - LoadAdaptiveRecommendation
    enum LoadAdaptiveRecommendation {
        struct Request {}
        struct Response {
            var recommendedMode: StutteringMode
            var voicePromptText: String
            var shouldShowGlow: Bool
        }
        struct ViewModel {
            var recommendedMode: StutteringMode
            var voicePromptText: String
            var showGlowAnimation: Bool
        }
    }

    // MARK: - RecordSessionCompleted
    enum RecordSessionCompleted {
        struct Request {
            var mode: StutteringMode
            var fluencyScore: Float
        }
    }
}

// MARK: - StutteringMode

enum StutteringMode: String, CaseIterable, Sendable {
    case metronome
    case breathing
    case softOnset
    case diary
    case pacing
}

// MARK: - ExerciseCardData / ExerciseCardViewModel

struct ExerciseCardData: Sendable {
    var mode: StutteringMode
    var titleKey: String
    var subtitleKey: String
    var symbol: String
    var symbolColor: ExerciseSymbolColor
    var duration: String
}

enum ExerciseSymbolColor: Sendable {
    case primary, mint, butter, sky, rose, lilac, gold
}

struct ExerciseCardViewModel: Identifiable, Sendable {
    var id: StutteringMode { mode }
    var mode: StutteringMode
    var title: String
    var subtitle: String
    var symbol: String
    var symbolColor: ExerciseSymbolColor
    var duration: String
    var accessibilityLabel: String
    var isRecommended: Bool
    var completedToday: Bool
    var streak: Int
}

// MARK: - FeatureProgress / FeatureProgressViewModel

struct FeatureProgress: Sendable {
    var mode: StutteringMode
    var streak: Int
    var completedToday: Bool
}

struct FeatureProgressViewModel: Identifiable, Sendable {
    var id: StutteringMode { mode }
    var mode: StutteringMode
    var modeTitle: String
    var streakLabel: String
    var completedToday: Bool
    var streakAccessibilityLabel: String
}

// MARK: - InfoCardType

enum InfoCardType: Sendable {
    case whatIsStuttering
    case howAppHelps
    case techniques
}

// MARK: - MetronomeModels

enum MetronomeModels {
    enum StartSession {
        struct Request { var difficulty: StutteringDifficulty = .easy }
        struct Response { var word: String; var syllables: [String]; var bpm: Int }
        struct ViewModel { var word: String; var syllables: [SyllableViewModel]; var bpm: Int; var progressLabel: String }
    }
    enum Tick {
        struct Response { var syllableIndex: Int; var totalSyllables: Int }
        struct ViewModel { var activeIndex: Int; var progressLabel: String }
    }
    enum SyllableDetected {
        struct Response { var index: Int; var success: Bool }
        struct ViewModel { var completedIndices: Set<Int>; var showReward: Bool }
    }
    enum AmplitudeUpdate {
        struct Response { var levels: [Float] }
        struct ViewModel { var levels: [Float] }
    }
}

struct SyllableViewModel: Identifiable, Sendable {
    var id: Int { index }
    var index: Int
    var state: SyllableState
    var accessibilityLabel: String
}

enum SyllableState: Sendable, Equatable {
    case waiting
    case active
    case completed
}

// MARK: - SoftOnsetModels

enum SoftOnsetModels {
    enum StartSession {
        struct Request { var difficulty: StutteringDifficulty = .easy }
        struct Response { var word: String; var attemptNumber: Int }
        struct ViewModel { var word: String; var attemptLabel: String; var lanternState: LanternState }
    }
    enum RecordingResult {
        struct Response { var attackTimeMs: Float; var attemptNumber: Int; var maxAttempts: Int }
        struct ViewModel {
            var feedbackText: String
            var feedbackStyle: FeedbackStyle
            var lanternState: LanternState
            var waveformColorMode: OnsetColorMode
            var attemptLabel: String
            var isSessionComplete: Bool
        }
    }
    enum AmplitudeUpdate {
        struct Response { var levels: [Float] }
        struct ViewModel { var levels: [Float] }
    }
}

enum LanternState: Sendable, Equatable {
    case off, flicker, bright
}

enum OnsetColorMode: Sendable, Equatable {
    case neutral, soft, borderline, hard
}

enum FeedbackStyle: Sendable, Equatable {
    case success, warning, error, neutral
}

// MARK: - FluencyDiaryModels

enum FluencyDiaryModels {
    enum StartSession {
        struct Request {}
        struct Response { var text: String; var textIndex: Int }
        struct ViewModel { var text: String }
    }
    enum RecordingComplete {
        struct Response { var dysfluencyCount: Int; var totalSyllables: Int; var transcript: String }
        struct ViewModel { var showComplete: Bool }
    }
    enum LoadParentHistory {
        struct Request {}
        struct Response { var sessions: [FluencySessionData] }
        struct ViewModel { var sessions: [FluencySessionViewModel]; var chartData: [ChartPoint] }
    }
    enum AmplitudeUpdate {
        struct Response { var levels: [Float] }
        struct ViewModel { var levels: [Float] }
    }
}

struct FluencySessionData: Sendable {
    var id: String
    var date: Date
    var dysfluencyCount: Int
    var totalSyllables: Int
    var rate: Float
    var transcript: String
}

struct FluencySessionViewModel: Identifiable, Sendable {
    var id: String
    var dateText: String
    var rateText: String
    var isNormal: Bool
    var statusSymbol: String
}

struct ChartPoint: Identifiable, Sendable {
    var id: Date { date }
    var date: Date
    var rate: Float
}

// MARK: - StutteringDifficulty

enum StutteringDifficulty: String, Sendable, CaseIterable {
    case easy, medium, hard

    var bpm: Int {
        switch self {
        case .easy:   return 75
        case .medium: return 90
        case .hard:   return 105
        }
    }

    var tickIntervalSeconds: TimeInterval {
        60.0 / Double(bpm)
    }

    var requiredExhaleSec: TimeInterval {
        switch self {
        case .easy:   return 3
        case .medium: return 4
        case .hard:   return 5
        }
    }

    var roundCount: Int {
        switch self {
        case .easy:   return 5
        case .medium: return 7
        case .hard:   return 10
        }
    }

    var attackTimeThresholdMs: Float {
        switch self {
        case .easy:   return 100
        case .medium: return 120
        case .hard:   return 150
        }
    }
}
