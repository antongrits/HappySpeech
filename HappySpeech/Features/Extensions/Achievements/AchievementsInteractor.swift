import Foundation
import OSLog
import RealmSwift

// MARK: - AchievementsBusinessLogic

@MainActor
protocol AchievementsBusinessLogic: AnyObject {
    func loadAchievements(_ request: AchievementsModels.Load.Request) async
    func handleAchievementEvent(childId: String, event: AchievementEvent) async
}

// MARK: - AchievementsInteractor

@MainActor
final class AchievementsInteractor: AchievementsBusinessLogic {

    var presenter: (any AchievementsPresentationLogic)?

    private let realmActor: RealmActor
    private let childRepository: any ChildRepository
    private let sessionRepository: any SessionRepository
    private let logger = Logger(subsystem: "ru.happyspeech", category: "Achievements")

    // Held as nonisolated to allow deinit access (Swift 6 strict concurrency).
    nonisolated(unsafe) private var notificationObserver: Any?

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

    // MARK: - Subscribe

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

            let response = AchievementsModels.Load.Response(
                childId: request.childId,
                achievements: dtos,
                totalUnlocked: unlockedKeys.count,
                totalCount: Achievement.allCases.count,
                sessions: sessions,
                siblingProfiles: siblings
            )
            presenter?.presentAchievements(response)
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

            for achievement in newAchievements {
                await persistUnlock(childId: childId, achievement: achievement)
                presenter?.presentUnlockedToast(
                    AchievementsModels.ToastUnlocked.Response(achievement: achievement)
                )
                logger.info("Achievement unlocked: \(achievement.rawValue, privacy: .public) for child \(childId, privacy: .private)")
            }
        } catch {
            logger.error("handleAchievementEvent error: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Realm helpers

    private func fetchUnlockedAchievements(childId: String) async -> [UnlockedAchievementData] {
        await realmActor.fetchUnlockedAchievements(childId: childId)
    }

    private func persistUnlock(childId: String, achievement: Achievement) async {
        await realmActor.persistAchievementUnlock(childId: childId, achievementKey: achievement.rawValue)
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
