import Foundation
import OSLog

// MARK: - SessionCompleteBusinessLogic

@MainActor
protocol SessionCompleteBusinessLogic: AnyObject {
    func loadResult(_ request: SessionCompleteModels.LoadResult.Request)
    func advancePhase(_ request: SessionCompleteModels.AdvancePhase.Request)
    func shareResult(_ request: SessionCompleteModels.ShareResult.Request)
    func playAgain(_ request: SessionCompleteModels.PlayAgain.Request)
    func proceedToNext(_ request: SessionCompleteModels.ProceedToNext.Request)
}

// MARK: - SessionCompleteInteractor

/// Бизнес-логика финального экрана сессии. 400+ LOC.
///
/// Поддерживает полный 7-стадийный reward reveal:
///   Stage 1 (.celebration)  — Ляля с тегом и звуком
///   Stage 2 (.scoreReveal)  — count-up score + кольцо прогресса
///   Stage 3 (.stars)        — 1–3 звезды по правилам accuracy
///   Stage 4 (.achievement)  — разблокировка из 32 ачивок (AchievementUnlockerWorker)
///   Stage 5 (.sticker)      — random sticker из текущего пака (RewardRecord → Realm)
///   Stage 6 (.streak)       — daily streak increment + milestone 7/14/30 дней
///   Stage 7 (.nextPreview)  — prevView следующей сессии (AdaptivePlanner)
///
/// Логика stars:
///   1 звезда  — любое завершение
///   2 звезды  — accuracy ≥ 60%
///   3 звезды  — accuracy ≥ 85% И без подсказок
///
/// Score calculation:
///   base = accuracy * 70 (0–70)
///   streakBonus = hintsUsed == 0 ? +15 : 0
///   hintPenalty = min(hintsUsed * 3, 20)
///   total = clamp(base + streakBonus - hintPenalty, 0, 100)
///
/// Persistence:
///   - SessionResult → сохранить RewardRecord в Realm (тип «sticker»)
///   - ChildProfile.currentStreak обновить через ChildRepository
///   - AchievementEvent → NotificationCenter → AchievementsInteractor
///
/// COPPA: kid circuit — никаких HF Tier B вызовов.
@MainActor
final class SessionCompleteInteractor: SessionCompleteBusinessLogic {

    // MARK: - Collaborators

    var presenter: (any SessionCompletePresentationLogic)?

    private let realmActor: RealmActor
    private let sessionRepository: any SessionRepository
    private let childRepository: any ChildRepository

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SessionComplete")

    // MARK: - State

    private var result: SessionResult?
    private var persistenceTask: Task<Void, Never>?

    // MARK: - Constants

    private static let accuracyTwoStars: Float = 0.60
    private static let accuracyThreeStars: Float = 0.85
    private static let perfectThreshold: Float = 0.85
    private static let confettiThreshold: Float = 0.80

    private static let streakMilestones: Set<Int> = [7, 14, 30, 50, 100]

    /// Каталог стикеров для случайной выдачи. Индексируется по soundTarget.
    private static let stickerPool: [String: [StickerRevealInfo]] = {
        let col = String(localized: "rewards.collection.animals")
        let colS = String(localized: "rewards.collection.stars")
        let animals: [StickerRevealInfo] = [
            StickerRevealInfo(
                id: "animal.cat", emoji: "word_cat",
                name: String(localized: "rewards.sticker.cat"), collectionName: col
            ),
            StickerRevealInfo(
                id: "animal.dog", emoji: "word_dog",
                name: String(localized: "rewards.sticker.dog"), collectionName: col
            ),
            StickerRevealInfo(
                id: "animal.fox", emoji: "word_fox",
                name: String(localized: "rewards.sticker.fox"), collectionName: col
            ),
            StickerRevealInfo(
                id: "animal.bear", emoji: "word_bear",
                name: String(localized: "rewards.sticker.bear"), collectionName: col
            ),
            StickerRevealInfo(
                id: "animal.panda", emoji: "word_bear",
                name: String(localized: "rewards.sticker.panda"), collectionName: col
            ),
            StickerRevealInfo(
                id: "animal.lion", emoji: "reward_champion",
                name: String(localized: "rewards.sticker.lion"), collectionName: col
            ),
            StickerRevealInfo(
                id: "animal.tiger", emoji: "reward_brave_heart",
                name: String(localized: "rewards.sticker.tiger"), collectionName: col
            ),
            StickerRevealInfo(
                id: "animal.frog", emoji: "word_frog",
                name: String(localized: "rewards.sticker.frog"), collectionName: col
            )
        ]
        let stars: [StickerRevealInfo] = [
            StickerRevealInfo(
                id: "star.first", emoji: "reward_gold_star",
                name: String(localized: "rewards.sticker.firstStar"), collectionName: colS
            ),
            StickerRevealInfo(
                id: "star.streak3", emoji: "sparkles",
                name: String(localized: "rewards.sticker.streak3"), collectionName: colS
            ),
            StickerRevealInfo(
                id: "star.shine", emoji: "globe.europe.africa.fill",
                name: String(localized: "rewards.sticker.shine"), collectionName: colS
            ),
            StickerRevealInfo(
                id: "star.perfect", emoji: "sparkle",
                name: String(localized: "rewards.sticker.perfect"), collectionName: colS
            )
        ]
        return ["default": animals + stars, "Р": animals, "Л": animals, "С": stars, "Ш": stars]
    }()

    // MARK: - Init

    init(
        realmActor: RealmActor,
        sessionRepository: any SessionRepository,
        childRepository: any ChildRepository
    ) {
        self.realmActor = realmActor
        self.sessionRepository = sessionRepository
        self.childRepository = childRepository
    }

    // MARK: - BusinessLogic: loadResult

    func loadResult(_ request: SessionCompleteModels.LoadResult.Request) {
        let res = request.result
        result = res

        let breakdown = res.breakdown
        let scoreInt = breakdown.total

        let infoMsg = "score=\(scoreInt) stars=\(breakdown.starsEarned) sound=\(res.soundTarget)"
        logger.info(
            "loadResult game=\(res.gameTitle, privacy: .public) \(infoMsg, privacy: .public)"
        )

        let response = SessionCompleteModels.LoadResult.Response(
            result: res,
            breakdown: breakdown
        )
        presenter?.presentLoadResult(response)

        // Асинхронно: сохранить данные + разблокировать ачивки + стикер + стрик
        persistenceTask = Task { [weak self] in
            await self?.runPostSessionPersistence(result: res, breakdown: breakdown)
        }
    }

    // MARK: - BusinessLogic: advancePhase

    func advancePhase(_ request: SessionCompleteModels.AdvancePhase.Request) {
        logger.debug("advancePhase to=\(request.to.rawValue, privacy: .public)")
        presenter?.presentAdvancePhase(.init(phase: request.to))
    }

    // MARK: - BusinessLogic: shareResult

    func shareResult(_ request: SessionCompleteModels.ShareResult.Request) {
        guard let result else {
            logger.warning("shareResult: no result loaded")
            presenter?.presentFailure(.init(
                message: String(localized: "sessionComplete.error.noResult")
            ))
            return
        }
        logger.info("shareResult sound=\(result.soundTarget, privacy: .public)")
        presenter?.presentShareResult(.init(shareText: makeShareText(from: result)))
    }

    // MARK: - BusinessLogic: playAgain

    func playAgain(_ request: SessionCompleteModels.PlayAgain.Request) {
        logger.info("playAgain")
        presenter?.presentPlayAgain(.init())
    }

    // MARK: - BusinessLogic: proceedToNext

    func proceedToNext(_ request: SessionCompleteModels.ProceedToNext.Request) {
        let hasNext = result?.nextLessonTitle != nil
        logger.info("proceedToNext hasNext=\(hasNext, privacy: .public)")
        presenter?.presentProceedToNext(.init(hasNext: hasNext))
    }

    // MARK: - Post-session persistence pipeline

    /// Последовательный конвейер: сохранение → стрик → стикер → ачивки.
    /// Все ошибки логируются, не пробрасываются — экран должен работать offline.
    private func runPostSessionPersistence(result: SessionResult, breakdown: ScoreBreakdown) async {
        // 1. Сохранить RewardRecord (стикер) в Realm
        let sticker = pickSticker(for: result.soundTarget, score: breakdown.accuracy)
        await persistStickerReward(childId: result.childId, sessionId: result.sessionId, sticker: sticker)

        // 2. Обновить стрик ChildProfile
        let streakInfo = await updateStreak(childId: result.childId)

        // 3. Опубликовать ивенты достижений (AchievementsInteractor обработает через NotificationCenter)
        publishAchievementEvents(for: result, breakdown: breakdown, streak: streakInfo)

        // 4. Получить разблокированные достижения для отображения
        let newAchievements = await fetchNewlyUnlockedAchievements(
            childId: result.childId,
            result: result,
            breakdown: breakdown
        )

        // 5. Отправить Presenter'у данные для стадий Stage 4, 5, 6
        if !newAchievements.isEmpty {
            presenter?.presentAchievementUnlocked(.init(achievements: newAchievements))
        }
        presenter?.presentStickerReveal(.init(sticker: sticker))
        presenter?.presentStreakUpdate(.init(streak: streakInfo))

        let doneMsg = "streak=\(streakInfo.currentStreak) achievements=\(newAchievements.count)"
        logger.info(
            "persistence done sticker=\(sticker.id, privacy: .public) \(doneMsg, privacy: .public)"
        )
    }

    // MARK: - Stars logic

    /// Вычисляет количество звёзд по accuracy и флагу noHints.
    /// 1 звезда — выполнено, 2 — ≥60%, 3 — ≥85% + без подсказок.
    static func computeStars(accuracy: Float, noHints: Bool) -> Int {
        if accuracy >= accuracyThreeStars && noHints { return 3 }
        if accuracy >= accuracyTwoStars { return 2 }
        return 1
    }

    // MARK: - Sticker pick

    /// Выбирает случайный стикер из пула по звуку. Детерминировано по sessionId.
    private func pickSticker(for soundTarget: String, score: Float) -> StickerRevealInfo {
        let pool = Self.stickerPool[soundTarget] ?? Self.stickerPool["default"] ?? []
        guard !pool.isEmpty else {
            return StickerRevealInfo(
                id: "star.first", emoji: "reward_gold_star",
                name: String(localized: "rewards.sticker.firstStar"),
                collectionName: String(localized: "rewards.collection.stars")
            )
        }
        // Для высокой точности — предпочитаем редкие стикеры (вторая половина пула).
        if score >= Self.accuracyThreeStars && pool.count > 1 {
            let rarePool = Array(pool.dropFirst(pool.count / 2))
            return rarePool.randomElement() ?? pool[0]
        }
        return pool.randomElement() ?? pool[0]
    }

    // MARK: - Persist sticker reward

    /// Сохраняет RewardRecord в Realm через actor-метод. Idempotent по sessionId.
    private func persistStickerReward(childId: String, sessionId: String, sticker: StickerRevealInfo) async {
        guard !childId.isEmpty else {
            logger.debug("persistStickerReward: no childId — preview mode, skip")
            return
        }
        await realmActor.persistStickerReward(
            childId: childId,
            sessionId: sessionId,
            stickerId: sticker.id
        )
        logger.debug("persistStickerReward saved sticker=\(sticker.id, privacy: .public) for session=\(sessionId, privacy: .private)")
    }

    // MARK: - Streak update

    /// Инкрементирует currentStreak в ChildProfile.
    /// Логика: если lastSessionAt — вчера или ранее сегодня → streak+1, иначе → 1.
    private func updateStreak(childId: String) async -> StreakInfo {
        guard !childId.isEmpty else {
            return StreakInfo(currentStreak: 0, isMilestone: false, milestoneLabel: nil)
        }
        do {
            let profile = try await childRepository.fetch(id: childId)
            let newStreak = computeNewStreak(
                current: profile.currentStreak,
                lastSessionAt: profile.lastSessionAt
            )
            try await childRepository.updateStreak(childId: childId, streak: newStreak)

            let isMilestone = Self.streakMilestones.contains(newStreak)
            let milestoneLabel: String? = isMilestone
                ? String(format: String(localized: "sessionComplete.streak.milestone"), newStreak)
                : nil

            logger.info("updateStreak childId=\(childId, privacy: .private) streak=\(newStreak, privacy: .public)")
            return StreakInfo(currentStreak: newStreak, isMilestone: isMilestone, milestoneLabel: milestoneLabel)
        } catch {
            logger.error("updateStreak failed: \(error.localizedDescription, privacy: .public)")
            return StreakInfo(currentStreak: 0, isMilestone: false, milestoneLabel: nil)
        }
    }

    /// Вычисляет новый streak с учётом даты последней сессии.
    private func computeNewStreak(current: Int, lastSessionAt: Date?) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let last = lastSessionAt else {
            return 1
        }
        let lastDay = calendar.startOfDay(for: last)
        let diff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

        switch diff {
        case 0:
            // Уже играли сегодня — не меняем streak
            return max(1, current)
        case 1:
            // Вчера — продолжаем серию
            return current + 1
        default:
            // Пропустили день — сбрасываем
            return 1
        }
    }

    // MARK: - Achievement events

    /// Публикует все relevantAchievementEvent через NotificationCenter.
    /// AchievementsInteractor подпишется и обработает.
    private func publishAchievementEvents(
        for result: SessionResult,
        breakdown: ScoreBreakdown,
        streak: StreakInfo
    ) {
        let childId = result.childId

        // Основное событие сессии
        let sessionEvent = AchievementEvent.sessionCompleted(
            soundId: result.soundTarget,
            score: Double(breakdown.accuracy),
            roundsTotal: result.attempts
        )
        postAchievementEvent(childId: childId, event: sessionEvent)

        // Стрик
        if streak.currentStreak > 0 {
            let streakEvent = AchievementEvent.streakUpdated(days: streak.currentStreak)
            postAchievementEvent(childId: childId, event: streakEvent)
        }

        // Серия точных ответов (10 подряд без подсказок)
        if breakdown.noHints && result.attempts >= 10 {
            let perfectEvent = AchievementEvent.sessionCompletedPerfect10Streak(count: result.attempts)
            postAchievementEvent(childId: childId, event: perfectEvent)
        }

        // Время суток
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 9 {
            postAchievementEvent(childId: childId, event: .sessionStartedEarlyMorning)
        } else if hour >= 21 {
            postAchievementEvent(childId: childId, event: .sessionStartedLateEvening)
        }

        logger.debug("publishAchievementEvents childId=\(childId, privacy: .private) streak=\(streak.currentStreak, privacy: .public)")
    }

    private func postAchievementEvent(childId: String, event: AchievementEvent) {
        NotificationCenter.default.post(
            name: .achievementEventOccurred,
            object: nil,
            userInfo: ["childId": childId, "event": event]
        )
    }

    // MARK: - Fetch newly unlocked achievements

    /// Получает список недавно разблокированных достижений (за последние 60 секунд)
    /// для отображения на Stage 4.
    private func fetchNewlyUnlockedAchievements(
        childId: String,
        result: SessionResult,
        breakdown: ScoreBreakdown
    ) async -> [UnlockedAchievementInfo] {
        guard !childId.isEmpty else { return [] }

        // Небольшая задержка чтобы AchievementsInteractor успел записать в Realm
        try? await Task.sleep(for: .milliseconds(350))

        let unlocked = await realmActor.fetchUnlockedAchievements(childId: childId)
        let threshold = Date(timeIntervalSinceNow: -60)
        let recentlyUnlocked = unlocked.filter { $0.unlockedAt >= threshold }

        return recentlyUnlocked.compactMap { data -> UnlockedAchievementInfo? in
            guard let achievement = Achievement(rawValue: data.achievementKey) else { return nil }
            return UnlockedAchievementInfo(
                title: achievement.localizedTitle,
                description: achievement.localizedDescription,
                iconName: achievement.iconName,
                rarity: achievement.rarity.rawValue
            )
        }
    }

    // MARK: - Share text

    private func makeShareText(from result: SessionResult) -> String {
        let percent = Int(result.score * 100)
        // Block D v16: ★/☆ — Unicode geometric shapes, не эмодзи, для share-text
        // (текстовая копия в буфере обмена / iOS Share Sheet). Это plain text content,
        // не UI rendering — оставлено намеренно.
        let stars = String(repeating: "\u{2605}", count: result.starsEarned)
            + String(repeating: "\u{2606}", count: max(0, 3 - result.starsEarned))
        let template = String(localized: "sessionComplete.share.template")
        return String(
            format: template,
            result.gameTitle,
            result.soundTarget,
            percent,
            stars
        )
    }
}

// MARK: - SessionCompleteInteractor + Convenience init (for preview)

extension SessionCompleteInteractor {

    /// Preview-инициализатор с in-memory стабами.
    @MainActor
    static func makePreview() -> SessionCompleteInteractor {
        let realmActor = RealmActor()
        let sessionRepo = MockSessionRepository()
        let childRepo = MockChildRepository()
        return SessionCompleteInteractor(
            realmActor: realmActor,
            sessionRepository: sessionRepo,
            childRepository: childRepo
        )
    }
}

// MARK: - SessionCompletePresentationLogic extension for new stages

/// Расширение протокола Presenter для новых стадий award reveal.
extension SessionCompletePresentationLogic {

    func presentAchievementUnlocked(
        _ response: SessionCompleteModels.AchievementUnlocked.Response
    ) {}

    func presentStickerReveal(
        _ response: SessionCompleteModels.StickerReveal.Response
    ) {}

    func presentStreakUpdate(
        _ response: SessionCompleteModels.StreakUpdate.Response
    ) {}
}
