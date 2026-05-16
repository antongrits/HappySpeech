import Accelerate
import AVFoundation
import Foundation
import OSLog

// MARK: - SoftOnsetInteractor
//
// Управляет упражнением «Мягкая голосоподача» (Soft Onset) — ключевой техникой
// при работе с заиканием. Цель: ребёнок учится начинать слово с мягкого,
// плавного голосового начала, без резкого «атаки».
//
// Классификация атаки:
//   soft       → RMS растёт медленно (attack time > threshold_soft мс)
//   borderline → RMS в допустимом диапазоне
//   hard       → RMS нарастает слишком быстро (атака > порог)
//
// Scoring:
//   В каждом слове может быть до maxAttempts попыток.
//   Финальный score = wordsSucceeded / totalWords * 100.
//
// Progression tracking:
//   Сессии сохраняются через DiaryStorageWorkerProtocol.
//   Успех > 80% открывает следующий уровень сложности.
//
// 4 уровня сложности:
//   easy   → короткие (1-слог) открытые слоги, порог атаки 100 мс
//   medium → двусложные слова, порог атаки 80 мс
//   hard   → трёхсложные слова, порог атаки 60 мс
//
// Adaptive difficulty:
//   После 3 сессий с score ≥ 85% → автоматически предлагать следующий уровень.

@MainActor
final class SoftOnsetInteractor {

    // MARK: - Display state

    @Observable
    final class Display {
        var currentWord: String = ""
        var lanternState: LanternState = .off
        var waveformColorMode: OnsetColorMode = .neutral
        var feedbackText: String? = nil
        var feedbackStyle: FeedbackStyle = .neutral
        var attemptNumber: Int = 1
        var maxAttempts: Int = 5
        var isListening: Bool = false
        var isRecording: Bool = false
        var waveformLevels: [Float] = []
        var sessionComplete: Bool = false
        var wordsSucceeded: Int = 0
        var totalWords: Int = 5
        var sessionScore: Int = 0         // 0–100
        var showDifficultyUpgrade: Bool = false
        var difficultyLabel: String = ""
        var progressHistory: [SessionProgressPoint] = []
        var attackTimeMs: Float = 0        // для диагностики/отображения
    }

    let display = Display()

    // MARK: - Dependencies

    private let audioWorker: any BreathingAudioWorkerProtocol
    private let analyzerWorker: any FluencyAnalyzerWorkerProtocol
    private let hapticService: any HapticService
    private let logger = HSLogger.audio

    // MARK: - Session state

    private var difficulty: StutteringDifficulty = .easy
    private var wordList: [String] = []
    private var wordIndex: Int = 0
    private var attemptNumber: Int = 1
    private let maxAttempts = 5
    private let wordsPerSession = 5

    // RMS capture buffer for attack time analysis
    private var rmsBuffer: [Float] = []
    private var isCapturingOnset: Bool = false
    private let captureWindowTicks = 10  // 10 × 50ms = 500ms

    // MARK: - Progression tracking

    /// Последние сессии для определения необходимости повышения сложности.
    private var recentSessionScores: [Int] = []
    private let scoresToCheckUpgrade = 3
    private let upgradeThreshold = 85

    // MARK: - Session result tracking

    private var wordAttemptCounts: [Int: Int] = [:]   // wordIndex → number of attempts used

    // MARK: - Init

    init(
        audioWorker: any BreathingAudioWorkerProtocol = BreathingAudioWorker(),
        analyzerWorker: any FluencyAnalyzerWorkerProtocol = FluencyAnalyzerWorker(),
        hapticService: any HapticService = LiveHapticService()
    ) {
        self.audioWorker = audioWorker
        self.analyzerWorker = analyzerWorker
        self.hapticService = hapticService
    }

    // MARK: - Public API

    func startSession(difficulty: StutteringDifficulty) async {
        self.difficulty = difficulty
        display.maxAttempts = maxAttempts
        display.totalWords = wordsPerSession
        display.wordsSucceeded = 0
        display.sessionComplete = false
        display.sessionScore = 0
        display.showDifficultyUpgrade = false
        display.difficultyLabel = difficultyLabel(for: difficulty)
        wordAttemptCounts = [:]

        wordList = SoftOnsetWords.words(for: difficulty).shuffled().prefix(wordsPerSession).map { $0 }
        wordIndex = 0
        attemptNumber = 1
        display.attemptNumber = 1
        loadCurrentWord()
        logger.info("SoftOnset: startSession difficulty=\(difficulty.rawValue, privacy: .public) words=\(self.wordList.count, privacy: .public)")
    }

    func startListening() async {
        guard !display.isRecording else { return }
        rmsBuffer.removeAll()
        isCapturingOnset = false
        display.isRecording = true
        display.lanternState = .off
        display.waveformColorMode = .neutral
        display.feedbackText = nil
        display.attackTimeMs = 0
        Task { await hapticService.play(pattern: .buttonTap) }

        let granted = await audioWorker.requestPermission()
        guard granted else {
            display.feedbackText = String(localized: "stuttering.error.mic_permission")
            display.feedbackStyle = .error
            display.isRecording = false
            return
        }

        do {
            try await audioWorker.start(
                onAmplitude: { [weak self] amp in
                    Task { @MainActor [weak self] in self?.handleAmplitude(amp) }
                },
                onInterrupt: { [weak self] in
                    Task { @MainActor [weak self] in self?.stopListening() }
                }
            )
        } catch {
            logger.error("SoftOnsetInteractor: audio start error \(error.localizedDescription, privacy: .public)")
            display.isRecording = false
        }
    }

    func stopListening() {
        audioWorker.stop()
        display.isRecording = false
        analyzeRecording()
    }

    // MARK: - Amplitude handling

    private func handleAmplitude(_ amplitude: Float) {
        var levels = display.waveformLevels
        levels.append(amplitude)
        if levels.count > 40 { levels.removeFirst(levels.count - 40) }
        display.waveformLevels = levels

        let noiseFloor: Float = 0.04
        if amplitude > noiseFloor {
            isCapturingOnset = true
        }
        if isCapturingOnset && rmsBuffer.count < captureWindowTicks {
            rmsBuffer.append(amplitude)
        }
        if rmsBuffer.count >= captureWindowTicks && display.isRecording {
            stopListening()
        }
    }

    // MARK: - Analysis

    private func analyzeRecording() {
        let threshold: Float = attackThresholdForDifficulty(difficulty)
        let (classification, attackTimeMs) = analyzerWorker.classifyOnset(
            rmsBuffer: rmsBuffer,
            threshold: threshold,
            difficulty: difficulty
        )

        display.attackTimeMs = attackTimeMs
        let classStr = String(describing: classification)
        let diffStr = self.difficulty.rawValue
        logger.info(
            "SoftOnset attackMs:\(attackTimeMs, privacy: .public) class:\(classStr, privacy: .public) diff:\(diffStr, privacy: .public)"
        )

        switch classification {
        case .soft:
            display.lanternState = .bright
            display.waveformColorMode = .soft
            display.feedbackText = buildFeedback(classification: .soft, attackMs: attackTimeMs)
            display.feedbackStyle = .success
            display.wordsSucceeded += 1
            Task { await hapticService.play(pattern: .perfectRound) }

        case .borderline:
            display.lanternState = .flicker
            display.waveformColorMode = .borderline
            display.feedbackText = buildFeedback(classification: .borderline, attackMs: attackTimeMs)
            display.feedbackStyle = .warning
            Task { await hapticService.play(pattern: .buttonTap) }

        case .hard:
            display.lanternState = .flicker
            display.waveformColorMode = .hard
            display.feedbackText = buildFeedback(classification: .hard, attackMs: attackTimeMs)
            display.feedbackStyle = .error
            Task { await hapticService.play(pattern: .errorBuzz) }
        }

        advanceAttempt(succeeded: classification == .soft)
    }

    private func buildFeedback(classification: OnsetClassification, attackMs: Float) -> String {
        switch classification {
        case .soft:
            return String(localized: "stuttering.soft_start.feedback.soft")
        case .borderline:
            return String(localized: "stuttering.soft_start.feedback.borderline")
        case .hard:
            return String(localized: "stuttering.soft_start.feedback.hard")
        }
    }

    private func attackThresholdForDifficulty(_ diff: StutteringDifficulty) -> Float {
        switch diff {
        case .easy:   return 0.08
        case .medium: return 0.10
        case .hard:   return 0.12
        }
    }

    private func advanceAttempt(succeeded: Bool) {
        wordAttemptCounts[wordIndex, default: 0] += 1

        if succeeded {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.2))
                self.nextWord()
            }
        } else {
            display.attemptNumber += 1
            attemptNumber += 1
            if attemptNumber > maxAttempts {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.0))
                    self.nextWord()
                }
            }
        }
    }

    private func nextWord() {
        wordIndex += 1
        attemptNumber = 1
        display.attemptNumber = 1
        if wordIndex >= wordList.count {
            finalizeSession()
        } else {
            loadCurrentWord()
            display.lanternState = .off
            display.feedbackText = nil
            display.waveformColorMode = .neutral
        }
    }

    private func loadCurrentWord() {
        guard wordIndex < wordList.count else { return }
        display.currentWord = wordList[wordIndex].uppercased()
    }

    // MARK: - Session finalization

    private func finalizeSession() {
        let score = calculateSessionScore()
        display.sessionScore = score
        display.sessionComplete = true

        recentSessionScores.append(score)
        if recentSessionScores.count > 10 { recentSessionScores.removeFirst() }

        logger.info("SoftOnset: session complete score=\(score, privacy: .public)")

        checkDifficultyUpgrade(score: score)
    }

    private func calculateSessionScore() -> Int {
        guard wordsPerSession > 0 else { return 0 }
        let pct = Double(display.wordsSucceeded) / Double(wordsPerSession) * 100
        return min(100, Int(pct))
    }

    // MARK: - Difficulty upgrade check

    /// Если последние N сессий дают score ≥ upgradeThreshold — предлагаем апгрейд.
    private func checkDifficultyUpgrade(score: Int) {
        guard difficulty != .hard else { return }
        let recent = Array(recentSessionScores.suffix(scoresToCheckUpgrade))
        guard recent.count >= scoresToCheckUpgrade else { return }
        let allAboveThreshold = recent.allSatisfy { $0 >= upgradeThreshold }
        if allAboveThreshold {
            display.showDifficultyUpgrade = true
            logger.info(
                "SoftOnset: difficulty upgrade available (last \(self.scoresToCheckUpgrade, privacy: .public) avg≥\(self.upgradeThreshold, privacy: .public)%)"
            )
        }
    }

    private func difficultyLabel(for diff: StutteringDifficulty) -> String {
        switch diff {
        case .easy:   return String(localized: "stuttering.difficulty.easy")
        case .medium: return String(localized: "stuttering.difficulty.medium")
        case .hard:   return String(localized: "stuttering.difficulty.hard")
        }
    }

    // MARK: - Session Statistics

    /// Статистика текущей сессии: среднее время атаки по словам.
    /// Используется для диагностики прогресса терапии.
    private func buildSessionStatistics() -> SoftOnsetSessionStats {
        let avgAttackMs = display.attackTimeMs
        let successRate = wordsPerSession > 0
            ? Double(display.wordsSucceeded) / Double(wordsPerSession)
            : 0.0

        return SoftOnsetSessionStats(
            totalWords: wordsPerSession,
            wordsSucceeded: display.wordsSucceeded,
            successRate: successRate,
            averageAttackTimeMs: Double(avgAttackMs),
            difficulty: difficulty,
            sessionScore: display.sessionScore
        )
    }

    // MARK: - SessionProgressPoint

    /// Точка прогресса для истории сессий.
    struct SessionProgressPoint: Identifiable, Sendable {
        let id = UUID()
        let date: Date
        let score: Int
        let wordsSucceeded: Int
        let totalWords: Int
    }

    // MARK: - Test hooks

    #if DEBUG
    // swiftlint:disable identifier_name
    /// Прокси к `buildSessionStatistics` для unit-тестов диагностической
    /// статистики сессии. Поведение прод-кода не меняется.
    func _test_buildSessionStatistics() -> SoftOnsetSessionStats {
        buildSessionStatistics()
    }
    // swiftlint:enable identifier_name
    #endif
}

// MARK: - SoftOnsetSessionStats

/// Статистика одной сессии «Мягкой голосоподачи».
struct SoftOnsetSessionStats: Sendable {
    let totalWords: Int
    let wordsSucceeded: Int
    let successRate: Double
    let averageAttackTimeMs: Double
    let difficulty: StutteringDifficulty
    let sessionScore: Int

    /// Классификация результата сессии.
    var resultLevel: ResultLevel {
        switch sessionScore {
        case 85...: return .excellent
        case 60..<85: return .good
        case 40..<60: return .fair
        default: return .needsWork
        }
    }

    enum ResultLevel: String {
        case excellent   = "Отлично"
        case good        = "Хорошо"
        case fair        = "Неплохо"
        case needsWork   = "Продолжаем тренироваться"
    }
}
