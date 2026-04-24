import Foundation

// MARK: - Rhythm VIP Models
//
// Syllable-rhythm matching game. Лала hums/speaks a rhythmic pattern
// ("ТА-та-та"), and the child repeats it back by saying a matching word
// ("ра-ке-та") with the same syllable count and stress. Detection is done
// via AVAudioEngine RMS — every loud burst with clear silence between is
// counted as a syllable.
//
// Flow:
//   loading → preview → playing (TTS + beat animation)
//           → recording (RMS detector) → feedback → (next | completed)

enum RhythmModels {

    // MARK: - LoadPattern
    enum LoadPattern {
        struct Request { var soundGroup: String = "whistling"; var index: Int = 0 }
        struct Response {
            var pattern: RhythmPattern
            var patternIndex: Int
            var totalPatterns: Int
        }
        struct ViewModel {
            var beats: [RhythmBeatDisplay]
            var syllableWord: String
            var targetWord: String
            var displayPattern: String
            var emoji: String
            var patternIndex: Int
            var totalPatterns: Int
            var progressFraction: Double
        }
    }

    // MARK: - PlayPattern
    enum PlayPattern {
        struct Request { }
        struct Response { var activeBeatIndex: Int }
        struct ViewModel { var activeBeatIndex: Int }
    }

    // MARK: - StartRecord
    enum StartRecord {
        struct Request { }
        struct Response { }
        struct ViewModel { }
    }

    // MARK: - UpdateRMS
    enum UpdateRMS {
        struct Request { var rms: Float = 0; var detectedBeats: Int = 0 }
        struct Response { var rmsLevel: Float; var detectedBeats: Int }
        struct ViewModel { var rmsLevel: Float; var detectedBeats: Int }
    }

    // MARK: - EvaluateRhythm
    enum EvaluateRhythm {
        struct Request { var detectedBeats: Int = 0; var expectedBeats: Int = 0 }
        struct Response {
            var score: Float
            var correct: Bool
            var detectedBeats: Int
            var expectedBeats: Int
            var beatsWasHit: [Bool]
        }
        struct ViewModel {
            var feedbackText: String
            var feedbackCorrect: Bool
            var starsPreview: Int
            var beatsWasHit: [Bool]
            var lastScore: Float
        }
    }

    // MARK: - NextPattern
    enum NextPattern {
        struct Request { }
        struct Response { }
        struct ViewModel { }
    }

    // MARK: - Complete
    enum Complete {
        struct Request { }
        struct Response {
            var finalScore: Float
            var correctPatterns: Int
            var totalPatterns: Int
        }
        struct ViewModel {
            var completionMessage: String
            var scoreLabel: String
            var starsEarned: Int
            var finalScore: Float
        }
    }
}

// MARK: - Beat strength

/// Один "бит" паттерна — сильный или слабый
enum BeatStrength: String, Sendable, CaseIterable {
    case strong  // ТА (громкий, долгий, ударный)
    case weak    // та (тихий, короткий, безударный)
}

// MARK: - RhythmPattern

/// Ритмический паттерн — набор ударных/безударных слогов, привязан к слову.
struct RhythmPattern: Identifiable, Sendable, Equatable {
    let id: UUID
    /// Массив ударов: например [.strong, .weak, .weak] — ТА-та-та.
    let beats: [BeatStrength]
    /// Слово с разбиением по слогам через дефис: "РА-ке-та".
    let syllableWord: String
    /// Целевое слово без дефисов: "ракета".
    let targetWord: String
    /// Группа звука: "whistling" | "hissing" | "sonants" | "velar".
    let soundGroup: String
    /// Эмодзи для визуализации.
    let emoji: String
    /// Паттерн для отображения ("ТА • та • та").
    let displayPattern: String
}

// MARK: - RhythmPhase

enum RhythmPhase: Sendable, Equatable {
    case loading
    case preview     // показ паттерна и слова
    case playing     // воспроизводим паттерн (анимируем биты)
    case recording   // ребёнок повторяет
    case feedback    // результат текущего паттерна
    case completed   // финал
}

// MARK: - RhythmBeatDisplay

struct RhythmBeatDisplay: Sendable, Equatable {
    let strength: BeatStrength
    var isActive: Bool    // подсвечен в данный момент
    var wasHit: Bool      // ребёнок попал по этому биту
}

// MARK: - RhythmDisplay

/// Observable view-state, которым владеет View через @State.
/// Presenter мутирует его поля; View реактивно перерисовывается.
@Observable @MainActor
final class RhythmDisplay {
    var beats: [RhythmBeatDisplay] = []
    var syllableWord: String = ""
    var targetWord: String = ""
    var displayPattern: String = ""
    var emoji: String = ""
    var phase: RhythmPhase = .loading
    var patternIndex: Int = 0
    var totalPatterns: Int = 5
    var progressFraction: Double = 0
    var currentActiveBeat: Int = -1   // индекс активного бита (для анимации)
    var rmsLevel: Float = 0           // текущий RMS (0..1)
    var detectedBeats: Int = 0        // сколько "хлопков" обнаружено
    var feedbackText: String = ""
    var feedbackCorrect: Bool = false
    var starsEarned: Int = 0
    var starsPreview: Int = 0
    var scoreLabel: String = ""
    var completionMessage: String = ""
    var lastScore: Float = 0
    var finalScore: Float = 0
}
