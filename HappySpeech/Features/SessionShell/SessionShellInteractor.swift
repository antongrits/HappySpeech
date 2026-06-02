import ActivityKit
import Foundation
import OSLog
import UIKit

// MARK: - SessionShellBusinessLogic

@MainActor
protocol SessionShellBusinessLogic: AnyObject {
    func startSession(_ request: SessionShellModels.StartSession.Request) async
    func completeActivity(_ request: SessionShellModels.CompleteActivity.Request) async
    func pauseSession(_ request: SessionShellModels.PauseSession.Request)
    func resumeSession()
    func skipCurrentActivity() async
    func endSessionEarly() async

    /// Анализирует эмоцию из голоса ребёнка (опционально, on-device, COPPA).
    /// Вызывается играми после попытки, если доступна аудиозапись.
    /// frustrated/sad → ускоряет предложение перерыва.
    func analyzeEmotion(_ request: SessionShellModels.AnalyzeEmotion.Request) async
}

// MARK: - SessionShellBusinessLogic default

extension SessionShellBusinessLogic {
    /// Дефолт — no-op: игры без аудио-захвата не обязаны анализировать эмоцию.
    func analyzeEmotion(_ request: SessionShellModels.AnalyzeEmotion.Request) async {}
}

// MARK: - SessionShellInteractor

/// Orchestrates a full session: loads a route from `AdaptivePlannerService`, passes
/// activities to game children, collects score, and decides when to stop (including
/// fatigue detection based on consecutive errors and session length).
///
/// Fatigue model:
///   * 3 hearts at session start.
///   * Every 3 consecutive incorrect answers (`score < 0.5`) drain 1 heart.
///   * 0 hearts → fatigueDetected, session is offered to end gracefully.
///   * Session also auto-stops at `maxSessionMinutes` of *active* time
///     (excludes accumulated pause time).
@MainActor
final class SessionShellInteractor: SessionShellBusinessLogic {

    var presenter: (any SessionShellPresentationLogic)?

    private let contentService: any ContentService
    private let adaptivePlannerService: any AdaptivePlannerService
    private let sessionRepository: any SessionRepository
    /// Offline-first персистентность + постановка сессии в очередь синка. Опционален —
    /// при `nil` (legacy preview/test) сессия не сохраняется (как было раньше).
    /// В `.live()` подключён `LiveSessionPersistenceCoordinator`.
    private let sessionPersistence: (any SessionPersistenceCoordinating)?
    private let hapticService: any HapticService
    /// Опциональное обнаружение эмоций (on-device, COPPA). Если подключено, голос
    /// ребёнка анализируется после попытки и frustrated/sad ускоряет предложение
    /// перерыва (дренирует сердце усталости). `nil` → поведение без изменений.
    private let emotionDetectionService: (any EmotionDetectionServiceProtocol)?
    private let logger = Logger(subsystem: "ru.happyspeech", category: "SessionShell")

    private var activities: [SessionActivity] = []
    private var currentIndex: Int = 0
    private var sessionStartTime: Date = Date()
    /// Метаданные текущей сессии для построения `SessionDTO` при сохранении.
    private var sessionChildId: String = ""
    private var sessionTargetSound: String = ""
    /// Гард от двойного сохранения: `completeActivity`→`saveSession` и
    /// `onDisappear`→`endSessionEarly`→`saveSession` могут сработать оба.
    private var didSaveSession: Bool = false
    private var errorCount: Int = 0
    private var consecutiveErrors: Int = 0
    private var isPaused: Bool = false
    private var pauseStartTime: Date?
    private var accumulatedPauseSeconds: TimeInterval = 0

    /// 3 hearts → 0. Drained every `errorsPerHeart` consecutive incorrect answers.
    private var fatigueHearts: Int = 3

    /// Подряд обнаруженных негативных эмоций (frustrated/sad). Сбрасывается при
    /// положительной/нейтральной эмоции. Достигнув порога — дренирует сердце.
    private var consecutiveNegativeEmotions: Int = 0

    // MARK: - Fatigue thresholds

    private let maxConsecutiveErrors = 3
    private let errorsPerHeart = 3
    private let initialHearts = 3
    private let maxSessionMinutes: Double = 15

    /// Порог уверенности негативной эмоции, при котором она учитывается.
    private let emotionConfidenceThreshold: Float = 0.6
    /// Сколько подряд негативных эмоций дренируют одно сердце усталости.
    private let negativeEmotionsPerHeart = 2

    // MARK: - Init

    init(
        contentService: any ContentService,
        adaptivePlannerService: any AdaptivePlannerService,
        sessionRepository: any SessionRepository,
        hapticService: any HapticService,
        emotionDetectionService: (any EmotionDetectionServiceProtocol)? = nil,
        sessionPersistence: (any SessionPersistenceCoordinating)? = nil
    ) {
        self.contentService = contentService
        self.adaptivePlannerService = adaptivePlannerService
        self.sessionRepository = sessionRepository
        self.hapticService = hapticService
        self.emotionDetectionService = emotionDetectionService
        self.sessionPersistence = sessionPersistence
    }

    // MARK: - SessionShellBusinessLogic

    func startSession(_ request: SessionShellModels.StartSession.Request) async {
        sessionStartTime = Date()
        accumulatedPauseSeconds = 0
        errorCount = 0
        consecutiveErrors = 0
        currentIndex = 0
        isPaused = false
        fatigueHearts = initialHearts
        consecutiveNegativeEmotions = 0
        didSaveSession = false
        sessionChildId = request.childId
        sessionTargetSound = request.targetSoundId

        let activities = await loadActivities(for: request)
        self.activities = activities

        let totalMinutes = max(activities.count * 2, 1)
        logger.info(
            "Session started: type=\(request.sessionType.rawValue) steps=\(activities.count) hearts=\(self.fatigueHearts)"
        )

        let response = SessionShellModels.StartSession.Response(
            activities: activities,
            totalSteps: activities.count,
            estimatedMinutes: totalMinutes,
            sessionStartTime: sessionStartTime
        )
        await presenter?.presentStartSession(response)

        // Запускаем Live Activity (iOS 16.1+, без COPPA-данных)
        if #available(iOS 16.1, *) {
            await LiveActivityManager.shared.start(
                sessionId: request.childId + "-" + UUID().uuidString,
                lessonTitle: request.targetSoundId,
                soundId: request.targetSoundId,
                totalRounds: activities.count
            )
        }
    }

    func completeActivity(_ request: SessionShellModels.CompleteActivity.Request) async {
        guard currentIndex < activities.count else {
            logger.warning(
                "completeActivity called with currentIndex=\(self.currentIndex) >= activities=\(self.activities.count)"
            )
            return
        }

        let isCorrect = request.score >= 0.5
        let feedback: SessionShellModels.ActivityFeedback = isCorrect ? .correct : .incorrect

        if isCorrect {
            consecutiveErrors = 0
            Task { await hapticService.play(pattern: .celebration) }
        } else {
            consecutiveErrors += 1
            errorCount += request.errorCount
            Task { await hapticService.play(pattern: .wrong) }

            // Каждые `errorsPerHeart` подряд неправильных ответов — минус сердце.
            if consecutiveErrors > 0 && consecutiveErrors % errorsPerHeart == 0 {
                fatigueHearts = max(0, fatigueHearts - 1)
                logger.info("Fatigue heart drained → hearts=\(self.fatigueHearts)")
            }
        }

        activities[currentIndex].isCompleted = true
        activities[currentIndex].score = request.score

        let fatigueDetected = detectFatigue()
        let nextActivity: SessionActivity? = {
            let nextIdx = currentIndex + 1
            guard nextIdx < activities.count else { return nil }
            return activities[nextIdx]
        }()
        currentIndex += 1

        let reward: SessionReward? = request.score >= 0.8 ? .star : nil

        let response = SessionShellModels.CompleteActivity.Response(
            nextActivity: fatigueDetected ? nil : nextActivity,
            isSessionComplete: nextActivity == nil || fatigueDetected,
            earnedReward: reward,
            fatigueDetected: fatigueDetected,
            fatigueHearts: fatigueHearts,
            feedback: feedback
        )
        logger.info(
            "Activity \(request.activityId) score=\(request.score) fatigue=\(fatigueDetected) hearts=\(self.fatigueHearts) done=\(response.isSessionComplete)"
        )

        if response.isSessionComplete {
            await saveSession()
            // Завершаем Live Activity
            if #available(iOS 16.1, *) {
                await LiveActivityManager.shared.end()
            }
        } else {
            // Обновляем Live Activity после каждого раунда
            if #available(iOS 16.1, *) {
                let elapsed = Int(activeElapsedSeconds)
                await LiveActivityManager.shared.update(
                    round: currentIndex,
                    score: Int(avgScoreValue() * 100),
                    elapsed: elapsed,
                    streak: consecutiveErrors == 0 ? (currentIndex - errorCount) : 0
                )
            }
        }
        await presenter?.presentCompleteActivity(response)
    }

    func pauseSession(_ request: SessionShellModels.PauseSession.Request) {
        guard !isPaused else { return }
        isPaused = true
        pauseStartTime = Date()

        let progress = Float(currentIndex) / Float(max(activities.count, 1))
        let response = SessionShellModels.PauseSession.Response(
            currentProgress: progress,
            activeSeconds: activeElapsedSeconds
        )
        presenter?.presentPauseSession(response)
    }

    func resumeSession() {
        guard isPaused, let pauseStart = pauseStartTime else { return }
        accumulatedPauseSeconds += Date().timeIntervalSince(pauseStart)
        pauseStartTime = nil
        isPaused = false
    }

    func skipCurrentActivity() async {
        guard currentIndex < activities.count else { return }
        activities[currentIndex].isCompleted = true
        activities[currentIndex].score = 0
        let skippedId = activities[currentIndex].id
        logger.info("Skipped activity id=\(skippedId)")
        await completeActivity(SessionShellModels.CompleteActivity.Request(
            activityId: skippedId,
            score: 0,
            durationSeconds: 0,
            errorCount: 0
        ))
    }

    func endSessionEarly() async {
        logger.info("Ending session early: \(self.currentIndex)/\(self.activities.count)")
        await saveSession()
        if #available(iOS 16.1, *) {
            await LiveActivityManager.shared.end()
        }
    }

    func analyzeEmotion(_ request: SessionShellModels.AnalyzeEmotion.Request) async {
        guard let emotionDetectionService else { return }
        guard !request.pcmData.isEmpty else { return }

        let result = await emotionDetectionService.analyze(pcmData: request.pcmData)
        let isNegative = (result.emotion == .frustrated || result.emotion == .sad)
            && result.confidence >= emotionConfidenceThreshold

        if isNegative {
            consecutiveNegativeEmotions += 1
            let emotionRaw = result.emotion.rawValue
            let conf = result.confidence
            logger.info(
                "Negative emotion \(emotionRaw, privacy: .public) conf=\(conf, format: .fixed(precision: 2)) streak=\(self.consecutiveNegativeEmotions)"
            )
            // Каждые `negativeEmotionsPerHeart` подряд негативных эмоций — минус сердце,
            // ускоряя мягкое предложение перерыва (антифатиговое правило).
            if consecutiveNegativeEmotions % negativeEmotionsPerHeart == 0 {
                fatigueHearts = max(0, fatigueHearts - 1)
                logger.info("Fatigue heart drained by emotion → hearts=\(self.fatigueHearts)")
            }
        } else {
            // Положительная/нейтральная эмоция сбрасывает счётчик.
            consecutiveNegativeEmotions = 0
        }

        let suggestBreak = detectFatigue()
        presenter?.presentAnalyzeEmotion(
            .init(suggestBreak: suggestBreak, fatigueHearts: fatigueHearts)
        )
    }

    // MARK: - Public read access (for SessionShellHost mirroring)

    /// Текущее «живое» время сессии, без учёта пауз. Используется TimelineView
    /// в HUD как точка опоры для счётчика mm:ss.
    var sessionActiveStartReference: Date {
        sessionStartTime.addingTimeInterval(accumulatedPauseSeconds)
    }

    var currentFatigueHearts: Int { fatigueHearts }

    // MARK: - Private

    private func detectFatigue() -> Bool {
        let elapsed = activeElapsedSeconds / 60
        return fatigueHearts == 0
            || consecutiveErrors >= maxConsecutiveErrors
            || elapsed >= maxSessionMinutes
    }

    private var activeElapsedSeconds: TimeInterval {
        let total = Date().timeIntervalSince(sessionStartTime)
        return max(0, total - accumulatedPauseSeconds)
    }

    private func loadActivities(for request: SessionShellModels.StartSession.Request) async -> [SessionActivity] {
        // Если deep link / debug-route задал конкретный шаблон — собираем сессию
        // из 5 шагов одного шаблона, минуя AdaptivePlanner.
        if let forced = request.forcedGameType {
            return Self.forcedActivities(for: request, gameType: forced)
        }
        switch request.sessionType {
        case .adaptive:
            do {
                let route = try await adaptivePlannerService.buildDailyRoute(for: request.childId)
                return route.steps.enumerated().map { idx, step in
                    SessionActivity(
                        id: "\(request.childId)-adaptive-\(idx)",
                        gameType: Self.gameType(from: step.templateType),
                        lessonId: "\(step.targetSound)-\(step.stage.rawValue)-\(idx)",
                        soundTarget: step.targetSound,
                        difficulty: step.difficulty,
                        isCompleted: false
                    )
                }
            } catch {
                logger.error("Adaptive route failed: \(error.localizedDescription). Falling back to default.")
                return Self.defaultActivities(for: request)
            }
        case .quickPractice, .screening, .homeworkTask:
            return Self.defaultActivities(for: request)
        }
    }

    private static func forcedActivities(
        for request: SessionShellModels.StartSession.Request,
        gameType: GameType
    ) -> [SessionActivity] {
        (0..<5).map { idx in
            SessionActivity(
                id: "\(request.childId)-forced-\(gameType.rawValue)-\(idx)",
                gameType: gameType,
                lessonId: "\(request.targetSoundId)-\(gameType.rawValue)-\(idx)",
                soundTarget: request.targetSoundId,
                difficulty: 1 + idx / 2,
                isCompleted: false
            )
        }
    }

    private static func defaultActivities(for request: SessionShellModels.StartSession.Request) -> [SessionActivity] {
        let templates: [GameType] = [.listenAndChoose, .repeatAfterModel, .minimalPairs, .sorting, .memory]
        return templates.enumerated().map { idx, type in
            SessionActivity(
                id: "\(request.childId)-\(request.sessionType.rawValue)-\(idx)",
                gameType: type,
                lessonId: "\(request.targetSoundId)-lesson-\(idx)",
                soundTarget: request.targetSoundId,
                difficulty: 1 + idx / 2,
                isCompleted: false
            )
        }
    }

    private static func gameType(from template: TemplateType) -> GameType {
        switch template {
        case .listenAndChoose:       return .listenAndChoose
        case .repeatAfterModel:      return .repeatAfterModel
        case .dragAndMatch:          return .dragAndMatch
        case .storyCompletion:       return .storyCompletion
        case .puzzleReveal:          return .puzzleReveal
        case .sorting:               return .sorting
        case .memory:                return .memory
        case .bingo:                 return .bingo
        case .soundHunter:           return .soundHunter
        case .articulationImitation: return .articulationImitation
        case .arActivity:            return .arActivity
        case .visualAcoustic:        return .visualAcoustic
        case .breathing:             return .breathing
        case .rhythm:                return .rhythm
        case .narrativeQuest:        return .narrativeQuest
        case .minimalPairs:          return .minimalPairs
        case .objectHunt:            return .objectHunt
        case .letterTracing:         return .letterTracing
        }
    }

    private func saveSession() async {
        // Гард: сохраняем сессию ровно один раз (completeActivity и endSessionEarly
        // оба ведут сюда). Без него возможна двойная запись + двойной enqueue синка.
        guard !didSaveSession else { return }
        didSaveSession = true

        let completed = activities.filter { $0.isCompleted }
        let totalCompleted = completed.count
        let avgScore = avgScoreValue()
        // Каждый завершённый шаг = одна «попытка» сессии; correct = score >= 0.5.
        let totalAttempts = max(totalCompleted, 0)
        let correctAttempts = completed.filter { ($0.score ?? 0) >= 0.5 }.count

        let dto = SessionDTO(
            id: UUID().uuidString,
            childId: sessionChildId,
            date: Date(),
            templateType: Self.representativeTemplateType(for: activities),
            targetSound: sessionTargetSound,
            stage: CorrectionStage.wordInit.rawValue,
            durationSeconds: Int(activeElapsedSeconds),
            totalAttempts: totalAttempts,
            correctAttempts: correctAttempts,
            fatigueDetected: detectFatigue(),
            isSynced: false,
            attempts: []
        )

        logger.info("Session saving: \(totalCompleted)/\(self.activities.count) avg=\(avgScore, format: .fixed(precision: 2))")
        logger.info("Session attempts=\(totalAttempts) correct=\(correctAttempts)")

        guard let sessionPersistence else {
            logger.debug("Session not persisted — no SessionPersistenceCoordinator wired (preview/test)")
            return
        }
        await sessionPersistence.persistAndSync(dto)
    }

    /// Представительный `TemplateType.rawValue` сессии — берём первый завершённый
    /// шаг (или первый шаг), мапим `GameType` → `TemplateType`. Сессия может быть
    /// мультишаблонной, но `SessionDTO` хранит один тип (как и AR-персист).
    private static func representativeTemplateType(for activities: [SessionActivity]) -> String {
        let representative = activities.first(where: { $0.isCompleted }) ?? activities.first
        guard let gameType = representative?.gameType else {
            return TemplateType.listenAndChoose.rawValue
        }
        return templateType(from: gameType).rawValue
    }

    private static func templateType(from gameType: GameType) -> TemplateType {
        switch gameType {
        case .listenAndChoose:       return .listenAndChoose
        case .repeatAfterModel:      return .repeatAfterModel
        case .minimalPairs:          return .minimalPairs
        case .dragAndMatch:          return .dragAndMatch
        case .memory:                return .memory
        case .bingo:                 return .bingo
        case .breathing:             return .breathing
        case .rhythm:                return .rhythm
        case .sorting:               return .sorting
        case .puzzleReveal:          return .puzzleReveal
        case .soundHunter:           return .soundHunter
        case .narrativeQuest:        return .narrativeQuest
        case .visualAcoustic:        return .visualAcoustic
        case .storyCompletion:       return .storyCompletion
        case .articulationImitation: return .articulationImitation
        case .arActivity:            return .arActivity
        case .objectHunt:            return .objectHunt
        case .letterTracing:         return .letterTracing
        }
    }

    private func avgScoreValue() -> Float {
        let scored = activities.compactMap { $0.score }
        guard !scored.isEmpty else { return 0 }
        return scored.reduce(0, +) / Float(scored.count)
    }
}
