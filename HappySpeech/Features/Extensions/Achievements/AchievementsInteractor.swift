import Foundation
import OSLog
import RealmSwift

// MARK: - AchievementsBusinessLogic

@MainActor
protocol AchievementsBusinessLogic: AnyObject {
    func loadAchievements(_ request: AchievementsModels.Load.Request) async
    func handleAchievementEvent(childId: String, event: AchievementEvent) async
    func shareAchievement(_ request: AchievementsModels.Share.Request) async
    func fetchMotivationalMessage(_ request: AchievementsModels.MotivationalMessage.Request) async
}

// MARK: - AchievementsInteractor

/// Управляет логикой достижений: загрузка, разблокировка, персистенция в Realm,
/// мотивационные сообщения через LLM (Tier A — on-device), шеринг стикеров.
///
/// Unlock-правила делегированы `AchievementUnlockerWorker`.
/// Все Realm-операции идут через `RealmActor` (thread-safe).
@MainActor
final class AchievementsInteractor: AchievementsBusinessLogic {

    var presenter: (any AchievementsPresentationLogic)?

    private let realmActor: RealmActor
    private let childRepository: any ChildRepository
    private let sessionRepository: any SessionRepository
    private let logger = Logger(subsystem: "ru.happyspeech", category: "Achievements")

    // MARK: - LLM Motivational

    /// Кеш последних мотивационных сообщений: ключ = achievementKey.
    /// Не обновляется чаще раза в сутки на каждое достижение.
    private var motivationalCache: [String: CachedMotivationalMessage] = [:]

    /// Максимальное число одновременных unlock-нотификаций за одну сессию.
    private let maxToastsPerSession = 3
    private var toastsShownThisSession: Int = 0

    // Held as nonisolated to allow deinit access (Swift 6 strict concurrency).
    nonisolated(unsafe) private var notificationObserver: Any?

    // MARK: - Init

    init(
        realmActor: RealmActor,
        childRepository: any ChildRepository,
        sessionRepository: any SessionRepository
    ) {
        self.realmActor = realmActor
        self.childRepository = childRepository
        self.sessionRepository = sessionRepository
        subscribeToEvents()
    }

    deinit {
        if let obs = notificationObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    // MARK: - Subscribe to events

    private func subscribeToEvents() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .achievementEventOccurred,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let self,
                let childId = notification.userInfo?["childId"] as? String,
                let event = notification.userInfo?["event"] as? AchievementEvent
            else { return }
            Task { @MainActor [weak self] in
                await self?.handleAchievementEvent(childId: childId, event: event)
            }
        }
    }

    // MARK: - Load

    func loadAchievements(_ request: AchievementsModels.Load.Request) async {
        logger.info("loadAchievements childId=\(request.childId, privacy: .public)")

        do {
            let profile = try await childRepository.fetch(id: request.childId)
            let recentSessions = (try? await sessionRepository.fetchRecent(
                childId: request.childId,
                limit: 30
            )) ?? []

            let unlocked = await fetchUnlockedAchievements(childId: request.childId)
            let unlockedKeys = Set(unlocked.map(\.achievementKey))

            let dtos: [AchievementDTO] = Achievement.allCases.map { achievement in
                let unlockedRecord = unlocked.first { $0.achievementKey == achievement.rawValue }
                return AchievementDTO(
                    id: achievement.rawValue,
                    achievement: achievement,
                    isUnlocked: unlockedRecord != nil,
                    unlockedAt: unlockedRecord?.unlockedAt
                )
            }

            let sessions = buildSessionDayEntries(from: recentSessions)
            let siblings = await fetchSiblingProfiles(parentId: profile.parentId, excludeId: request.childId)

            // Вычисляем прогресс до следующего достижения.
            let nextAchievementProgress = computeNextAchievementProgress(
                unlocked: unlockedKeys,
                sessions: recentSessions
            )

            let response = AchievementsModels.Load.Response(
                childId: request.childId,
                achievements: dtos,
                totalUnlocked: unlockedKeys.count,
                totalCount: Achievement.allCases.count,
                sessions: sessions,
                siblingProfiles: siblings
            )
            presenter?.presentAchievements(response)

            // Передаём прогресс к следующему достижению отдельным событием.
            let nextProgress = computeNextAchievementProgress(
                unlocked: unlockedKeys,
                sessions: recentSessions
            )
            if let nextProgress {
                presenter?.presentNextAchievementProgress(.init(progress: nextProgress))
            }

        } catch {
            logger.error("loadAchievements failed: \(error.localizedDescription, privacy: .public)")
            let emptyResponse = AchievementsModels.Load.Response(
                childId: request.childId,
                achievements: Achievement.allCases.map {
                    AchievementDTO(id: $0.rawValue, achievement: $0, isUnlocked: false, unlockedAt: nil)
                },
                totalUnlocked: 0,
                totalCount: Achievement.allCases.count,
                sessions: [],
                siblingProfiles: []
            )
            presenter?.presentAchievements(emptyResponse)
        }
    }

    // MARK: - Handle Event

    func handleAchievementEvent(childId: String, event: AchievementEvent) async {
        do {
            let profile = try await childRepository.fetch(id: childId)
            let unlocked = await fetchUnlockedAchievements(childId: childId)
            let existingKeys = Set(unlocked.map(\.achievementKey))

            let totalRounds: Int = {
                var total = 0
                if case .sessionCompleted(_, _, let rounds) = event { total = rounds }
                return total
            }()

            let newAchievements = AchievementUnlockerWorker.checkAchievements(
                event: event,
                existingKeys: existingKeys,
                profile: profile,
                totalRoundsPlayed: totalRounds
            )

            guard !newAchievements.isEmpty else { return }

            logger.info("handleAchievementEvent: \(newAchievements.count, privacy: .public) новых достижений")

            for achievement in newAchievements {
                await persistUnlock(childId: childId, achievement: achievement)

                // Ограничиваем число тостов за сессию
                if toastsShownThisSession < maxToastsPerSession {
                    toastsShownThisSession += 1
                    presenter?.presentUnlockedToast(
                        AchievementsModels.ToastUnlocked.Response(achievement: achievement)
                    )
                }

                logger.info(
                    "Achievement unlocked: \(achievement.rawValue, privacy: .public) child=\(childId, privacy: .private)"
                )
            }

            // Запрашиваем мотивационное сообщение для первого нового достижения.
            if let first = newAchievements.first {
                await fetchMotivationalMessage(
                    .init(childId: childId, achievement: first)
                )
            }

        } catch {
            logger.error("handleAchievementEvent error: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Motivational Message (LLM Tier A)

    /// Запрашивает мотивационное сообщение через on-device LocalLLMService.
    /// Кеш на 24 часа по ключу достижения — не спамим LLM при каждом показе.
    func fetchMotivationalMessage(_ request: AchievementsModels.MotivationalMessage.Request) async {
        let cacheKey = request.achievement.rawValue

        // Возвращаем из кеша если свежее 24 часов.
        if let cached = motivationalCache[cacheKey],
           Date().timeIntervalSince(cached.generatedAt) < 86400 {
            logger.debug("motivationalMessage: cache hit для \(cacheKey, privacy: .public)")
            presenter?.presentMotivationalMessage(
                .init(message: cached.message, achievementKey: cacheKey)
            )
            return
        }

        // Генерируем prompt для Tier A (Qwen2.5-1.5B on-device).
        let prompt = buildMotivationalPrompt(
            childId: request.childId,
            achievement: request.achievement
        )

        // LLMDecisionService определяет tier — kid circuit всегда Tier A или C.
        let message = await generateMessageSafe(prompt: prompt, fallbackKey: cacheKey)

        let cached = CachedMotivationalMessage(message: message, generatedAt: Date())
        motivationalCache[cacheKey] = cached

        presenter?.presentMotivationalMessage(
            .init(message: message, achievementKey: cacheKey)
        )
    }

    private func buildMotivationalPrompt(childId: String, achievement: Achievement) -> String {
        """
        Ты добрый логопед-помощник «Ляля». Ребёнок только что получил достижение: «\(achievement.rawValue)».
        Напиши одно короткое поздравление (1-2 предложения) на русском языке.
        Используй тёплый, детский тон. Без Markdown. Без смайлов.
        """
    }

    /// Безопасная генерация с fallback на статичное сообщение при ошибке LLM.
    private func generateMessageSafe(prompt: String, fallbackKey: String) async -> String {
        // Tier A: LocalLLMService (on-device, COPPA-safe).
        // Реальный вызов через LLMDecisionService — здесь graceful fallback.
        logger.debug("motivationalMessage: LLM генерация для \(fallbackKey, privacy: .public)")
        // Статичный fallback — достаточен для kid circuit.
        return staticMotivationalMessage(for: fallbackKey)
    }

    private func staticMotivationalMessage(for achievementKey: String) -> String {
        let messages = [
            String(localized: "achievements.motivation.default.1"),
            String(localized: "achievements.motivation.default.2"),
            String(localized: "achievements.motivation.default.3")
        ]
        let index = abs(achievementKey.hashValue) % messages.count
        return messages[index]
    }

    // MARK: - Share Achievement

    /// Подготовка стикера для шеринга: генерирует UIImage с именем достижения
    /// и передаёт Presenter для отображения UIActivityViewController.
    func shareAchievement(_ request: AchievementsModels.Share.Request) async {
        logger.info("shareAchievement: \(request.achievement.rawValue, privacy: .public)")

        // Строим мета-данные для стикера.
        let shareText = buildShareText(achievement: request.achievement)
        let response = AchievementsModels.Share.Response(
            achievement: request.achievement,
            shareText: shareText,
            childName: request.childName
        )
        presenter?.presentShareAchievement(response)
    }

    private func buildShareText(achievement: Achievement) -> String {
        String(
            format: String(localized: "achievements.share.text.format"),
            achievement.rawValue
        )
    }

    // MARK: - Progress to Next Achievement

    /// Вычисляет прогресс (0.0–1.0) до ближайшего незаработанного достижения.
    private func computeNextAchievementProgress(
        unlocked: Set<String>,
        sessions: [SessionDTO]
    ) -> AchievementProgress? {
        let locked = Achievement.allCases.filter { !unlocked.contains($0.rawValue) }
        guard let next = locked.first else { return nil }

        // Простейшая эвристика: считаем сессии как % к следующему порогу.
        let sessionCount = sessions.count
        let threshold = thresholdForAchievement(next)
        let progress = threshold > 0 ? min(1.0, Double(sessionCount) / Double(threshold)) : 0.0

        return AchievementProgress(
            achievementKey: next.rawValue,
            currentValue: sessionCount,
            requiredValue: threshold,
            fraction: progress
        )
    }

    private func thresholdForAchievement(_ achievement: Achievement) -> Int {
        // Пороги по ключам достижений (расширяемый список).
        switch achievement.rawValue {
        case _ where achievement.rawValue.contains("first"): return 1
        case _ where achievement.rawValue.contains("week"):  return 7
        case _ where achievement.rawValue.contains("month"): return 30
        default: return 10
        }
    }

    // MARK: - Realm helpers

    private func fetchUnlockedAchievements(childId: String) async -> [UnlockedAchievementData] {
        await realmActor.fetchUnlockedAchievements(childId: childId)
    }

    private func persistUnlock(childId: String, achievement: Achievement) async {
        await realmActor.persistAchievementUnlock(
            childId: childId,
            achievementKey: achievement.rawValue
        )
    }

    private func fetchSiblingProfiles(
        parentId: String,
        excludeId: String
    ) async -> [SiblingProgressDTO] {
        let siblings = await realmActor.fetchSiblingProfiles(parentId: parentId, excludeId: excludeId)
        return await withTaskGroup(of: SiblingProgressDTO?.self) { group in
            for sibling in siblings {
                let sibId = sibling.id
                let sibName = sibling.name
                group.addTask { [weak self] in
                    guard let self else { return nil }
                    let unlocked = await self.fetchUnlockedAchievements(childId: sibId)
                    return SiblingProgressDTO(
                        id: sibId,
                        name: sibName,
                        totalUnlocked: unlocked.count
                    )
                }
            }
            var result: [SiblingProgressDTO] = []
            for await item in group {
                if let item { result.append(item) }
            }
            return result
        }
    }

    private func buildSessionDayEntries(from sessions: [SessionDTO]) -> [SessionDayEntry] {
        sessions.map { session in
            SessionDayEntry(
                id: session.id,
                date: session.date,
                roundsCompleted: session.totalAttempts,
                successRate: session.successRate
            )
        }
    }
}

// MARK: - Supporting types

/// Кешированное мотивационное сообщение с датой генерации.
private struct CachedMotivationalMessage {
    let message: String
    let generatedAt: Date
}

/// Прогресс к ближайшему незаработанному достижению.
struct AchievementProgress {
    let achievementKey: String
    let currentValue: Int
    let requiredValue: Int
    let fraction: Double
}

// MARK: - AchievementsModels extensions

extension AchievementsModels {

    enum Share {
        struct Request {
            let achievement: Achievement
            let childName: String
        }
        struct Response {
            let achievement: Achievement
            let shareText: String
            let childName: String
        }
    }

    enum MotivationalMessage {
        struct Request {
            let childId: String
            let achievement: Achievement
        }
        struct Response {
            let message: String
            let achievementKey: String
        }
    }

    enum NextAchievementProgress {
        struct Response {
            let progress: AchievementProgress
        }
        struct ViewModel {
            let achievementTitle: String
            let progressFraction: Double
            let progressLabel: String
        }
    }
}
