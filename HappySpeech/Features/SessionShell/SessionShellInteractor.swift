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
    /// P0-2: репозиторий профилей. Когда маршрут пришёл с пустым `targetSoundId`
    /// (быстрый вход / Siri / Spotlight), резолвим РЕАЛЬНЫЙ целевой звук активного
    /// ребёнка (`ChildProfile.targetSounds.first`), чтобы forced/quick-сессии не
    /// тренировали захардкоженный звук. Опционален — в legacy preview/test может
    /// быть `nil` (тогда поведение прежнее: используется переданный звук как есть).
    private let childRepository: (any ChildRepository)?
    /// P0-4: персистентный прогресс ребёнка по 10-этапной лестнице коррекции
    /// (per-child-per-sound). Источник РЕАЛЬНОЙ стартовой стадии сессии (вместо
    /// захардкоженного `wordInit`) и приёмник продвижения вперёд при освоении.
    /// Опционален — в legacy preview/test может быть `nil` (тогда стадия как
    /// раньше определяется метаданными forced-шаблона / адаптивным маршрутом).
    private let stageProgressStore: (any StageProgressStoring)?
    private let logger = Logger(subsystem: "ru.happyspeech", category: "SessionShell")

    private var activities: [SessionActivity] = []
    private var currentIndex: Int = 0
    private var sessionStartTime: Date = Date()
    /// Метаданные текущей сессии для построения `SessionDTO` при сохранении.
    private var sessionChildId: String = ""
    private var sessionTargetSound: String = ""
    /// P0-4: РЕАЛЬНАЯ стадия лестницы, на которой идёт эта сессия. Резолвится в
    /// `startSession` из `stageProgressStore` (forced/quick путь) или из стадии
    /// первого звукового шага адаптивного маршрута. Персистится в `SessionDTO`
    /// вместо константы `wordInit` и кормит продвижение стадии.
    private var sessionStage: CorrectionStage = .wordInit
    /// P1-3 (Fable): реальные попытки сессии — по одной на каждый завершённый
    /// шаг (слово/урок + score + correct + время). Накапливаются в
    /// `completeActivity`, пишутся в `SessionDTO.attempts`, оживляя «слова недели»,
    /// экспорт и consecutiveWrong-фатиг планировщика (раньше attempts были `[]`).
    private var collectedAttempts: [AttemptDTO] = []
    /// Гард от двойного сохранения: `completeActivity`→`saveSession` и
    /// `onDisappear`→`endSessionEarly`→`saveSession` могут сработать оба.
    private var didSaveSession: Bool = false
    /// Стабильный id этого проигрывания. Совпадает с `SessionDTO.id` сохранённой
    /// сессии, чтобы `buildSessionResult()` и persistence-конвейер SessionComplete
    /// идемпотентно связывались с одной записью (стикер/награда по sessionId).
    private let sessionResultId: String = UUID().uuidString
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
        sessionPersistence: (any SessionPersistenceCoordinating)? = nil,
        childRepository: (any ChildRepository)? = nil,
        stageProgressStore: (any StageProgressStoring)? = nil
    ) {
        self.contentService = contentService
        self.adaptivePlannerService = adaptivePlannerService
        self.sessionRepository = sessionRepository
        self.hapticService = hapticService
        self.emotionDetectionService = emotionDetectionService
        self.sessionPersistence = sessionPersistence
        self.childRepository = childRepository
        self.stageProgressStore = stageProgressStore
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
        collectedAttempts = []
        sessionChildId = request.childId

        // P0-2: если маршрут не донёс целевой звук, берём реальный звук активного
        // ребёнка из профиля (первый `targetSound`). Это закрывает ВСЕ входы
        // (daily-mission/quick-play/WordBank/Siri/Spotlight) разом, независимо от
        // того, передал ли конкретный вызов звук. Для `.adaptive`-сессий звук всё
        // равно перепланируется по профилю в планировщике — здесь важен лишь
        // forced/quick путь и метаданные персистенции.
        let resolvedRequest = await resolveTargetSound(for: request)
        sessionTargetSound = resolvedRequest.targetSoundId

        // P0-4: РЕАЛЬНАЯ стадия лестницы этого ребёнка по этому звуку. Раньше
        // сессия всегда писалась как `wordInit` (хардкод), из-за чего лестница
        // была заморожена. Берём текущую стадию из персистентного стора —
        // сессия стартует с того этапа, где ребёнок реально находится.
        sessionStage = resolveSessionStage(
            childId: resolvedRequest.childId,
            sound: resolvedRequest.targetSoundId
        )

        let activities = await loadActivities(for: resolvedRequest)
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

        // Запускаем Live Activity (iOS 16.1+, без COPPA-данных).
        // P0-2: показываем реальный (резолвнутый) звук, а не пустой/чужой.
        if #available(iOS 16.1, *) {
            await LiveActivityManager.shared.start(
                sessionId: resolvedRequest.childId + "-" + UUID().uuidString,
                lessonTitle: resolvedRequest.targetSoundId,
                soundId: resolvedRequest.targetSoundId,
                totalRounds: activities.count
            )
        }
    }

    /// Резолвит целевой звук сессии. Если `request.targetSoundId` уже задан —
    /// возвращает запрос без изменений. Иначе подставляет первый `targetSound`
    /// активного ребёнка из профиля (`childRepository`). Если профиль недоступен
    /// или у ребёнка нет звуков — возвращает запрос как есть (планировщик в
    /// `.adaptive` режиме всё равно выберет звук сам).
    private func resolveTargetSound(
        for request: SessionShellModels.StartSession.Request
    ) async -> SessionShellModels.StartSession.Request {
        let trimmed = request.targetSoundId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty else { return request }
        guard let childRepository, !request.childId.isEmpty else { return request }
        do {
            let profile = try await childRepository.fetch(id: request.childId)
            guard let sound = profile.targetSounds.first(where: { !$0.isEmpty }) else {
                return request
            }
            logger.info("Resolved empty targetSound → child profile sound=\(sound, privacy: .public)")
            return SessionShellModels.StartSession.Request(
                childId: request.childId,
                targetSoundId: sound,
                sessionType: request.sessionType,
                forcedGameType: request.forcedGameType
            )
        } catch {
            logger.notice("resolveTargetSound: profile unavailable (\(error.localizedDescription, privacy: .public)) — keeping request as-is")
            return request
        }
    }

    /// P0-4: Резолвит РЕАЛЬНУЮ стадию лестницы для сессии. Источник истины —
    /// персистентный `stageProgressStore` (per-child-per-sound). При отсутствии
    /// стора (legacy preview/test) или пустых идентификаторов возвращает
    /// `.wordInit` как нейтральную стартовую (прежнее поведение). Откат стадии
    /// при настоящем регрессе уже применяется в адаптивном маршруте
    /// (`StageProgressionPlanner.recommendedStage`) на уровне планировщика — здесь
    /// мы фиксируем текущую освоенную стадию ребёнка для персистенции и продвижения.
    private func resolveSessionStage(childId: String, sound: String) -> CorrectionStage {
        guard let stageProgressStore, !childId.isEmpty, !sound.isEmpty else {
            return .wordInit
        }
        let stage = stageProgressStore.currentStage(childId: childId, sound: sound)
        logger.info(
            "Session stage resolved sound=\(sound, privacy: .public) stage=\(stage.rawValue, privacy: .public)"
        )
        return stage
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

        // F1-016 — единый планировщик интервальных повторов. Центральный хук: КАЖДЫЙ
        // завершённый шаг ЛЮБОГО шаблона (listen-and-choose, repeat-after-model,
        // minimal-pairs, articulation, sound-hunter, visual-acoustic и др.) проходит
        // через SessionShell, поэтому результат попытки кормит FSRS-лестницу здесь —
        // без дублирования в каждом per-template Interactor'е. `correct` берётся из
        // реального score шаблона, не хардкод.
        await recordReviewOutcome(for: activities[currentIndex], correct: isCorrect)

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

        // P1-3 (Fable): фиксируем РЕАЛЬНУЮ попытку завершённого шага. Каждый
        // завершённый шаг любого шаблона проходит через SessionShell, поэтому
        // здесь — единая точка записи attempts (без дублирования в играх).
        // `word` = практикуемый элемент шага (`lessonId`), `asrScore` = реальный
        // score шаблона, `isCorrect` = score ≥ 0.5 (тот же критерий, что у
        // totalAttempts/correctAttempts). Без этого «слова недели», экспорт и
        // consecutiveWrong-фатиг планировщика были мертвы (attempts всегда `[]`).
        recordAttempt(for: activities[currentIndex], score: request.score, isCorrect: isCorrect)

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
                    // P2-3/P2-5: серия = пройденные шаги минус ошибки минус пропуски,
                    // зажата в 0 — раньше могла уйти в минус при произвольных errorCount.
                    streak: consecutiveErrors == 0 ? max(0, currentIndex - errorCount - skippedCount) : 0
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

    /// P2-3 (Fable): пропуск шага — НЕЙТРАЛЬНОЕ событие. Раньше skip шёл через
    /// `completeActivity(score: 0)` → `isCorrect=false` → `consecutiveErrors += 1`,
    /// дренаж сердца, FSRS-исход «неверно», запись ошибочной попытки и `score 0` в
    /// среднем (3 пропуска подряд → «усталость», сессия завершалась). Теперь skip
    /// НЕ трогает серию/фатиг/FSRS/попытки/средний балл: шаг помечается `skipped`
    /// (score остаётся nil, не попадает в подсчёт точности) и мы просто переходим
    /// к следующему шагу. Серия НЕ обнуляется (пропуск — не ошибка), но и НЕ
    /// засчитывается (пропуск — не верный ответ).
    func skipCurrentActivity() async {
        guard currentIndex < activities.count else { return }
        activities[currentIndex].isCompleted = true
        activities[currentIndex].skipped = true
        // score намеренно остаётся nil — пропуск не влияет на средний балл.
        let skippedId = activities[currentIndex].id
        logger.info("Skipped activity id=\(skippedId) (neutral — no error/streak/FSRS impact)")

        // Время сессии по-прежнему ограничивает её длину, но пропуск сам по себе
        // НЕ дренирует сердца и НЕ инкрементит ошибки — `detectFatigue` остаётся
        // честным (срабатывает только по реальным подряд-ошибкам / лимиту времени).
        let fatigueDetected = detectFatigue()
        let nextActivity: SessionActivity? = {
            let nextIdx = currentIndex + 1
            guard nextIdx < activities.count else { return nil }
            return activities[nextIdx]
        }()
        currentIndex += 1

        let response = SessionShellModels.CompleteActivity.Response(
            nextActivity: fatigueDetected ? nil : nextActivity,
            isSessionComplete: nextActivity == nil || fatigueDetected,
            earnedReward: nil,
            fatigueDetected: fatigueDetected,
            fatigueHearts: fatigueHearts,
            feedback: .skipped
        )

        if response.isSessionComplete {
            await saveSession()
            if #available(iOS 16.1, *) {
                await LiveActivityManager.shared.end()
            }
        } else if #available(iOS 16.1, *) {
            let elapsed = Int(activeElapsedSeconds)
            await LiveActivityManager.shared.update(
                round: currentIndex,
                score: Int(avgScoreValue() * 100),
                elapsed: elapsed,
                streak: consecutiveErrors == 0 ? max(0, currentIndex - errorCount - skippedCount) : 0
            )
        }
        await presenter?.presentCompleteActivity(response)
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

    /// Собирает РЕАЛЬНЫЙ результат завершённой сессии для экрана итогов.
    ///
    /// P0-2: раньше координатор показывал `SessionResult.sample` (фейк 86%/3★),
    /// и persistence-конвейер SessionComplete никогда не запускался в проде. Теперь
    /// interactor (единственный владелец метаданных сессии — childId, целевой звук,
    /// длительность, реальные пофрагментные score) отдаёт честный результат, по
    /// которому SessionComplete пишет стикер/стрик/ачивки в Realm.
    ///
    /// Звёзды считаются по средней точности (без учёта подсказок — на уровне
    /// SessionShell подсказки не агрегируются). `sessionId` — стабильный для этого
    /// проигрывания, чтобы детерминировать выбор баннера/стикера.
    func buildSessionResult() -> SessionResult {
        // P2-3: пропущенные шаги не считаются попытками экрана итогов.
        let completed = activities.filter { $0.isCompleted && !$0.skipped }
        let avgScore = avgScoreValue()
        let totalAttempts = completed.count
        let correctAttempts = completed.filter { ($0.score ?? 0) >= 0.5 }.count
        let durationSec = Int(activeElapsedSeconds)

        return SessionResult(
            score: avgScore,
            starsEarned: SessionResult.stars(for: avgScore),
            gameTitle: Self.representativeGameTitle(for: activities),
            soundTarget: sessionTargetSound,
            attempts: totalAttempts,
            correctAttempts: correctAttempts,
            durationSec: durationSec,
            nextLessonTitle: nil,
            childId: sessionChildId,
            sessionId: sessionResultId
        )
    }

    /// Локализованное имя представительного шаблона сессии для экрана итогов.
    private static func representativeGameTitle(for activities: [SessionActivity]) -> String {
        let representative = activities.first(where: { $0.isCompleted }) ?? activities.first
        guard let gameType = representative?.gameType else {
            return String(localized: "sessionComplete.sample.gameTitle")
        }
        return templateType(from: gameType).displayName
    }

    // MARK: - Private

    /// F1-016 — подаёт результат попытки по практикуемому элементу в единый
    /// планировщик интервальных повторов (`ReviewSchedulerService` через
    /// `AdaptivePlannerService.recordItemOutcome`). `itemId` — стабильный
    /// идентификатор практикуемого слова/урока шага (`lessonId`), `sound` — целевой
    /// звук шага. Верный ответ продвигает слово по лестнице 1→3→7→14→30 дней,
    /// ошибка сбрасывает на повтор завтра. Данные персистятся планировщиком
    /// (UserDefaults per-child), затем подмешиваются в начало дневного маршрута.
    private func recordReviewOutcome(for activity: SessionActivity, correct: Bool) async {
        let itemId = activity.lessonId
        let sound = activity.soundTarget
        guard !itemId.isEmpty, !sound.isEmpty else { return }
        await adaptivePlannerService.recordItemOutcome(
            childId: sessionChildId,
            itemId: itemId,
            sound: sound,
            correct: correct
        )
    }

    /// P1-3 (Fable): добавляет реальную попытку завершённого шага в буфер сессии.
    /// `word` берётся из практикуемого элемента шага (`lessonId`). Аудио-пути
    /// пустые: SessionShell не владеет файлом записи (он живёт в играх с захватом
    /// голоса), а отчёты/«слова недели» используют слово + score + correctness,
    /// которые здесь реальны. ASR-транскрипт = слово (известно из контента шага).
    private func recordAttempt(for activity: SessionActivity, score: Float, isCorrect: Bool) {
        let word = activity.lessonId
        guard !word.isEmpty else { return }
        let attempt = AttemptDTO(
            id: UUID().uuidString,
            word: word,
            audioLocalPath: "",
            audioStoragePath: "",
            asrTranscript: word,
            asrScore: Double(score),
            pronunciationScore: Double(score),
            manualScore: -1,
            isCorrect: isCorrect,
            timestamp: Date()
        )
        collectedAttempts.append(attempt)
    }

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
                        // gap #2: при наличии реальной вариации контента (`variationId`)
                        // ключ урока — её стабильный id (ссылка на конкретный
                        // сгенерированный срез пака `звук × этап × тема × сложность`),
                        // иначе — прежний `<звук>-<этап>-<idx>` контракт.
                        lessonId: step.variationId ?? "\(step.targetSound)-\(step.stage.rawValue)-\(idx)",
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

        // P2-3: пропущенные шаги (`skipped`) исключаются из «попыток» — пропуск
        // нейтрален и не должен ни засчитываться верным, ни штрафовать точность.
        let completed = activities.filter { $0.isCompleted && !$0.skipped }
        let totalCompleted = completed.count
        let avgScore = avgScoreValue()
        // Каждый завершённый (не пропущенный) шаг = одна «попытка»; correct = score >= 0.5.
        let totalAttempts = max(totalCompleted, 0)
        let correctAttempts = completed.filter { ($0.score ?? 0) >= 0.5 }.count

        let dto = SessionDTO(
            id: sessionResultId,
            childId: sessionChildId,
            date: Date(),
            templateType: Self.representativeTemplateType(for: activities),
            targetSound: sessionTargetSound,
            // P0-4: пишем РЕАЛЬНУЮ стадию лестницы (резолвнутую в startSession),
            // а не захардкоженный `wordInit` — иначе агрегатор стадии
            // (`SoundProgressAggregator.latestStage`) навсегда видел бы `wordInit`.
            stage: sessionStage.rawValue,
            durationSeconds: Int(activeElapsedSeconds),
            totalAttempts: totalAttempts,
            correctAttempts: correctAttempts,
            fatigueDetected: detectFatigue(),
            isSynced: false,
            // P1-3 (Fable): реальные попытки сессии (раньше всегда `[]`).
            attempts: collectedAttempts
        )

        logger.info("Session saving: \(totalCompleted)/\(self.activities.count) avg=\(avgScore, format: .fixed(precision: 2))")
        logger.info("Session attempts=\(totalAttempts) correct=\(correctAttempts) stage=\(self.sessionStage.rawValue, privacy: .public)")

        // P0-4: продвижение по лестнице при освоении текущей стадии. Применяем
        // методический критерий (≥80% × 2 сессии, изолированный 8/10, рассказ
        // 70%) к реальной точности этой сессии и персистим новую стадию. Только
        // для сессий с реальными попытками — пустой выход (немедленный exit без
        // единого шага) не должен обнулять накопленную серию.
        if totalAttempts > 0 {
            advanceStageProgress(sessionSuccessRate: dto.successRate)
        }

        guard let sessionPersistence else {
            logger.debug("Session not persisted — no SessionPersistenceCoordinator wired (preview/test)")
            return
        }
        await sessionPersistence.persistAndSync(dto)
    }

    /// P0-4: применяет результат завершённой сессии к прогрессу лестницы и
    /// персистит. Продвигает стадию вперёд при выполнении методического критерия
    /// освоения (`StageAdvancementPlanner`). Откат при регрессе делает
    /// планировщик маршрута — здесь только «вверх или держим серию». No-op без
    /// `stageProgressStore` (legacy preview/test) или пустых идентификаторов.
    private func advanceStageProgress(sessionSuccessRate: Double) {
        guard let stageProgressStore,
              !sessionChildId.isEmpty,
              !sessionTargetSound.isEmpty else { return }

        // Считаем серию относительно стадии, на которой реально шла эта сессия
        // (`sessionStage`), сохраняя накопленный счётчик подряд квалифицирующих
        // сессий из стора. Если стор за время сессии переключился на другую
        // стадию (рассинхрон) — счётчик неактуален, начинаем серию заново.
        let stored = stageProgressStore.progress(
            childId: sessionChildId,
            sound: sessionTargetSound
        )
        let streak = stored.stage == sessionStage ? stored.consecutiveQualifyingSessions : 0
        let current = StageProgress(stage: sessionStage, consecutiveQualifyingSessions: streak)
        let decision = StageAdvancementPlanner.apply(
            progress: current,
            sessionSuccessRate: sessionSuccessRate
        )
        stageProgressStore.save(
            decision.progress,
            childId: sessionChildId,
            sound: sessionTargetSound
        )
        if decision.didAdvance {
            logger.notice(
                """
                Stage advanced sound=\(self.sessionTargetSound, privacy: .public) \
                from=\(self.sessionStage.rawValue, privacy: .public) \
                to=\(decision.progress.stage.rawValue, privacy: .public) \
                rate=\(sessionSuccessRate, format: .fixed(precision: 2))
                """
            )
        }
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
        // Пропущенные шаги имеют score=nil и не влияют на средний балл (нейтрально).
        let scored = activities.compactMap { $0.score }
        guard !scored.isEmpty else { return 0 }
        return scored.reduce(0, +) / Float(scored.count)
    }

    /// P2-3: число пропущенных шагов сессии — нужно, чтобы серия в LiveActivity
    /// не «штрафовалась» за пропуски и не уходила в минус.
    private var skippedCount: Int {
        activities.filter { $0.skipped }.count
    }
}
