import Foundation

// MARK: - Breathing VIP Models
//
// The Breathing game asks the child to blow at the microphone to "blow away"
// a dandelion / candle / balloon on screen. The Interactor drives a small
// state machine around a real AVAudioEngine RMS signal; models here describe
// the Request/Response/ViewModel envelopes and the game-specific domain
// types consumed by `BreathingInteractor` and `BreathingPresenter`.

enum BreathingModels {

    // MARK: - LoadSession
    // Scaffold contract preserved for backwards compatibility with the
    // SessionShell routing pattern. `Request.sessionId` is the activity id,
    // `Response.items` carries the Russian hint phrases the presenter renders.
    enum LoadSession {
        struct Request {
            var sessionId: String = ""
            var difficulty: BreathingDifficulty = .medium
        }
        struct Response {
            var items: [String] = []
            var config: BreathingGameConfig = .medium
            var scene: BreathingScene = .dandelion
        }
        struct ViewModel {
            var displayItems: [String] = []
            var titleText: String = ""
            var instructionText: String = ""
            var scene: BreathingScene = .dandelion
        }
    }

    // MARK: - SubmitAttempt
    // The view does not submit words for Breathing. This arm of the scaffold
    // protocol is kept so the routing pipeline keeps compiling; we just
    // carry the final blow duration / amplitude instead.
    enum SubmitAttempt {
        struct Request {
            var selectedWord: String = ""
            var audioURL: URL? = nil
        }
        struct Response {
            var isCorrect: Bool = false
            var score: Double = 0
        }
        struct ViewModel {
            var feedbackText: String = ""
            var isCorrect: Bool = false
        }
    }

    // MARK: - UpdateSignal
    // Interactor emits a stream of UI snapshots 20×/sec while the child is
    // blowing. Presenter turns them into the `ViewModel` the Canvas reads.
    enum UpdateSignal {
        struct Response {
            var state: BreathingGameState
            var amplitude: Float
            var normalizedAmplitude: Float // 0…1, threshold-relative
            var objectScale: Float          // 1.0…3.0 spring target
            var petalsRemaining: Int
            var elapsedMs: Int
            var progress: Float             // 0…1 against required duration
        }
        struct ViewModel {
            var title: String
            var subtitle: String
            var amplitude: Float
            var objectScale: CGFloat
            var petalsRemaining: Int
            var progress: Double
            var mascotMood: MascotMoodVM
            var showWarmUpOverlay: Bool
            var showTutorialOverlay: Bool
            var tutorialStep: Int
            var isFinished: Bool
            var failureMessage: String?
            var finalScore: Float?
        }
    }

    // MARK: - Finish
    enum Finish {
        struct Response {
            var result: BreathingResult
        }
        struct ViewModel {
            var title: String
            var subtitle: String
            var finalScore: Float   // 0…1 exposed to SessionShell
            var stars: Int          // 0…3 visual rating
        }
    }
}

// MARK: - Game state machine

enum BreathingGameState: Sendable, Equatable {
    case idle
    case tutorial(step: Int)            // 3 staged hints from Lyalya
    case warmUp(elapsedMs: Int)         // 3-second silence calibration
    case playing(elapsedMs: Int, amplitude: Float, objectScale: Float)
    case success(score: Float, duration: TimeInterval)
    case failure(reason: BreathingFailureReason)
    case summary(result: BreathingResult)
}

enum BreathingFailureReason: Sendable, Equatable {
    case tooQuiet          // never crossed threshold
    case tooShort          // started blowing then stopped too early
    case noMicrophone      // permission denied
    case interrupted       // AVAudioSession interruption (call, background)
}

// MARK: - Difficulty & config

enum BreathingDifficulty: String, Sendable {
    case easy, medium, hard

    /// Continuous exhale duration the child has to hold.
    var requiredDurationSec: TimeInterval {
        switch self {
        case .easy:   return 5
        case .medium: return 10
        case .hard:   return 20
        }
    }

    /// Minimum proportion of time the signal must sit above threshold
    /// for the attempt to count as successful.
    var minStableRatio: Float {
        switch self {
        case .easy:   return 0.55
        case .medium: return 0.70
        case .hard:   return 0.80
        }
    }
}

struct BreathingGameConfig: Sendable, Equatable {
    let difficulty: BreathingDifficulty
    let requiredDurationSec: TimeInterval
    let warmUpSec: TimeInterval
    let minStableRatio: Float
    let thresholdMultiplier: Float          // baseline × multiplier = amplitude gate
    let amplitudeScaleCap: Float            // visual scale ceiling

    static let easy = BreathingGameConfig(
        difficulty: .easy,
        requiredDurationSec: BreathingDifficulty.easy.requiredDurationSec,
        warmUpSec: 3,
        minStableRatio: BreathingDifficulty.easy.minStableRatio,
        thresholdMultiplier: 1.8,
        amplitudeScaleCap: 3.0
    )

    static let medium = BreathingGameConfig(
        difficulty: .medium,
        requiredDurationSec: BreathingDifficulty.medium.requiredDurationSec,
        warmUpSec: 3,
        minStableRatio: BreathingDifficulty.medium.minStableRatio,
        thresholdMultiplier: 2.0,
        amplitudeScaleCap: 3.0
    )

    static let hard = BreathingGameConfig(
        difficulty: .hard,
        requiredDurationSec: BreathingDifficulty.hard.requiredDurationSec,
        warmUpSec: 3,
        minStableRatio: BreathingDifficulty.hard.minStableRatio,
        thresholdMultiplier: 2.2,
        amplitudeScaleCap: 3.0
    )

    static func forDifficulty(_ difficulty: BreathingDifficulty) -> BreathingGameConfig {
        switch difficulty {
        case .easy:   return .easy
        case .medium: return .medium
        case .hard:   return .hard
        }
    }
}

// MARK: - Scene

enum BreathingScene: String, Sendable, Equatable {
    case dandelion
    case candle
    case balloon

    var totalPetals: Int {
        switch self {
        case .dandelion: return 12
        case .candle:    return 1
        case .balloon:   return 10
        }
    }
}

// MARK: - Result

struct BreathingResult: Sendable, Equatable {
    let difficulty: BreathingDifficulty
    let durationSec: TimeInterval         // total exhale duration held
    let stableRatio: Float                // time above threshold / total
    let score: Float                      // 0…1 — passed to SessionShell
    let stars: Int                        // 0…3 visual rating
    let petalsBlown: Int
    let totalPetals: Int
    let didSucceed: Bool
}

// MARK: - Scoring

enum BreathingScoring {

    /// `score = stableRatio × min(duration/required, 1.0)`
    /// Both factors are clamped to 0…1.
    static func score(
        stableRatio: Float,
        durationSec: TimeInterval,
        required: TimeInterval
    ) -> Float {
        guard required > 0 else { return 0 }
        let durationFactor = Float(min(durationSec / required, 1.0))
        let ratio = max(0, min(stableRatio, 1))
        return max(0, min(ratio * durationFactor, 1))
    }

    static func stars(for score: Float) -> Int {
        switch score {
        case 0.85...: return 3
        case 0.65..<0.85: return 2
        case 0.40..<0.65: return 1
        default: return 0
        }
    }
}

// MARK: - Mascot mood (VM-side enum to keep View pure)

enum MascotMoodVM: String, Sendable, Equatable {
    case idle
    case encouraging
    case celebrating
    case sad
    case thinking
}
