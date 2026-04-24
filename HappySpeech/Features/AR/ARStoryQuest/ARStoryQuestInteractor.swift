import Foundation
import OSLog

// MARK: - ARStoryQuestBusinessLogic

@MainActor
protocol ARStoryQuestBusinessLogic: AnyObject {
    func handle(_ request: ARStoryQuestRequest) async
}

// MARK: - ARStoryQuestInteractor
//
// Ведёт 8-шаговый квест: загружает сценарий, запускает/останавливает запись,
// оценивает произношение по transcript + confidence, двигает прогресс.
// Взаимодействует с `AudioService` (запись) и `ASRService` (транскрипция).
// Haptic-feedback даётся через `HapticService`. UI-звуки — через `SoundService`.

@MainActor
final class ARStoryQuestInteractor: ARStoryQuestBusinessLogic {

    // MARK: - Collaborators

    private let presenter: ARStoryQuestPresenter
    private let audioService: any AudioService
    private let asrService: any ASRService
    private let hapticService: any HapticService
    private let soundService: any SoundServiceProtocol
    private let analytics: any AnalyticsService
    private let router: ARStoryQuestRouter

    // MARK: - State

    private var script: QuestScript
    private var currentStepIndex: Int = 0
    private var stepScores: [Float] = []
    private var isListening: Bool = false
    private var listeningTask: Task<Void, Never>?

    /// Порог, выше которого попытка считается «пройденной».
    private let passThreshold: Float = 0.6
    /// Порог confidence WhisperKit, гарантирующий zaчёт даже при расхождении слов.
    private let highConfidenceThreshold: Float = 0.85

    // MARK: - Init

    init(
        presenter: ARStoryQuestPresenter,
        router: ARStoryQuestRouter,
        container: AppContainer,
        script: QuestScript = .spaceAdventure
    ) {
        self.presenter = presenter
        self.router = router
        self.audioService = container.audioService
        self.asrService = container.asrService
        self.hapticService = container.hapticService
        self.soundService = container.soundService
        self.analytics = container.analyticsService
        self.script = script
    }

    // MARK: - Request handling

    func handle(_ request: ARStoryQuestRequest) async {
        switch request {
        case let .loadQuest(script):
            await loadQuest(script)

        case .startListening:
            await startListening()

        case .stopListening:
            await stopListening()

        case let .submitAttempt(transcript, confidence):
            await evaluateAttempt(transcript: transcript, confidence: confidence)

        case .advanceStep:
            await advanceStep()

        case .restartQuest:
            await restartQuest()

        case .dismiss:
            listeningTask?.cancel()
            if audioService.isRecording {
                _ = try? await audioService.stopRecording()
            }
            router.routeBack()
        }
    }

    // MARK: - Load

    private func loadQuest(_ newScript: QuestScript) async {
        self.script = newScript
        self.currentStepIndex = 0
        self.stepScores = []

        guard let first = newScript.steps.first else {
            presenter.present(.error(message: String(localized: "ar.quest.error.emptyScript")))
            return
        }

        HSLogger.ar.info("ARStoryQuest loaded \(newScript.questId, privacy: .public) steps=\(newScript.steps.count)")
        analytics.track(event: AnalyticsEvent(
            name: "ar_story_quest.started",
            parameters: ["questId": newScript.questId]
        ))

        presenter.present(.questLoaded(script: newScript, currentStep: first))
    }

    // MARK: - Listening pipeline

    private func startListening() async {
        guard !isListening else { return }
        guard let step = currentStep else { return }

        // Пытаемся запросить микрофон, если ещё не выдан.
        if !audioService.isPermissionGranted {
            let granted = await audioService.requestPermission()
            if !granted {
                presenter.present(.error(message: String(localized: "ar.quest.error.micDenied")))
                return
            }
        }

        do {
            try await audioService.startRecording()
            isListening = true
            hapticService.selection()
            soundService.playUISound(.tap)
            presenter.present(.listeningStarted)
            HSLogger.ar.debug("ARStoryQuest listening for step=\(step.stepNumber)")
        } catch {
            HSLogger.ar.error("ARStoryQuest startRecording failed: \(error.localizedDescription)")
            presenter.present(.error(message: String(localized: "ar.quest.error.recordFailed")))
        }
    }

    private func stopListening() async {
        guard isListening else { return }
        isListening = false
        presenter.present(.listeningStopped)

        do {
            let url = try await audioService.stopRecording()
            let asr = try await asrService.transcribe(url: url)
            await evaluateAttempt(transcript: asr.transcript, confidence: Float(asr.confidence))
        } catch {
            HSLogger.ar.error("ARStoryQuest stopRecording/transcribe failed: \(error.localizedDescription)")
            // Fallback: даём фиктивный балл, чтобы не ломать прогресс ребёнка
            let fallbackScore: Float = 0.55
            await evaluateAttempt(transcript: "", confidence: fallbackScore)
        }
    }

    // MARK: - Scoring

    private func evaluateAttempt(transcript: String, confidence: Float) async {
        guard let step = currentStep else { return }

        let result = scoreAttempt(transcript: transcript, target: step.targetWord, confidence: confidence)
        stepScores.append(result.score)

        if result.passed {
            hapticService.notification(.success)
            soundService.playUISound(.correct)
        } else {
            hapticService.notification(.warning)
            soundService.playUISound(.incorrect)
        }

        HSLogger.ar.info(
            "ARStoryQuest step=\(step.stepNumber) target=\(step.targetWord, privacy: .public) transcript=\(transcript, privacy: .private) score=\(result.score, privacy: .public) passed=\(result.passed)"
        )

        analytics.track(event: AnalyticsEvent(
            name: "ar_story_quest.attempt",
            parameters: [
                "step": String(step.stepNumber),
                "passed": result.passed ? "1" : "0",
                "score": String(format: "%.2f", result.score)
            ]
        ))

        presenter.present(.attemptEvaluated(
            score: result.score,
            passed: result.passed,
            feedback: result.feedback,
            stepEmoji: step.rewardEmoji
        ))
    }

    /// Простая оценка попытки:
    /// - `1.0` если transcript содержит target (case-insensitive)
    /// - `0.85 + bonus` если совпадают первые 2 буквы + confidence ≥ 0.85
    /// - `0.65` если только первые 2 буквы совпадают
    /// - `0.4` если overlap слогов > 50%
    /// - иначе — `max(0.3, confidence × 0.5)`
    private func scoreAttempt(
        transcript: String,
        target: String,
        confidence: Float
    ) -> (score: Float, passed: Bool, feedback: String) {
        let cleanTranscript = transcript
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTarget = target
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanTarget.isEmpty else {
            return (0, false, String(localized: "ar.quest.feedback.tryAgain"))
        }

        // 1. Точное совпадение / содержание
        if !cleanTranscript.isEmpty && cleanTranscript.contains(cleanTarget) {
            return (1.0, true, String(localized: "ar.quest.feedback.perfect"))
        }

        // 2. Первые 2 буквы совпадают + хорошая уверенность
        let prefixMatch = sharedPrefixLength(cleanTranscript, cleanTarget) >= 2
        if prefixMatch && confidence >= highConfidenceThreshold {
            return (0.9, true, String(localized: "ar.quest.feedback.great"))
        }

        // 3. Высокая уверенность модели — zачёт с бонусом (для MVP когда Mock ASR)
        if confidence >= highConfidenceThreshold && !cleanTranscript.isEmpty {
            return (0.85, true, String(localized: "ar.quest.feedback.good"))
        }

        // 4. Первые 2 буквы совпадают — пограничный zачёт
        if prefixMatch {
            return (0.65, true, String(localized: "ar.quest.feedback.good"))
        }

        // 5. Частичное совпадение по слогам
        let overlap = syllableOverlap(cleanTranscript, cleanTarget)
        if overlap >= 0.5 {
            return (0.55, false, String(localized: "ar.quest.feedback.close"))
        }

        // 6. Для пустого transcript — используем confidence как hint
        if cleanTranscript.isEmpty {
            let score = max(0.3, confidence * 0.5)
            return (score, score >= passThreshold, String(localized: "ar.quest.feedback.tryAgain"))
        }

        return (0.35, false, String(localized: "ar.quest.feedback.tryAgain"))
    }

    private func sharedPrefixLength(_ a: String, _ b: String) -> Int {
        var count = 0
        for (c1, c2) in zip(a, b) {
            if c1 == c2 { count += 1 } else { break }
        }
        return count
    }

    private func syllableOverlap(_ transcript: String, _ target: String) -> Float {
        guard !transcript.isEmpty, !target.isEmpty else { return 0 }
        let vowels: Set<Character> = ["а", "е", "ё", "и", "о", "у", "ы", "э", "ю", "я"]
        let transcriptChars = Set(transcript.filter { vowels.contains($0) })
        let targetChars = Set(target.filter { vowels.contains($0) })
        guard !targetChars.isEmpty else { return 0 }
        let shared = transcriptChars.intersection(targetChars).count
        return Float(shared) / Float(targetChars.count)
    }

    // MARK: - Advance / finish

    private func advanceStep() async {
        let nextIndex = currentStepIndex + 1
        if nextIndex >= script.steps.count {
            await completeQuest()
            return
        }
        currentStepIndex = nextIndex
        let step = script.steps[nextIndex]
        let isLast = nextIndex == script.steps.count - 1

        soundService.playUISound(.transitionNext)
        hapticService.impact(.light)

        presenter.present(.stepAdvanced(step: step, isLast: isLast))
        HSLogger.ar.debug("ARStoryQuest advanced to step=\(step.stepNumber)")
    }

    private func completeQuest() async {
        guard !stepScores.isEmpty else { return }
        let total = stepScores.reduce(0, +) / Float(stepScores.count)
        let stars = starsForScore(total)

        hapticService.notification(.success)
        soundService.playUISound(.complete)

        HSLogger.ar.info("ARStoryQuest completed avg=\(total, privacy: .public) stars=\(stars)")

        analytics.track(event: AnalyticsEvent(
            name: "ar_story_quest.completed",
            parameters: [
                "questId": script.questId,
                "avgScore": String(format: "%.2f", total),
                "stars": String(stars)
            ]
        ))

        presenter.present(.questCompleted(totalScore: total, starsEarned: stars))
        router.routeToRewardCelebration(stars: stars, totalScore: total)
    }

    private func starsForScore(_ score: Float) -> Int {
        switch score {
        case 0.85...:       return 3
        case 0.65..<0.85:   return 2
        case 0.45..<0.65:   return 1
        default:            return 0
        }
    }

    private func restartQuest() async {
        currentStepIndex = 0
        stepScores = []
        isListening = false
        guard let first = script.steps.first else { return }
        presenter.present(.questLoaded(script: script, currentStep: first))
    }

    // MARK: - Helpers

    private var currentStep: QuestStep? {
        guard script.steps.indices.contains(currentStepIndex) else { return nil }
        return script.steps[currentStepIndex]
    }
}
