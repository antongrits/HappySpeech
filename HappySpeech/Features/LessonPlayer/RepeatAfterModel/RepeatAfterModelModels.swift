import Foundation

// MARK: - RepeatAfterModel VIP Models
//
// "Повтори за Лялей" — классическая игра-повторюшка:
//   listen(reference) → record(attempt) → score → [advance | retry]
//
// 5 слов на сессию × до 3 попыток на каждое слово. Скоринг — ASR
// transcript + confidence + heuristic substring match. ASR вызывается
// через `AppContainer.asrService`. Если WhisperKit недоступен или
// транскрипт пустой — fallback на confidence из сервиса.

// MARK: - Target word

struct TargetWordItem: Sendable, Identifiable, Equatable {
    let id: String
    let word: String
    let soundGroup: String
    /// Слогоразделение для подсветки: "ра-ке-та".
    let syllabification: String
    /// Опциональный файл эталонной озвучки (bundle). Если nil — fallback
    /// на SoundService.playLyalya (приветственная фраза) или TTS.
    let audioFilename: String?
    let emoji: String
}

extension TargetWordItem {

    /// 5 слов на сессию для каждой группы. Подобраны с акцентом на
    /// целевой фонеме в начальной/средней позиции.
    static func words(for soundGroup: String) -> [TargetWordItem] {
        switch soundGroup {
        case SoundFamily.whistling.rawValue:
            return [
                TargetWordItem(id: "sova", word: "Сова", soundGroup: soundGroup, syllabification: "со-ва", audioFilename: nil, emoji: "🦉"),
                TargetWordItem(id: "zamok", word: "Замок", soundGroup: soundGroup, syllabification: "за-мок", audioFilename: nil, emoji: "🔒"),
                TargetWordItem(id: "zub", word: "Зуб", soundGroup: soundGroup, syllabification: "зуб", audioFilename: nil, emoji: "🦷"),
                TargetWordItem(id: "sad", word: "Сад", soundGroup: soundGroup, syllabification: "сад", audioFilename: nil, emoji: "🌳"),
                TargetWordItem(id: "sobaka", word: "Собака", soundGroup: soundGroup, syllabification: "со-ба-ка", audioFilename: nil, emoji: "🐶")
            ]
        case SoundFamily.hissing.rawValue:
            return [
                TargetWordItem(id: "shuba", word: "Шуба", soundGroup: soundGroup, syllabification: "шу-ба", audioFilename: nil, emoji: "🧥"),
                TargetWordItem(id: "zhaba", word: "Жаба", soundGroup: soundGroup, syllabification: "жа-ба", audioFilename: nil, emoji: "🐸"),
                TargetWordItem(id: "shkola", word: "Школа", soundGroup: soundGroup, syllabification: "шко-ла", audioFilename: nil, emoji: "🏫"),
                TargetWordItem(id: "zhuk", word: "Жук", soundGroup: soundGroup, syllabification: "жук", audioFilename: nil, emoji: "🐞"),
                TargetWordItem(id: "shapka", word: "Шапка", soundGroup: soundGroup, syllabification: "шап-ка", audioFilename: nil, emoji: "🧢")
            ]
        case SoundFamily.sonorant.rawValue:
            return [
                TargetWordItem(id: "raketa", word: "Ракета", soundGroup: soundGroup, syllabification: "ра-ке-та", audioFilename: nil, emoji: "🚀"),
                TargetWordItem(id: "ryba", word: "Рыба", soundGroup: soundGroup, syllabification: "ры-ба", audioFilename: nil, emoji: "🐟"),
                TargetWordItem(id: "luna", word: "Луна", soundGroup: soundGroup, syllabification: "лу-на", audioFilename: nil, emoji: "🌙"),
                TargetWordItem(id: "lev", word: "Лев", soundGroup: soundGroup, syllabification: "лев", audioFilename: nil, emoji: "🦁"),
                TargetWordItem(id: "radio", word: "Радио", soundGroup: soundGroup, syllabification: "ра-ди-о", audioFilename: nil, emoji: "📻")
            ]
        default: // velar + unknown
            return [
                TargetWordItem(id: "kot", word: "Кот", soundGroup: soundGroup, syllabification: "кот", audioFilename: nil, emoji: "🐱"),
                TargetWordItem(id: "gora", word: "Гора", soundGroup: soundGroup, syllabification: "го-ра", audioFilename: nil, emoji: "⛰️"),
                TargetWordItem(id: "hvala", word: "Хвала", soundGroup: soundGroup, syllabification: "хва-ла", audioFilename: nil, emoji: "👏"),
                TargetWordItem(id: "kniga", word: "Книга", soundGroup: soundGroup, syllabification: "кни-га", audioFilename: nil, emoji: "📚"),
                TargetWordItem(id: "galka", word: "Галка", soundGroup: soundGroup, syllabification: "гал-ка", audioFilename: nil, emoji: "🐦")
            ]
        }
    }
}

// MARK: - Phase

enum RepeatPhase: Sendable, Equatable {
    case loading
    case wordPreview
    case recording
    case feedback
    case completed
}

// MARK: - Scoring

enum RepeatScoring {

    /// Эвристика скоринга на основе транскрипта и confidence:
    ///   1.0 — точное совпадение (case-insensitive, диакритика нормализована);
    ///   0.8 — слово-в-слово не совпадает, но confidence ≥ 0.85;
    ///   0.7 — первые ≥2 символа совпали (начало правильное);
    ///   else — сам confidence (ограничен 0…1).
    static func score(transcript: String, target: String, confidence: Float) -> Float {
        let normTranscript = normalize(transcript)
        let normTarget = normalize(target)
        if normTranscript == normTarget {
            return 1.0
        }
        let cappedConfidence = max(0, min(confidence, 1))
        if cappedConfidence >= 0.85 {
            return 0.8
        }
        if let prefixScore = prefixScore(transcript: normTranscript, target: normTarget) {
            return prefixScore
        }
        return cappedConfidence
    }

    /// Решение, засчитываем ли попытку (>= 0.65).
    static func passed(score: Float) -> Bool { score >= 0.65 }

    private static func normalize(_ value: String) -> String {
        let lowered = value.lowercased()
        let filtered = lowered.unicodeScalars.filter { scalar in
            CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar)
        }
        return String(String.UnicodeScalarView(filtered))
    }

    private static func prefixScore(transcript: String, target: String) -> Float? {
        let prefixLength = min(2, target.count)
        guard prefixLength > 0 else { return nil }
        let targetPrefix = target.prefix(prefixLength)
        if transcript.hasPrefix(targetPrefix) {
            return 0.7
        }
        return nil
    }
}

// MARK: - VIP envelopes

enum RepeatAfterModelModels {

    // MARK: LoadSession
    enum LoadSession {
        struct Request: Sendable {
            let soundGroup: String
            let childName: String
        }
        struct Response: Sendable {
            let words: [TargetWordItem]
            let childName: String
        }
        struct ViewModel: Sendable {
            let totalWords: Int
            let greeting: String
        }
    }

    // MARK: StartWord
    enum StartWord {
        struct Request: Sendable {
            let wordIndex: Int
        }
        struct Response: Sendable {
            let word: TargetWordItem
            let wordNumber: Int
            let total: Int
            let attemptsLeft: Int
        }
        struct ViewModel: Sendable {
            let word: TargetWordItem
            let progressLabel: String
            let attemptsLabel: String
            let syllabification: String
        }
    }

    // MARK: RecordAttempt
    enum RecordAttempt {
        struct Request: Sendable {}
        struct Response: Sendable {
            let isRecording: Bool
        }
        struct ViewModel: Sendable {
            let isRecording: Bool
            let micLabel: String
        }
    }

    // MARK: EvaluateAttempt
    enum EvaluateAttempt {
        struct Request: Sendable {
            let transcript: String
            let confidence: Float
        }
        struct Response: Sendable {
            let score: Float
            let passed: Bool
            let feedback: String
            let attemptsLeft: Int
            let canAdvance: Bool
        }
        struct ViewModel: Sendable {
            let score: Float
            let passed: Bool
            let feedbackText: String
            let attemptsLabel: String
            let canAdvance: Bool
        }
    }

    // MARK: CompleteSession
    enum CompleteSession {
        struct Request: Sendable {}
        struct Response: Sendable {
            let totalScore: Float
            let starsEarned: Int
        }
        struct ViewModel: Sendable {
            let starsEarned: Int
            let scoreLabel: String
            let message: String
            /// 0…1 — прокидывается наверх через SessionShell.onComplete.
            let normalizedScore: Float
        }
    }
}

// MARK: - Display store

@MainActor
@Observable
final class RepeatAfterModelDisplay {
    var totalWords: Int = 5
    var greeting: String = ""
    var currentWord: TargetWordItem?
    var progressLabel: String = ""
    var attemptsLabel: String = ""
    var syllabification: String = ""
    var isRecording: Bool = false
    var micLabel: String = ""
    var feedbackText: String = ""
    var score: Float = 0
    var passed: Bool = false
    var canAdvance: Bool = false
    var starsEarned: Int = 0
    var scoreLabel: String = ""
    var completionMessage: String = ""
    var phase: RepeatPhase = .loading
    /// Финальный 0…1 скор, который View передаёт в SessionShell.onComplete.
    var pendingFinalScore: Float?
}
