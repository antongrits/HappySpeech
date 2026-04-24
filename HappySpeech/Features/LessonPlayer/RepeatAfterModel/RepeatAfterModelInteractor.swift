import Foundation
import OSLog

// MARK: - RepeatAfterModelBusinessLogic

@MainActor
protocol RepeatAfterModelBusinessLogic: AnyObject {
    func loadSession(_ request: RepeatAfterModelModels.LoadSession.Request)
    func startWord(_ request: RepeatAfterModelModels.StartWord.Request)
    func toggleRecording()
    func submitTranscript(_ request: RepeatAfterModelModels.EvaluateAttempt.Request)
    func advanceWord()
    func completeSession()
    func cancel()
}

// MARK: - RepeatAfterModelInteractor
//
// Игра «Повтори за Лялей»:
//   loading → [wordPreview → recording → feedback] × N → completed
//
// * N = `wordsPerSession` (по умолчанию 5).
// * До `maxAttempts` попыток (3) на каждое слово. После третьей
//   неудачной попытки слово принудительно переходит дальше (canAdvance=true,
//   passed=false) — чтобы не бесить ребёнка.
// * Скоринг — `RepeatScoring.score(transcript:target:confidence:)`.
// * Итог сессии: нормализованный средний лучший-за-слово score.

@MainActor
final class RepeatAfterModelInteractor: RepeatAfterModelBusinessLogic {

    // MARK: - Dependencies

    var presenter: (any RepeatAfterModelPresentationLogic)?

    private let logger = HSLogger.asr

    // MARK: - Tunables

    private let wordsPerSession: Int = 5
    private let maxAttempts: Int = 3

    // MARK: - Session state

    private(set) var words: [TargetWordItem] = []
    private(set) var currentIndex: Int = 0
    private(set) var attemptsLeft: Int = 3
    private(set) var isRecording: Bool = false
    private(set) var childName: String = ""

    /// Лучший скор по каждому слову (по id). Используется для итогового
    /// усреднения.
    private var bestScorePerWord: [String: Float] = [:]

    // MARK: - loadSession

    func loadSession(_ request: RepeatAfterModelModels.LoadSession.Request) {
        childName = request.childName
        let pool = TargetWordItem.words(for: request.soundGroup)
        words = Array(pool.prefix(wordsPerSession))
        currentIndex = 0
        attemptsLeft = maxAttempts
        bestScorePerWord = [:]
        isRecording = false

        logger.info("repeat loadSession soundGroup=\(request.soundGroup, privacy: .public) count=\(self.words.count)")

        let response = RepeatAfterModelModels.LoadSession.Response(
            words: words,
            childName: childName
        )
        presenter?.presentLoadSession(response)
    }

    // MARK: - startWord

    func startWord(_ request: RepeatAfterModelModels.StartWord.Request) {
        guard !words.isEmpty else { return }
        currentIndex = max(0, min(request.wordIndex, words.count - 1))
        attemptsLeft = maxAttempts
        isRecording = false

        let word = words[currentIndex]
        let response = RepeatAfterModelModels.StartWord.Response(
            word: word,
            wordNumber: currentIndex + 1,
            total: words.count,
            attemptsLeft: attemptsLeft
        )
        presenter?.presentStartWord(response)
    }

    // MARK: - toggleRecording

    func toggleRecording() {
        isRecording.toggle()
        let response = RepeatAfterModelModels.RecordAttempt.Response(isRecording: isRecording)
        presenter?.presentRecordAttempt(response)
    }

    // MARK: - submitTranscript

    func submitTranscript(_ request: RepeatAfterModelModels.EvaluateAttempt.Request) {
        guard !words.isEmpty, currentIndex < words.count else { return }
        let word = words[currentIndex]

        // Если попыток не осталось (защита от ре-submit) — просто advance.
        if attemptsLeft <= 0 {
            let response = RepeatAfterModelModels.EvaluateAttempt.Response(
                score: 0,
                passed: false,
                feedback: String(localized: "repeat.feedback.forced_advance"),
                attemptsLeft: 0,
                canAdvance: true
            )
            presenter?.presentEvaluateAttempt(response)
            return
        }

        isRecording = false
        let score = RepeatScoring.score(
            transcript: request.transcript,
            target: word.word,
            confidence: request.confidence
        )
        let passed = RepeatScoring.passed(score: score)

        // Обновляем "лучший" балл за слово.
        let previousBest = bestScorePerWord[word.id] ?? 0
        if score > previousBest {
            bestScorePerWord[word.id] = score
        }

        attemptsLeft = max(0, attemptsLeft - 1)
        let canAdvance = passed || attemptsLeft == 0

        let feedback: String
        if passed {
            feedback = String(localized: "repeat.feedback.great")
        } else if attemptsLeft == 0 {
            feedback = String(localized: "repeat.feedback.forced_advance")
        } else {
            feedback = String(localized: "repeat.feedback.try_again")
        }

        logger.info("repeat evaluate word=\(word.id, privacy: .public) score=\(score) passed=\(passed) attemptsLeft=\(self.attemptsLeft)")

        let response = RepeatAfterModelModels.EvaluateAttempt.Response(
            score: score,
            passed: passed,
            feedback: feedback,
            attemptsLeft: attemptsLeft,
            canAdvance: canAdvance
        )
        presenter?.presentEvaluateAttempt(response)
    }

    // MARK: - advanceWord

    func advanceWord() {
        let nextIndex = currentIndex + 1
        if nextIndex >= words.count {
            completeSession()
        } else {
            startWord(.init(wordIndex: nextIndex))
        }
    }

    // MARK: - completeSession

    func completeSession() {
        let outOf = max(words.count, 1)
        let total = bestScorePerWord.values.reduce(0, +) / Float(outOf)
        let normalized = max(0, min(total, 1))
        let stars = Self.starCount(for: normalized)

        logger.info("repeat completeSession score=\(normalized) stars=\(stars)/\(outOf)")

        let response = RepeatAfterModelModels.CompleteSession.Response(
            totalScore: normalized,
            starsEarned: stars
        )
        presenter?.presentCompleteSession(response)
    }

    func cancel() {
        isRecording = false
    }

    // MARK: - Helpers

    private static func starCount(for score: Float) -> Int {
        switch score {
        case 0.85...:     return 3
        case 0.65..<0.85: return 2
        case 0.40..<0.65: return 1
        default:          return 0
        }
    }
}
