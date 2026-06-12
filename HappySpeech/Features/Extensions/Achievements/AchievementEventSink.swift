import Foundation
import OSLog

// MARK: - AchievementEventSink

/// Резидентный (долгоживущий) слушатель шины `.achievementEventOccurred`.
///
/// P1-5: раньше единственным подписчиком был `AchievementsInteractor`, который
/// жил ТОЛЬКО пока открыт экран ачивок. Продюсеры событий (завершение сессии,
/// смена наряда) публиковали в шину, когда экран был закрыт → события молча
/// терялись, ачивки не разблокировались («монеты/наряды не копятся»).
///
/// Этот sink создаётся один раз в `AppContainer` (в `bootstrapApp`) и живёт всё
/// время работы приложения. Он персистит разблокированные ачивки в Realm через
/// тот же путь, что и интерактор (`AchievementUnlockerWorker` +
/// `RealmActor.persistAchievementUnlock`, идемпотентно). Тосты/UI он НЕ показывает
/// — это ответственность открытого экрана ачивок; sink лишь гарантирует, что
/// разблокировка ПЕРСИСТИТСЯ независимо от того, открыт экран или нет.
///
/// COPPA: вся логика on-device, без сети. childId без PII.
@MainActor
final class AchievementEventSink {

    private let realmActor: RealmActor
    private let childRepository: any ChildRepository
    private let logger = Logger(subsystem: "ru.happyspeech", category: "AchievementEventSink")

    // nonisolated(unsafe) для доступа из deinit (Swift 6 strict concurrency).
    nonisolated(unsafe) private var observer: Any?

    // MARK: - Init

    init(realmActor: RealmActor, childRepository: any ChildRepository) {
        self.realmActor = realmActor
        self.childRepository = childRepository
        subscribe()
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Subscription

    private func subscribe() {
        observer = NotificationCenter.default.addObserver(
            forName: .achievementEventOccurred,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let self,
                let childId = notification.userInfo?["childId"] as? String,
                !childId.isEmpty,
                let event = notification.userInfo?["event"] as? AchievementEvent
            else { return }
            Task { @MainActor [weak self] in
                await self?.persistUnlocks(childId: childId, event: event)
            }
        }
        logger.debug("AchievementEventSink: подписан на шину достижений")
    }

    // MARK: - Persistence

    /// Считает новые ачивки по событию и идемпотентно персистит их в Realm.
    private func persistUnlocks(childId: String, event: AchievementEvent) async {
        let profile: ChildProfileDTO
        do {
            profile = try await childRepository.fetch(id: childId)
        } catch {
            logger.error("persistUnlocks: профиль не найден child=\(childId, privacy: .private): \(error.localizedDescription, privacy: .public)")
            return
        }

        let unlocked = await realmActor.fetchUnlockedAchievements(childId: childId)
        let existingKeys = Set(unlocked.map(\.achievementKey))

        let totalRounds: Int = {
            if case .sessionCompleted(_, _, let rounds) = event { return rounds }
            return 0
        }()

        let newAchievements = AchievementUnlockerWorker.checkAchievements(
            event: event,
            existingKeys: existingKeys,
            profile: profile,
            totalRoundsPlayed: totalRounds
        )

        guard !newAchievements.isEmpty else { return }

        for achievement in newAchievements {
            await realmActor.persistAchievementUnlock(
                childId: childId,
                achievementKey: achievement.rawValue
            )
        }
        logger.info("persistUnlocks: персистировано \(newAchievements.count, privacy: .public) ачивок")
    }
}
