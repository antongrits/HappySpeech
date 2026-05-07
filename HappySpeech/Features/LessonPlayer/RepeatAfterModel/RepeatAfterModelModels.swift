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
                TargetWordItem(id: "sova", word: "Сова", soundGroup: soundGroup, syllabification: "со-ва", audioFilename: nil, emoji: "word_bird"),
                TargetWordItem(id: "zamok", word: "Замок", soundGroup: soundGroup, syllabification: "за-мок", audioFilename: nil, emoji: "word_door"),
                TargetWordItem(id: "zub", word: "Зуб", soundGroup: soundGroup, syllabification: "зуб", audioFilename: nil, emoji: "word_bag"),
                TargetWordItem(id: "sad", word: "Сад", soundGroup: soundGroup, syllabification: "сад", audioFilename: nil, emoji: "word_tree"),
                TargetWordItem(id: "sobaka", word: "Собака", soundGroup: soundGroup, syllabification: "со-ба-ка", audioFilename: nil, emoji: "word_dog")
            ]
        case SoundFamily.hissing.rawValue:
            return [
                TargetWordItem(id: "shuba", word: "Шуба", soundGroup: soundGroup, syllabification: "шу-ба", audioFilename: nil, emoji: "word_bag"),
                TargetWordItem(id: "zhaba", word: "Жаба", soundGroup: soundGroup, syllabification: "жа-ба", audioFilename: nil, emoji: "word_frog"),
                TargetWordItem(id: "shkola", word: "Школа", soundGroup: soundGroup, syllabification: "шко-ла", audioFilename: nil, emoji: "house.fill"),
                TargetWordItem(id: "zhuk", word: "Жук", soundGroup: soundGroup, syllabification: "жук", audioFilename: nil, emoji: "word_butterfly_insect"),
                TargetWordItem(id: "shapka", word: "Шапка", soundGroup: soundGroup, syllabification: "шап-ка", audioFilename: nil, emoji: "word_bag")
            ]
        case SoundFamily.sonorant.rawValue:
            return [
                TargetWordItem(id: "raketa", word: "Ракета", soundGroup: soundGroup, syllabification: "ра-ке-та", audioFilename: nil, emoji: "reward_rocket"),
                TargetWordItem(id: "ryba", word: "Рыба", soundGroup: soundGroup, syllabification: "ры-ба", audioFilename: nil, emoji: "word_fish"),
                TargetWordItem(id: "luna", word: "Луна", soundGroup: soundGroup, syllabification: "лу-на", audioFilename: nil, emoji: "word_moon"),
                TargetWordItem(id: "lev", word: "Лев", soundGroup: soundGroup, syllabification: "лев", audioFilename: nil, emoji: "reward_champion"),
                TargetWordItem(id: "radio", word: "Радио",
                               soundGroup: soundGroup, syllabification: "ра-ди-о",
                               audioFilename: nil,
                               emoji: "antenna.radiowaves.left.and.right")
            ]
        default: // velar + unknown
            return [
                TargetWordItem(id: "kot", word: "Кот", soundGroup: soundGroup, syllabification: "кот", audioFilename: nil, emoji: "word_cat"),
                TargetWordItem(id: "gora", word: "Гора", soundGroup: soundGroup, syllabification: "го-ра", audioFilename: nil, emoji: "word_forest"),
                TargetWordItem(id: "hvala", word: "Хвала", soundGroup: soundGroup, syllabification: "хва-ла", audioFilename: nil, emoji: "hands.clap.fill"),
                TargetWordItem(id: "kniga", word: "Книга", soundGroup: soundGroup, syllabification: "кни-га", audioFilename: nil, emoji: "books.vertical.fill"),
                TargetWordItem(id: "galka", word: "Галка", soundGroup: soundGroup, syllabification: "гал-ка", audioFilename: nil, emoji: "word_bird")
            ]
        }
    }
}

// MARK: - Phase

/// 7-step state machine для одного слова в сессии «Повтори за Лялей»:
///
///   loading
///     ↓
///   wordPreview          — слово показано, ребёнок может нажать «Послушать» / «Записать»
///     ↓ (auto или tap)
///   modelPlaying         — Ляля произносит эталон, буквы подсвечиваются по очереди
///     ↓ (audio finished)
///   waiting              — короткая пауза «приготовиться» (~0.6с)
///     ↓ (tap mic)
///   recording            — идёт запись с микрофона + pulse-ring анимация
///     ↓ (stop)
///   processing           — ASR + scoring (1–2 сек)
///     ↓
///   feedback             — ⭐︎ результат + AttemptDots
///     ↓ (advance / retry)
///   wordPreview … или completed
///
/// `result` — алиас для `feedback`, оставлен для семантической ясности
/// "финальной фазы успеха". Использовать `.feedback` (текущий код).
enum RepeatPhase: Sendable, Equatable {
    case loading
    case wordPreview
    case modelPlaying
    case waiting
    case recording
    case processing
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
            let totalRounds: Int
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
            let canReplay: Bool
            let replayCount: Int
        }
        struct ViewModel: Sendable {
            let word: TargetWordItem
            let progressLabel: String
            let attemptsLabel: String
            let syllabification: String
            let canReplay: Bool
            let replayCount: Int
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

    // MARK: EvaluateAttempt (ASR path)
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
            let diagnostic: PronunciationDiagnostic
            let encouragement: String?
            let hintLevel: RepeatHintLevel
            let stars: Int
        }
        struct ViewModel: Sendable {
            let score: Float
            let passed: Bool
            let feedbackText: String
            let attemptsLabel: String
            let canAdvance: Bool
            let diagnosticText: String?
            let encouragement: String?
            let hintAvailable: Bool
            let stars: Int
        }
    }

    // MARK: MLEvaluate (PronunciationScorer path)
    enum MLEvaluate {
        struct Request: Sendable {
            let wordId: String
            let mlScore: Float
        }
    }

    // MARK: ReplayModel
    enum ReplayModel {
        struct Request: Sendable {}
        struct Response: Sendable {
            let word: TargetWordItem
            let replayCount: Int
            let replayLimitReached: Bool
            let audioFilename: String?
        }
        struct ViewModel: Sendable {
            let audioFilename: String?
            let replayCount: Int
            let replayLimitReached: Bool
            let replayLabel: String
        }
    }

    // MARK: Hint
    enum Hint {
        struct Request: Sendable {}
        struct Response: Sendable {
            let hintLevel: RepeatHintLevel
            let syllabification: String
            let articulationAsset: String
            let word: TargetWordItem
        }
        struct ViewModel: Sendable {
            let hintLevel: RepeatHintLevel
            let syllabificationText: String
            let articulationAsset: String
            let hintLabel: String
        }
    }

    // MARK: SloMo
    enum SloMo {
        struct Request: Sendable {
            let playbackRate: Float
        }
        struct Response: Sendable {
            let audioFilename: String?
            let playbackRate: Float
            let word: TargetWordItem
        }
        struct ViewModel: Sendable {
            let audioFilename: String?
            let playbackRate: Float
            let sloMoLabel: String
        }
    }

    // MARK: CompleteSession
    enum CompleteSession {
        struct Request: Sendable {}
        struct Response: Sendable {
            let totalScore: Float
            let starsEarned: Int
            let totalAttempts: Int
            let wordsWithPerfectScore: Int
            let wordsCompleted: Int
        }
        struct ViewModel: Sendable {
            let starsEarned: Int
            let scoreLabel: String
            let message: String
            /// 0…1 — прокидывается наверх через SessionShell.onComplete.
            let normalizedScore: Float
            let statsLabel: String
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
    var statsLabel: String = ""
    var phase: RepeatPhase = .loading
    /// Финальный 0…1 скор, который View передаёт в SessionShell.onComplete.
    var pendingFinalScore: Float?
    // Replay
    var canReplay: Bool = true
    var replayLimitReached: Bool = false
    var replayLabel: String = ""
    // Feedback extras
    var diagnosticText: String?
    var encouragement: String?
    var hintAvailable: Bool = true
    var roundStars: Int = 0
    // Hint
    var hintLevel: RepeatHintLevel = .none
    var hintLabel: String = ""
    var articulationAsset: String = ""
    // Slo-mo
    var sloMoLabel: String = ""
    var sloMoPending: Bool = false
    var sloMoRate: Float = 0.75
}
