import Foundation
import OSLog

// MARK: - AchievementWallBusinessLogic

@MainActor
protocol AchievementWallBusinessLogic: AnyObject {
    func loadWall(_ request: AchievementWallModels.LoadWall.Request) async
    func openDetail(_ request: AchievementWallModels.OpenDetail.Request) async
    func share(_ request: AchievementWallModels.Share.Request) async
}

// MARK: - AchievementWallInteractor

/// Загружает стену достижений: объединяет разблокированные (`UnlockedAchievementObject`)
/// с полным каталогом `Achievement.allCases` — locked цели остаются видимы,
/// но показываются в grayscale с lock overlay.
///
/// Метод `share(_:)` собирает текст для UIActivityViewController; сам share
/// генерируется на View (snapshot) + Router (presentation).
@MainActor
final class AchievementWallInteractor: AchievementWallBusinessLogic {

    var presenter: (any AchievementWallPresentationLogic)?

    private let realmActor: RealmActor
    private let childRepository: any ChildRepository

    private let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "AchievementWall.Interactor"
    )

    // Last-loaded entries — needed for openDetail без повторного похода в Realm.
    private var cachedEntries: [WallEntry] = []

    init(
        realmActor: RealmActor,
        childRepository: any ChildRepository
    ) {
        self.realmActor = realmActor
        self.childRepository = childRepository
    }

    // MARK: - Load

    func loadWall(_ request: AchievementWallModels.LoadWall.Request) async {
        logger.info("loadWall childId=\(request.childId, privacy: .private)")

        let profile = try? await childRepository.fetch(id: request.childId)
        let unlockedRecords = await realmActor.fetchUnlockedAchievements(childId: request.childId)
        let unlockedMap: [String: Date] = Dictionary(
            uniqueKeysWithValues: unlockedRecords.map { ($0.achievementKey, $0.unlockedAt) }
        )

        let entries: [WallEntry] = Achievement.allCases.map { achievement in
            WallEntry(
                achievement: achievement,
                unlocked: unlockedMap[achievement.rawValue] != nil,
                unlockedDate: unlockedMap[achievement.rawValue]
            )
        }
        cachedEntries = entries
        let totalUnlocked = entries.filter(\.unlocked).count

        let response = AchievementWallModels.LoadWall.Response(
            childId: request.childId,
            childName: profile?.name ?? "Мой герой",
            childAge: profile?.age ?? 6,
            entries: entries,
            totalUnlocked: totalUnlocked,
            totalCount: entries.count
        )
        await presenter?.presentWall(response: response)
    }

    // MARK: - Open Detail

    func openDetail(_ request: AchievementWallModels.OpenDetail.Request) async {
        logger.info("openDetail id=\(request.achievementId, privacy: .public)")
        guard let entry = cachedEntries.first(where: { $0.id == request.achievementId }) else {
            return
        }
        await presenter?.presentDetail(response: .init(entry: entry))
    }

    // MARK: - Share

    func share(_ request: AchievementWallModels.Share.Request) async {
        let unlockedCount = cachedEntries.filter(\.unlocked).count
        let shareText = """
        Стена достижений \(request.childName): уже \(unlockedCount) наград в HappySpeech! 🏆
        """
        await presenter?.presentShare(response: .init(shareText: shareText))
    }
}
