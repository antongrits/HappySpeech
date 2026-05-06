import Foundation
import OSLog

// MARK: - BreathingExtendedInteractor
//
// Composition (not subclass) of BreathingInteractor logic, adapted for the
// Stuttering module's "Длинный выдох" (BreathingTreeView) exercise.
// Scene is `.tree`, goals match StutteringDifficulty thresholds.
//
// Упражнение: ДДТ — Диафрагмальное Дыхательное Тренирование.
// Техника 4-7-8: вдох 4 сек → задержка 7 сек → выдох 8 сек.
// Ребёнок «заполняет» дерево листьями, выдыхая ровно и долго.
//
// Adaptive difficulty:
//   easy   → 3 раунда, выдох 3 сек, порог RMS 0.05
//   medium → 5 раундов, выдох 5 сек, порог RMS 0.07
//   hard   → 7 раундов, выдох 7 сек, порог RMS 0.09
//
// Score calculation:
//   Per round: score = (successfulFrames / requiredFrames) * 100
//   Session:   average of all round scores → 0–100

@MainActor
final class BreathingExtendedInteractor {

    // MARK: - Display state

    @Observable
    final class Display {
        var treeProgress: Float = 0       // 0.0–1.0 leaf fill
        var isPlaying: Bool = false
        var roundsComplete: Int = 0
        var roundsRequired: Int = 5
        var showSuccess: Bool = false
        var mascotMood: MascotMood = .idle
        var instruction: String = ""
        var waveformLevels: [Float] = []
        var currentPhase: BreathingPhase = .idle
        var phaseCountdown: Int = 0       // секунды до конца текущей фазы
        var sessionScore: Int = 0         // 0–100
        var roundScores: [Int] = []
        var breathingTip: String = ""
    }

    let display = Display()

    // MARK: - Core breathing interactor (composition)

    private let coreInteractor: BreathingInteractor
    private let audioWorker: BreathingAudioWorker
    private let hapticWorker: any BreathingHapticWorkerProtocol
    private let logger = HSLogger.audio

    // MARK: - Session state

    private var difficulty: StutteringDifficulty = .easy
    private var totalProgress: Float = 0
    private var roundStartProgress: Float = 0

    // 4-7-8 phase tracking
    private var phaseTask: Task<Void, Never>?
    private var roundStartTime: Date?
    private var successfulFramesThisRound: Int = 0
    private var totalFramesThisRound: Int = 0

    // Adaptive threshold — зависит от сложности
    private var rmsThreshold: Float = 0.05

    // MARK: - DDT parameters по сложности

    private var inhaleSeconds: Int { 4 }

    private var holdSeconds: Int {
        switch difficulty {
        case .easy:   return 4
        case .medium: return 6
        case .hard:   return 7
        }
    }

    private var exhaleSeconds: Int {
        switch difficulty {
        case .easy:   return 3
        case .medium: return 5
        case .hard:   return 8
        }
    }

    // MARK: - Init

    init() {
        let audio = BreathingAudioWorker()
        let haptic = MockBreathingHapticWorker()
        self.audioWorker = audio
        self.hapticWorker = haptic
        self.coreInteractor = BreathingInteractor(
            audioWorker: audio,
            hapticWorker: haptic
        )
    }

    // MARK: - Public API

    func startSession(difficulty: StutteringDifficulty) async {
        self.difficulty = difficulty
        display.roundsRequired = difficulty.roundCount
        display.roundsComplete = 0
        display.roundScores = []
        display.treeProgress = 0
        display.showSuccess = false
        display.sessionScore = 0
        display.instruction = String(localized: "stuttering.exercise.breathing.subtitle")
        display.mascotMood = .happy
        display.breathingTip = breathingTip(for: difficulty)

        rmsThreshold = rmsThresholdForDifficulty(difficulty)
        logger.info("BreathingExtended: startSession difficulty=\(difficulty.rawValue, privacy: .public)")

        await beginRound()
    }

    func cancel() async {
        phaseTask?.cancel()
        await coreInteractor.cancel()
        display.isPlaying = false
        display.currentPhase = .idle
        display.mascotMood = .idle
        logger.info("BreathingExtended: session cancelled")
    }

    // MARK: - Round management

    private func beginRound() async {
        display.isPlaying = true
        display.currentPhase = .inhale
        roundStartProgress = display.treeProgress
        successfulFramesThisRound = 0
        totalFramesThisRound = 0
        roundStartTime = Date()

        await coreInteractor.beginGame(
            activityId: "stuttering_breathing_\(difficulty.rawValue)",
            difficulty: breathingDifficulty
        )

        let presenterAdapter = BreathingExtendedPresenterAdapter { [weak self] state, progress, amplitude in
            Task { @MainActor [weak self] in
                self?.handleCoreUpdate(state: state, progress: progress, amplitude: amplitude)
            }
        }
        coreInteractor.presenter = presenterAdapter
        await coreInteractor.advanceTutorial()
        await coreInteractor.advanceTutorial()
        await coreInteractor.advanceTutorial()

        // Запускаем 4-7-8 фазовый таймер
        await run478PhaseSequence()
    }

    // MARK: - 4-7-8 Phase Sequence

    /// Запускает последовательность фаз дыхания 4-7-8.
    /// Обновляет display.currentPhase и display.phaseCountdown.
    private func run478PhaseSequence() async {
        phaseTask?.cancel()
        phaseTask = Task { [weak self] in
            guard let self else { return }
            await self.runPhase(.inhale, seconds: self.inhaleSeconds)
            guard !Task.isCancelled else { return }
            await self.runPhase(.hold, seconds: self.holdSeconds)
            guard !Task.isCancelled else { return }
            await self.runPhase(.exhale, seconds: self.exhaleSeconds)
        }
        await phaseTask?.value
    }

    private func runPhase(_ phase: BreathingPhase, seconds: Int) async {
        display.currentPhase = phase
        display.instruction = instructionForPhase(phase)
        logger.debug("BreathingExtended: phase=\(phase.rawValue, privacy: .public) seconds=\(seconds, privacy: .public)")

        for remaining in stride(from: seconds, through: 1, by: -1) {
            display.phaseCountdown = remaining
            try? await Task.sleep(for: .seconds(1))
            if Task.isCancelled { return }
        }
        display.phaseCountdown = 0
    }

    private func instructionForPhase(_ phase: BreathingPhase) -> String {
        switch phase {
        case .inhale:
            return String(localized: "breathing.phase.inhale.instruction")
        case .hold:
            return String(localized: "breathing.phase.hold.instruction")
        case .exhale:
            return String(localized: "breathing.phase.exhale.instruction")
        case .idle:
            return String(localized: "stuttering.exercise.breathing.subtitle")
        }
    }

    // MARK: - State handling

    private func handleCoreUpdate(state: BreathingGameState, progress: Float, amplitude: Float) {
        // Обновляем waveform
        var levels = display.waveformLevels
        levels.append(amplitude)
        if levels.count > 40 { levels.removeFirst(levels.count - 40) }
        display.waveformLevels = levels

        // Счётчик успешных кадров (RMS выше порога во время выдоха)
        totalFramesThisRound += 1
        if display.currentPhase == .exhale, amplitude >= rmsThreshold {
            successfulFramesThisRound += 1
        }

        // Прогресс дерева (0..1 по всем раундам)
        let roundFraction = Float(display.roundsComplete) / Float(max(1, display.roundsRequired))
        let roundProgress = progress * (1.0 / Float(max(1, display.roundsRequired)))
        display.treeProgress = min(1.0, roundFraction + roundProgress)

        switch state {
        case .summary(let result):
            phaseTask?.cancel()
            if result.didSucceed {
                let roundScore = calculateRoundScore()
                completeRound(score: roundScore)
            } else {
                // Неудачный раунд: откат прогресса, повтор
                display.treeProgress = roundStartProgress
                display.mascotMood = .happy
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    try? await Task.sleep(for: .seconds(1.0))
                    await self.beginRound()
                }
            }
        case .playing:
            display.mascotMood = .happy
        case .warmUp:
            display.mascotMood = .thinking
        default:
            break
        }
    }

    // MARK: - Score Calculation

    /// Вычисляет score раунда на основе % успешных кадров во время выдоха.
    private func calculateRoundScore() -> Int {
        let exhaleFrames = max(1, Int(Float(exhaleSeconds) * 20)) // ~20 кадров/сек
        let score = min(100, Int(Float(successfulFramesThisRound) / Float(exhaleFrames) * 100))
        logger.info(
            "BreathingExtended round score: \(score, privacy: .public)% (ok=\(self.successfulFramesThisRound, privacy: .public)/\(exhaleFrames, privacy: .public))"
        )
        return score
    }

    /// Вычисляет финальный session score как среднее по раундам.
    private func calculateSessionScore(roundScores: [Int]) -> Int {
        guard !roundScores.isEmpty else { return 0 }
        return roundScores.reduce(0, +) / roundScores.count
    }

    private func completeRound(score: Int) {
        display.roundScores.append(score)
        display.roundsComplete += 1
        display.mascotMood = .celebrating
        logger.info(
            "BreathingExtended: round \(self.display.roundsComplete)/\(self.display.roundsRequired) score=\(score, privacy: .public)"
        )

        if display.roundsComplete >= display.roundsRequired {
            let sessionScore = calculateSessionScore(roundScores: display.roundScores)
            display.sessionScore = sessionScore
            display.treeProgress = 1.0
            display.showSuccess = true
            display.isPlaying = false
            display.currentPhase = .idle
            logger.info("BreathingExtended: session complete sessionScore=\(sessionScore, privacy: .public)")
        } else {
            Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: .seconds(1.5))
                self.display.mascotMood = .happy
                await self.beginRound()
            }
        }
    }

    // MARK: - Adaptive threshold mapping

    private func rmsThresholdForDifficulty(_ diff: StutteringDifficulty) -> Float {
        switch diff {
        case .easy:   return 0.05
        case .medium: return 0.07
        case .hard:   return 0.09
        }
    }

    // MARK: - Breathing tips (методологические подсказки)

    private func breathingTip(for difficulty: StutteringDifficulty) -> String {
        switch difficulty {
        case .easy:
            return String(localized: "breathing.tip.easy")
        case .medium:
            return String(localized: "breathing.tip.medium")
        case .hard:
            return String(localized: "breathing.tip.hard")
        }
    }

    // MARK: - Breathing difficulty mapping

    private var breathingDifficulty: BreathingDifficulty {
        switch difficulty {
        case .easy:   return .easy
        case .medium: return .medium
        case .hard:   return .hard
        }
    }
}

// MARK: - BreathingPhase

/// Фаза дыхательного упражнения (4-7-8 техника).
enum BreathingPhase: String {
    case idle
    case inhale    // вдох
    case hold      // задержка
    case exhale    // выдох
}

// MARK: - BreathingExtendedPresenterAdapter

/// Bridges BreathingInteractor output into the extended interactor callback.
@MainActor
private final class BreathingExtendedPresenterAdapter: BreathingPresentationLogic {

    typealias UpdateCallback = @MainActor (BreathingGameState, Float, Float) -> Void

    private let onUpdate: UpdateCallback

    init(onUpdate: @escaping UpdateCallback) {
        self.onUpdate = onUpdate
    }

    func presentLoadSession(_ response: BreathingModels.LoadSession.Response) {}

    func presentSubmitAttempt(_ response: BreathingModels.SubmitAttempt.Response) {}

    func presentUpdateSignal(_ response: BreathingModels.UpdateSignal.Response) {
        onUpdate(response.state, response.progress, response.amplitude)
    }

    func presentFinish(_ response: BreathingModels.Finish.Response) {
        onUpdate(.summary(result: response.result), 1.0, 0)
    }
}
