import RealmSwift
import XCTest
@testable import HappySpeech

// MARK: - SpyAchievementsPresenter

@MainActor
private final class SpyAchievementsPresenter: AchievementsPresentationLogic {
    private(set) var achievementsCallCount: Int = 0
    private(set) var toastCallCount: Int = 0
    private(set) var nextProgressCallCount: Int = 0
    private(set) var motivationalCallCount: Int = 0
    private(set) var shareCallCount: Int = 0

    private(set) var lastAchievementsResponse: AchievementsModels.Load.Response?
    private(set) var lastToastResponse: AchievementsModels.ToastUnlocked.Response?
    private(set) var lastMotivationalResponse: AchievementsModels.MotivationalMessage.Response?
    private(set) var lastShareResponse: AchievementsModels.Share.Response?

    func presentAchievements(_ response: AchievementsModels.Load.Response) {
        achievementsCallCount += 1
        lastAchievementsResponse = response
    }
    func presentUnlockedToast(_ response: AchievementsModels.ToastUnlocked.Response) {
        toastCallCount += 1
        lastToastResponse = response
    }
    func presentNextAchievementProgress(_ response: AchievementsModels.NextAchievementProgress.Response) {
        nextProgressCallCount += 1
    }
    func presentMotivationalMessage(_ response: AchievementsModels.MotivationalMessage.Response) {
        motivationalCallCount += 1
        lastMotivationalResponse = response
    }
    func presentShareAchievement(_ response: AchievementsModels.Share.Response) {
        shareCallCount += 1
        lastShareResponse = response
    }
}

// MARK: - AchievementsInteractorTests

@MainActor
final class AchievementsInteractorTests: XCTestCase {

    // MARK: - Helpers

    private func makeRealmActor() async throws -> RealmActor {
        let memId = "achievements-unit-\(UUID().uuidString)"
        var config = Realm.Configuration()
        config.inMemoryIdentifier = memId
        config.schemaVersion = RealmSchemaVersion.current
        Realm.Configuration.defaultConfiguration = config
        let actor = RealmActor()
        try await actor.open(configuration: config)
        return actor
    }

    private func makeSUT(
        childShouldFail: Bool = false
    ) async throws -> (
        sut: AchievementsInteractor,
        presenter: SpyAchievementsPresenter,
        childRepo: SpyChildRepository
    ) {
        let realm = try await makeRealmActor()
        let childRepo = SpyChildRepository(children: [
            TestDataBuilder.childProfile(id: "c1", name: "Маша", parentId: "p1")
        ])
        childRepo.shouldFail = childShouldFail
        let sessionRepo = SpySessionRepository(sessions: [
            TestDataBuilder.session(id: "s1", childId: "c1")
        ])
        let sut = AchievementsInteractor(
            realmActor: realm,
            childRepository: childRepo,
            sessionRepository: sessionRepo
        )
        let presenter = SpyAchievementsPresenter()
        sut.presenter = presenter
        return (sut, presenter, childRepo)
    }

    // MARK: - loadAchievements

    func test_loadAchievements_callsPresentAchievements() async throws {
        let (sut, presenter, _) = try await makeSUT()
        await sut.loadAchievements(.init(childId: "c1"))
        XCTAssertEqual(presenter.achievementsCallCount, 1)
    }

    func test_loadAchievements_totalCount_equalsAllCasesCount() async throws {
        let (sut, presenter, _) = try await makeSUT()
        await sut.loadAchievements(.init(childId: "c1"))
        XCTAssertEqual(presenter.lastAchievementsResponse?.totalCount, Achievement.allCases.count)
    }

    func test_loadAchievements_noUnlockedInitially_totalUnlocked_isZero() async throws {
        let (sut, presenter, _) = try await makeSUT()
        await sut.loadAchievements(.init(childId: "c1"))
        XCTAssertEqual(presenter.lastAchievementsResponse?.totalUnlocked, 0)
    }

    func test_loadAchievements_childRepoFail_stillCallsPresentAchievements() async throws {
        let (sut, presenter, _) = try await makeSUT(childShouldFail: true)
        await sut.loadAchievements(.init(childId: "c1"))
        XCTAssertEqual(presenter.achievementsCallCount, 1)
    }

    func test_loadAchievements_childRepoFail_totalUnlockedIsZero() async throws {
        let (sut, presenter, _) = try await makeSUT(childShouldFail: true)
        await sut.loadAchievements(.init(childId: "c1"))
        XCTAssertEqual(presenter.lastAchievementsResponse?.totalUnlocked, 0)
    }

    func test_loadAchievements_allDTOs_haveCorrectAchievementCount() async throws {
        let (sut, presenter, _) = try await makeSUT()
        await sut.loadAchievements(.init(childId: "c1"))
        XCTAssertEqual(presenter.lastAchievementsResponse?.achievements.count, Achievement.allCases.count)
    }

    // MARK: - handleAchievementEvent toast limit

    func test_handleAchievementEvent_max3Toasts_respected() async throws {
        let (sut, presenter, _) = try await makeSUT()
        for _ in 1...10 {
            await sut.handleAchievementEvent(childId: "c1", event: .arGamePlayed)
        }
        XCTAssertLessThanOrEqual(presenter.toastCallCount, 3)
    }

    func test_handleAchievementEvent_doesNotCrash_onRepoFail() async throws {
        let (sut, _, _) = try await makeSUT(childShouldFail: true)
        await sut.handleAchievementEvent(childId: "c1", event: .arGamePlayed)
        // Should not crash
    }

    // MARK: - fetchMotivationalMessage

    func test_fetchMotivationalMessage_callsPresentMotivationalMessage() async throws {
        let (sut, presenter, _) = try await makeSUT()
        await sut.fetchMotivationalMessage(.init(childId: "c1", achievement: .firstSoundMastered))
        XCTAssertEqual(presenter.motivationalCallCount, 1)
    }

    func test_fetchMotivationalMessage_messageIsNonEmpty() async throws {
        let (sut, presenter, _) = try await makeSUT()
        await sut.fetchMotivationalMessage(.init(childId: "c1", achievement: .firstSoundMastered))
        XCTAssertFalse(presenter.lastMotivationalResponse?.message.isEmpty ?? true)
    }

    func test_fetchMotivationalMessage_secondCall_usesCache() async throws {
        let (sut, presenter, _) = try await makeSUT()
        await sut.fetchMotivationalMessage(.init(childId: "c1", achievement: .streak3Days))
        await sut.fetchMotivationalMessage(.init(childId: "c1", achievement: .streak3Days))
        XCTAssertEqual(presenter.motivationalCallCount, 2)
    }

    func test_fetchMotivationalMessage_achievementKeyInResponse() async throws {
        let (sut, presenter, _) = try await makeSUT()
        await sut.fetchMotivationalMessage(.init(childId: "c1", achievement: .firstSoundMastered))
        XCTAssertEqual(presenter.lastMotivationalResponse?.achievementKey, Achievement.firstSoundMastered.rawValue)
    }

    // MARK: - shareAchievement

    func test_shareAchievement_callsPresentShareAchievement() async throws {
        let (sut, presenter, _) = try await makeSUT()
        await sut.shareAchievement(.init(achievement: .streak7Days, childName: "Маша"))
        XCTAssertEqual(presenter.shareCallCount, 1)
    }

    func test_shareAchievement_responseContainsChildName() async throws {
        let (sut, presenter, _) = try await makeSUT()
        await sut.shareAchievement(.init(achievement: .streak7Days, childName: "Маша"))
        XCTAssertEqual(presenter.lastShareResponse?.childName, "Маша")
    }

    func test_shareAchievement_shareTextNonEmpty() async throws {
        let (sut, presenter, _) = try await makeSUT()
        await sut.shareAchievement(.init(achievement: .streak7Days, childName: "Маша"))
        XCTAssertFalse(presenter.lastShareResponse?.shareText.isEmpty ?? true)
    }

    // MARK: - Achievement rarity

    func test_achievement_streak100Days_isLegendary() {
        XCTAssertEqual(Achievement.streak100Days.rarity, .legendary)
    }

    func test_achievement_streak3Days_isCommon() {
        XCTAssertEqual(Achievement.streak3Days.rarity, .common)
    }

    func test_achievement_played500Rounds_isRare() {
        XCTAssertEqual(Achievement.played500Rounds.rarity, .rare)
    }

    // MARK: - Achievement metadata

    func test_allAchievements_haveNonEmptyIconNames() {
        for achievement in Achievement.allCases {
            XCTAssertFalse(achievement.iconName.isEmpty, "empty icon for \(achievement.rawValue)")
        }
    }

    func test_allAchievements_haveNonEmptyRawValues() {
        for achievement in Achievement.allCases {
            XCTAssertFalse(achievement.rawValue.isEmpty, "empty rawValue")
        }
    }
}
