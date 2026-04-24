import Foundation
import AVFoundation
import OSLog

// MARK: - ListenAndChooseBusinessLogic

@MainActor
protocol ListenAndChooseBusinessLogic: AnyObject {
    func loadRound(_ request: ListenAndChooseModels.LoadRound.Request) async
    func submitAttempt(_ request: ListenAndChooseModels.SubmitAttempt.Request)
    func replayCurrentWord(_ request: ListenAndChooseModels.ReplayWord.Request)
}

// MARK: - ListenAndChooseInteractor

/// Business logic for a "Listen and choose" session.
///
/// Responsibilities:
///   * Build a question catalog for the child's current sound target (4 groups ×
///     12+ questions each — whistling, hissing, sonants, velar).
///   * Orchestrate a session: serve each question once, then replay wrong answers
///     in a second "retry pass" so the child gets another shot.
///   * Track per-question stats (attempts, response time, solved flag) and a
///     running streak of correct answers.
///   * Compute an adaptive score in `[0.0, 1.0]` that weighs first-try hit rate,
///     streak bonus and the retry penalty.
///   * Provide a TTS replay helper so the child can re-listen to the target word
///     at a slower rate without spending attempts.
///
/// The class keeps its original public API (`loadRound`, `submitAttempt`) so any
/// existing views and tests continue to compile.
@MainActor
final class ListenAndChooseInteractor: NSObject, ListenAndChooseBusinessLogic {

    // MARK: - Collaborators

    var presenter: (any ListenAndChoosePresentationLogic)?

    private let contentService: any ContentService
    private let logger = Logger(subsystem: "ru.happyspeech", category: "ListenAndChoose")

    // MARK: - Tuning

    private let maxAttempts: Int = 3
    private let targetSessionLength: Int = 8
    private let streakBonusLarge: Float = 0.10
    private let streakBonusSmall: Float = 0.05
    private let streakThresholdLarge: Int = 5
    private let streakThresholdSmall: Int = 3
    private let retryFirstTryScoreCap: Float = 0.66

    // MARK: - TTS

    private let synthesizer = AVSpeechSynthesizer()
    private static let voiceLocale = "ru-RU"
    private static let replayRate: Float = 0.40
    private static let replayPitch: Float = 1.05

    // MARK: - Session state

    private var soundGroup: String = "whistling"
    private var questions: [Question] = []
    private var retryQueue: [Question] = []
    private var currentRound: Question?
    private var isRetryPass: Bool = false
    private var totalQuestions: Int = 0
    private var questionNumber: Int = 0

    // MARK: - Scoring state

    private var currentStreak: Int = 0
    private var maxStreak: Int = 0
    private var firstTryCorrect: Int = 0
    private var firstTryAnswered: Int = 0
    private var totalCorrect: Int = 0
    private var totalAnswered: Int = 0
    private var questionStats: [UUID: QuestionStats] = [:]

    // MARK: - Init

    init(contentService: any ContentService) {
        self.contentService = contentService
        super.init()
    }

    // MARK: - ListenAndChooseBusinessLogic

    func loadRound(_ request: ListenAndChooseModels.LoadRound.Request) async {
        // First entry in this session — hydrate the catalog.
        if questions.isEmpty && retryQueue.isEmpty && currentRound == nil {
            let packItems = await fetchCandidates(for: request.soundTarget)
            soundGroup = Self.resolveSoundGroup(for: request.soundTarget)
            questions = Self.buildQuestions(
                packItems: packItems,
                soundTarget: request.soundTarget,
                soundGroup: soundGroup,
                difficulty: request.difficulty,
                sessionLength: targetSessionLength
            )
            totalQuestions = questions.count
            questionNumber = 0
            logger.info(
                "Session bootstrap group=\(self.soundGroup, privacy: .public) total=\(self.totalQuestions, privacy: .public)"
            )
        }

        // Pick the next question: primary queue first, then retry pass.
        let nextQuestion: Question
        if let primary = questions.first {
            questions.removeFirst()
            isRetryPass = false
            nextQuestion = primary
            questionNumber += 1
        } else if let retry = retryQueue.first {
            retryQueue.removeFirst()
            isRetryPass = true
            nextQuestion = retry
            logger.info("Retry-pass question remaining=\(self.retryQueue.count, privacy: .public)")
        } else {
            logger.notice("No more questions — session should be complete.")
            return
        }

        currentRound = nextQuestion
        questionStats[nextQuestion.id, default: QuestionStats(questionId: nextQuestion.id)]
            .lastServedAt = Date()

        let options = nextQuestion.choices.map {
            ListenAndChooseModels.LoadRound.OptionItem(
                id: $0.id, word: $0.word, imageAsset: $0.imageAsset
            )
        }

        let response = ListenAndChooseModels.LoadRound.Response(
            targetWord: nextQuestion.targetWord,
            options: options,
            correctIndex: nextQuestion.correctIndex,
            audioAsset: nextQuestion.audioAsset,
            hint: isRetryPass ? generateHint(for: nextQuestion.targetWord, soundGroup: soundGroup) : nil,
            questionNumber: questionNumber,
            totalQuestions: totalQuestions,
            isRetry: isRetryPass
        )
        presenter?.presentLoadRound(response)
    }

    func submitAttempt(_ request: ListenAndChooseModels.SubmitAttempt.Request) {
        let isCorrect = request.selectedIndex == request.correctIndex
        let attempts = max(request.attemptsUsed, 1)
        let shouldReveal = !isCorrect && attempts >= maxAttempts

        updateStreak(correct: isCorrect)
        recordQuestionAttempt(
            correct: isCorrect,
            attemptNumber: attempts,
            responseTimeMs: request.responseTimeMs
        )

        // Enqueue this question for a retry pass on the first wrong attempt.
        if !isCorrect && attempts == 1, let current = currentRound, !isRetryPass {
            if !retryQueue.contains(where: { $0.id == current.id }) {
                retryQueue.append(current)
            }
        }

        let attemptScore = computeAttemptScore(isCorrect: isCorrect, attempts: attempts)
        let finalScore = computeSessionScore()
        let isTerminalForThisQuestion = isCorrect || shouldReveal
        let hint: String? = (!isCorrect)
            ? generateHint(
                for: currentRound?.targetWord ?? "",
                soundGroup: soundGroup
            )
            : nil

        let response = ListenAndChooseModels.SubmitAttempt.Response(
            isCorrect: isCorrect,
            isFinalAttempt: isTerminalForThisQuestion,
            score: isTerminalForThisQuestion ? finalScore : attemptScore,
            shouldRevealAnswer: shouldReveal,
            correctIndex: request.correctIndex,
            currentStreak: currentStreak,
            hint: hint
        )
        logger.debug(
            "Attempt correct=\(isCorrect, privacy: .public) attempts=\(attempts, privacy: .public) streak=\(self.currentStreak, privacy: .public) score=\(finalScore, privacy: .public)"
        )
        presenter?.presentSubmitAttempt(response)
    }

    func replayCurrentWord(_ request: ListenAndChooseModels.ReplayWord.Request) {
        _ = request
        guard let current = currentRound else {
            logger.notice("replayCurrentWord called with no active round")
            return
        }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: current.targetWord)
        utterance.voice = AVSpeechSynthesisVoice(language: Self.voiceLocale)
        utterance.rate = Self.replayRate
        utterance.pitchMultiplier = Self.replayPitch
        synthesizer.speak(utterance)
        logger.debug("Replay TTS for word='\(current.targetWord, privacy: .private)'")
    }

    // MARK: - Scoring helpers

    /// Interim score for a single wrong/intermediate attempt. Used so that the UI
    /// can render a partial "almost there" signal while more attempts remain.
    private func computeAttemptScore(isCorrect: Bool, attempts: Int) -> Float {
        guard isCorrect else { return 0.0 }
        switch attempts {
        case 1:  return 1.0
        case 2:  return 0.66
        default: return 0.33
        }
    }

    /// Final, session-level adaptive score factoring in first-try hit-rate and
    /// streak bonus. Clamped to `[0.0, 1.0]`.
    private func computeSessionScore() -> Float {
        let answered = max(firstTryAnswered, 1)
        let baseHitRate = Float(firstTryCorrect) / Float(answered)
        let streakBonus: Float = {
            if maxStreak >= streakThresholdLarge { return streakBonusLarge }
            if maxStreak >= streakThresholdSmall { return streakBonusSmall }
            return 0.0
        }()
        let raw = baseHitRate + streakBonus
        return min(1.0, max(0.0, raw))
    }

    private func updateStreak(correct: Bool) {
        if correct {
            currentStreak += 1
            maxStreak = max(maxStreak, currentStreak)
        } else {
            currentStreak = 0
        }
    }

    private func recordQuestionAttempt(
        correct: Bool,
        attemptNumber: Int,
        responseTimeMs: Int?
    ) {
        guard let current = currentRound else { return }
        var stats = questionStats[current.id] ?? QuestionStats(questionId: current.id)
        stats.attempts += 1
        if let ms = responseTimeMs { stats.responseTimeMs = ms }
        if correct {
            stats.solved = true
            if attemptNumber == 1 && !isRetryPass {
                firstTryCorrect += 1
            }
            totalCorrect += 1
        }
        questionStats[current.id] = stats

        if attemptNumber == 1 && !isRetryPass {
            firstTryAnswered += 1
        }
        totalAnswered += 1
    }

    // MARK: - Hints

    /// Short, child-friendly acoustic cue shown after a wrong tap or on retry pass.
    private func generateHint(for word: String, soundGroup: String) -> String {
        let firstChar = word.prefix(1).uppercased()
        switch soundGroup {
        case "whistling":
            return String(localized: "Слушай звук «\(firstChar)» в начале слова!")
        case "hissing":
            return String(localized: "Обрати внимание на шипящий звук!")
        case "sonants":
            return String(localized: "Слышишь звук «\(firstChar)»?")
        case "velar":
            return String(localized: "Прислушайся к звуку «\(firstChar)» — он в горле.")
        default:
            return String(localized: "Попробуй ещё раз!")
        }
    }

    // MARK: - Content loading

    private func fetchCandidates(for sound: String) async -> [ContentItem] {
        let packId = Self.canonicalPackId(for: sound)
        do {
            let pack = try await contentService.loadPack(id: packId)
            if !pack.items.isEmpty { return pack.items }
        } catch {
            logger.notice("Pack \(packId) unavailable, falling back to defaults: \(error.localizedDescription)")
        }
        return Self.defaultItems(for: sound)
    }

    private static func canonicalPackId(for sound: String) -> String {
        let latin: String
        switch sound.lowercased() {
        case "с", "s":  latin = "s"
        case "з", "z":  latin = "z"
        case "ц", "c":  latin = "ts"
        case "ш", "sh": latin = "sh"
        case "ж", "zh": latin = "zh"
        case "ч", "ch": latin = "ch"
        case "щ", "shch": latin = "shch"
        case "р", "r":  latin = "r"
        case "л", "l":  latin = "l"
        case "к", "k":  latin = "k"
        case "г", "g":  latin = "g"
        case "х", "h":  latin = "h"
        default:        latin = "s"
        }
        return "sound_\(latin)_v1"
    }

    /// Maps a raw sound code to one of the 4 therapy groups the scoring models use.
    private static func resolveSoundGroup(for sound: String) -> String {
        switch sound.lowercased() {
        case "с", "з", "ц", "s", "z", "ts", "c":
            return "whistling"
        case "ш", "ж", "ч", "щ", "sh", "zh", "ch", "shch":
            return "hissing"
        case "р", "л", "рь", "ль", "r", "l":
            return "sonants"
        case "к", "г", "х", "k", "g", "h":
            return "velar"
        default:
            return "whistling"
        }
    }

    private static func defaultItems(for sound: String) -> [ContentItem] {
        let words = fallbackWords(for: sound)
        return words.enumerated().map { idx, w in
            ContentItem(
                id: "default-\(sound)-\(idx)",
                word: w,
                imageAsset: nil,
                audioAsset: nil,
                hint: nil,
                stage: .wordInit,
                difficulty: 1
            )
        }
    }

    // MARK: - Question catalog

    /// Expanded catalog — 12+ words per sound group — used when the content pack
    /// is too small to produce enough distinct questions.
    private static func fallbackWords(for sound: String) -> [String] {
        switch sound.lowercased() {
        case "с", "s":
            return ["сок", "сумка", "сад", "сова", "санки", "сыр", "слон",
                    "самолёт", "собака", "солнце", "свет", "суп"]
        case "з", "z":
            return ["заяц", "зонт", "зубы", "замок", "змея", "звезда",
                    "зима", "зеркало", "завод", "закат", "земля", "зерно"]
        case "ц", "c":
            return ["цапля", "цветок", "цирк", "царь", "цепь", "цыплёнок",
                    "цифра", "центр", "целый", "цвет", "царица", "цитрус"]
        case "ш", "sh":
            return ["шар", "шуба", "шапка", "школа", "шкаф", "шишка",
                    "шмель", "шоколад", "шорты", "шипы", "штора", "шум"]
        case "ж", "zh":
            return ["жук", "жираф", "жаба", "желудь", "жилет", "жало",
                    "жасмин", "жеребёнок", "жемчуг", "женщина", "жюри", "жар"]
        case "ч", "ch":
            return ["чайник", "часы", "чашка", "черешня", "чеснок", "червяк",
                    "чемодан", "чебурек", "чердак", "челюсть", "человек", "чудо"]
        case "щ", "shch":
            return ["щенок", "щука", "щит", "щётка", "щавель", "щегол",
                    "щепка", "щипцы", "щеколда", "щёки", "щебень", "щедрый"]
        case "р", "r":
            return ["рак", "роза", "рыба", "радуга", "ракета", "рука",
                    "рубашка", "робот", "ручей", "рыцарь", "рябина", "ромашка"]
        case "л", "l":
            return ["лак", "лодка", "ложка", "луна", "лампа", "лиса",
                    "лыжи", "лето", "лев", "лошадь", "лес", "лилия"]
        case "к", "k":
            return ["кот", "кубик", "книга", "куст", "кольцо", "корова",
                    "касса", "клоун", "каска", "кулак", "крыша", "карта"]
        case "г", "g":
            return ["гусь", "гора", "гриб", "город", "голубь", "гитара",
                    "газета", "гном", "горох", "губы", "гвоздика", "глобус"]
        case "х", "h":
            return ["хлеб", "халат", "холм", "хобот", "хомяк", "храм",
                    "художник", "хурма", "хоккей", "хвоя", "хлопок", "хор"]
        default:
            return ["мама", "папа", "дом", "мир", "свет", "книга", "кот",
                    "сад", "лето", "лес", "роза", "ромашка"]
        }
    }

    /// Builds up to `sessionLength` distinct questions for the given sound. Each
    /// question has 4 choices (1 correct + 3 distractors). Distractors are
    /// sampled from *other* sound groups so the child's ear has a clear acoustic
    /// contrast.
    private static func buildQuestions(
        packItems: [ContentItem],
        soundTarget: String,
        soundGroup: String,
        difficulty: Int,
        sessionLength: Int
    ) -> [Question] {
        let packWords = packItems.map { $0.word }.filter { !$0.isEmpty }
        let catalogWords = fallbackWords(for: soundTarget)
        var targets = Array((packWords + catalogWords).uniqued().prefix(sessionLength))
        if targets.isEmpty {
            targets = Array(catalogWords.prefix(sessionLength))
        }
        if targets.count < 2 {
            // Guarantee at least two rounds so the session isn't degenerate.
            targets.append(contentsOf: fallbackWords(for: "").prefix(2))
        }

        let distractorPool = Self.distractorPool(excluding: soundTarget)
        let optionCount = max(2, min(4, 2 + difficulty))

        return targets.enumerated().map { idx, word in
            var used: Set<String> = [word]
            var choices: [Question.Choice] = [
                Question.Choice(id: "q\(idx)-correct", word: word, imageAsset: nil)
            ]
            for distractor in distractorPool.shuffled() {
                if choices.count >= optionCount { break }
                guard !used.contains(distractor) else { continue }
                used.insert(distractor)
                choices.append(
                    Question.Choice(id: "q\(idx)-d\(choices.count)", word: distractor, imageAsset: nil)
                )
            }
            // Pad with repeats if the distractor pool is too small.
            while choices.count < optionCount {
                let filler = catalogWords.first(where: { !used.contains($0) }) ?? word
                used.insert(filler)
                choices.append(
                    Question.Choice(id: "q\(idx)-pad\(choices.count)", word: filler, imageAsset: nil)
                )
            }
            choices.shuffle()
            let correctIndex = choices.firstIndex(where: { $0.word == word }) ?? 0
            return Question(
                id: UUID(),
                targetWord: word,
                soundGroup: soundGroup,
                choices: choices,
                correctIndex: correctIndex,
                audioAsset: nil
            )
        }
    }

    /// Mix of words from *other* sound groups — good acoustic distractors.
    private static func distractorPool(excluding sound: String) -> [String] {
        let allSounds = ["с", "ш", "ж", "р", "л", "к", "г", "з"]
        var pool: [String] = []
        for other in allSounds where other != sound.lowercased() {
            pool.append(contentsOf: fallbackWords(for: other).prefix(4))
        }
        return pool.uniqued()
    }

    // MARK: - Internal models

    /// A single "listen and choose" question — one target word and several choices.
    private struct Question: Sendable {
        struct Choice: Sendable {
            let id: String
            let word: String
            let imageAsset: String?
        }
        let id: UUID
        let targetWord: String
        let soundGroup: String
        var choices: [Choice]
        let correctIndex: Int
        let audioAsset: String?
    }

    /// Per-question bookkeeping surfaced to the parent layer via scoring.
    private struct QuestionStats {
        let questionId: UUID
        var attempts: Int = 0
        var solved: Bool = false
        var responseTimeMs: Int?
        var lastServedAt: Date?
    }
}

// MARK: - Array.uniqued helper

private extension Array where Element: Hashable {
    /// Returns the array with duplicates removed, preserving order.
    func uniqued() -> [Element] {
        var seen: Set<Element> = []
        var out: [Element] = []
        out.reserveCapacity(count)
        for element in self where seen.insert(element).inserted {
            out.append(element)
        }
        return out
    }
}
