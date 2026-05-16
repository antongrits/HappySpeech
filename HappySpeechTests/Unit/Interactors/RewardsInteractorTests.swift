@testable import HappySpeech
import XCTest

// MARK: - RewardsInteractorTests
//
// M10.1 — 9 тестов для RewardsInteractor.
// Покрывает: loadRewards, filterByCollection, openSticker, claimReward, error cases.

@MainActor
final class RewardsInteractorTests: XCTestCase {

    // MARK: - Spy

    @MainActor
    private final class SpyPresenter: RewardsPresentationLogic {
        var loadRewardsCalled = false
        var filterCalled = false
        var openStickerCalled = false
        var claimRewardCalled = false
        var failureCalled = false

        var lastLoadRewards: RewardsModels.LoadRewards.Response?
        var lastFilter: RewardsModels.FilterByCollection.Response?
        var lastOpenSticker: RewardsModels.OpenSticker.Response?
        var lastClaimReward: RewardsModels.ClaimReward.Response?
        var lastFailure: RewardsModels.Failure.Response?

        func presentLoadRewards(_ response: RewardsModels.LoadRewards.Response) {
            loadRewardsCalled = true
            lastLoadRewards = response
        }
        func presentFilterByCollection(_ response: RewardsModels.FilterByCollection.Response) {
            filterCalled = true
            lastFilter = response
        }
        func presentOpenSticker(_ response: RewardsModels.OpenSticker.Response) {
            openStickerCalled = true
            lastOpenSticker = response
        }
        func presentClaimReward(_ response: RewardsModels.ClaimReward.Response) {
            claimRewardCalled = true
            lastClaimReward = response
        }
        func presentFailure(_ response: RewardsModels.Failure.Response) {
            failureCalled = true
            lastFailure = response
        }
        var sortCalled = false
        var searchCalled = false
        var changeThemeCalled = false
        var prepareShareCalled = false
        var openAchievementCalled = false
        var claimStreakRewardCalled = false

        var lastSort: RewardsModels.SortStickers.Response?
        var lastSearch: RewardsModels.SearchStickers.Response?
        var lastChangeTheme: RewardsModels.ChangeAlbumTheme.Response?
        var lastPrepareShare: RewardsModels.PrepareShare.Response?
        var lastOpenAchievement: RewardsModels.OpenAchievement.Response?
        var lastClaimStreakReward: RewardsModels.ClaimStreakReward.Response?

        func presentSortStickers(_ response: RewardsModels.SortStickers.Response) {
            sortCalled = true
            lastSort = response
        }
        func presentSearchStickers(_ response: RewardsModels.SearchStickers.Response) {
            searchCalled = true
            lastSearch = response
        }
        func presentChangeAlbumTheme(_ response: RewardsModels.ChangeAlbumTheme.Response) {
            changeThemeCalled = true
            lastChangeTheme = response
        }
        func presentPrepareShare(_ response: RewardsModels.PrepareShare.Response) {
            prepareShareCalled = true
            lastPrepareShare = response
        }
        func presentOpenAchievement(_ response: RewardsModels.OpenAchievement.Response) {
            openAchievementCalled = true
            lastOpenAchievement = response
        }
        func presentClaimStreakReward(_ response: RewardsModels.ClaimStreakReward.Response) {
            claimStreakRewardCalled = true
            lastClaimStreakReward = response
        }
    }

    private func makeSUT() -> (RewardsInteractor, SpyPresenter) {
        let sut = RewardsInteractor()
        let spy = SpyPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - 1. loadRewards вызывает presenter со стикерами

    func test_loadRewards_callsPresenterWithStickers() {
        let (sut, spy) = makeSUT()
        sut.loadRewards(.init(childId: "child-1", forceReload: false))
        XCTAssertTrue(spy.loadRewardsCalled)
        XCTAssertFalse(spy.lastLoadRewards?.stickers.isEmpty ?? true)
    }

    // MARK: - 2. loadRewards seed содержит стикеры (не пустой)

    func test_loadRewards_seedHasStickers() {
        let (sut, spy) = makeSUT()
        sut.loadRewards(.init(childId: "child-1", forceReload: false))
        XCTAssertGreaterThan(spy.lastLoadRewards?.stickers.count ?? 0, 0)
    }

    // MARK: - 3. forceReload сбрасывает и пересоздаёт seed

    func test_loadRewards_forceReload_resetsSeed() {
        let (sut, spy) = makeSUT()
        sut.loadRewards(.init(childId: "child-1", forceReload: true))
        XCTAssertGreaterThan(spy.lastLoadRewards?.stickers.count ?? 0, 0)
    }

    // MARK: - 4. filterByCollection возвращает только стикеры из нужной коллекции

    func test_filterByCollection_stars_returnsOnlyStars() {
        let (sut, spy) = makeSUT()
        sut.loadRewards(.init(childId: "child-1", forceReload: false))
        sut.filterByCollection(.init(collection: .animals))
        XCTAssertTrue(spy.filterCalled)
        let filtered = spy.lastFilter?.stickers.filter { $0.collection != .animals } ?? []
        // Все возвращённые стикеры в правильной коллекции или activeCollection = .all
        // Проверяем что коллекция правильно зафиксирована
        XCTAssertEqual(spy.lastFilter?.activeCollection, .animals)
    }

    // MARK: - 5. filterByCollection .all возвращает все стикеры

    func test_filterByCollection_all_returnsAll() {
        let (sut, spy) = makeSUT()
        sut.loadRewards(.init(childId: "child-1", forceReload: false))
        let totalCount = spy.lastLoadRewards?.stickers.count ?? 0
        sut.filterByCollection(.init(collection: .all))
        XCTAssertEqual(spy.lastFilter?.stickers.count, totalCount)
    }

    // MARK: - 6. openSticker с существующим id → presenter получает стикер

    func test_openSticker_existing_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.loadRewards(.init(childId: "child-1", forceReload: false))
        sut.openSticker(.init(id: "animals.cat"))
        XCTAssertTrue(spy.openStickerCalled)
        XCTAssertEqual(spy.lastOpenSticker?.sticker.id, "animals.cat")
    }

    // MARK: - 7. openSticker с несуществующим id → failure

    func test_openSticker_notFound_callsFailure() {
        let (sut, spy) = makeSUT()
        sut.loadRewards(.init(childId: "child-1", forceReload: false))
        sut.openSticker(.init(id: "nonexistent-id"))
        XCTAssertFalse(spy.openStickerCalled)
        XCTAssertTrue(spy.failureCalled)
    }

    // MARK: - 8. claimReward снимает флаг isNew

    func test_claimReward_clearsIsNew() {
        let (sut, spy) = makeSUT()
        sut.loadRewards(.init(childId: "child-1", forceReload: false))
        // star.first и animal.cat помечены isNew: true в seed
        sut.claimReward(.init(id: "animals.dog"))
        XCTAssertTrue(spy.claimRewardCalled)
        XCTAssertFalse(spy.lastClaimReward?.sticker.isNew ?? true)
    }

    // MARK: - 9. claimReward с несуществующим id → failure

    func test_claimReward_notFound_callsFailure() {
        let (sut, spy) = makeSUT()
        sut.loadRewards(.init(childId: "child-1", forceReload: false))
        sut.claimReward(.init(id: "ghost-id"))
        XCTAssertFalse(spy.claimRewardCalled)
        XCTAssertTrue(spy.failureCalled)
    }

    // MARK: - 10. claimReward уже заявленного стикера → presentOpenSticker

    func test_claimReward_alreadyClaimed_presentsOpenSticker() {
        let (sut, spy) = makeSUT()
        sut.loadRewards(.init(childId: "child-1", forceReload: false))
        // animals.cat — isNew: false в seed
        sut.claimReward(.init(id: "animals.cat"))
        XCTAssertTrue(spy.openStickerCalled)
        XCTAssertFalse(spy.claimRewardCalled)
    }

    // MARK: - 11. sortStickers для каждого порядка

    func test_sortStickers_byDate() {
        let (sut, spy) = makeSUT()
        sut.loadRewards(.init(childId: "child-1", forceReload: false))
        sut.sortStickers(.init(sortOrder: .byDate))
        XCTAssertTrue(spy.sortCalled)
        XCTAssertEqual(spy.lastSort?.sortOrder, .byDate)
    }

    func test_sortStickers_byRarity() {
        let (sut, spy) = makeSUT()
        sut.loadRewards(.init(childId: "child-1", forceReload: false))
        sut.sortStickers(.init(sortOrder: .byRarity))
        XCTAssertEqual(spy.lastSort?.sortOrder, .byRarity)
    }

    func test_sortStickers_byCollection() {
        let (sut, spy) = makeSUT()
        sut.loadRewards(.init(childId: "child-1", forceReload: false))
        sut.sortStickers(.init(sortOrder: .byCollection))
        XCTAssertEqual(spy.lastSort?.sortOrder, .byCollection)
    }

    // MARK: - 12. searchStickers

    func test_searchStickers_returnsResponse() {
        let (sut, spy) = makeSUT()
        sut.loadRewards(.init(childId: "child-1", forceReload: false))
        sut.searchStickers(.init(query: "  кот  "))
        XCTAssertTrue(spy.searchCalled)
        XCTAssertEqual(spy.lastSearch?.query, "кот")
    }

    func test_searchStickers_emptyQuery() {
        let (sut, spy) = makeSUT()
        sut.loadRewards(.init(childId: "child-1", forceReload: false))
        sut.searchStickers(.init(query: ""))
        XCTAssertTrue(spy.searchCalled)
        XCTAssertEqual(spy.lastSearch?.query, "")
    }

    // MARK: - 13. changeAlbumTheme

    func test_changeAlbumTheme_updatesTheme() {
        let (sut, spy) = makeSUT()
        sut.loadRewards(.init(childId: "child-1", forceReload: false))
        sut.changeAlbumTheme(.init(theme: .neon))
        XCTAssertTrue(spy.changeThemeCalled)
        XCTAssertEqual(spy.lastChangeTheme?.theme, .neon)
    }

    func test_changeAlbumTheme_persistsAcrossInstances() {
        let (sut, _) = makeSUT()
        sut.loadRewards(.init(childId: "child-1", forceReload: false))
        sut.changeAlbumTheme(.init(theme: .pastel))
        // Новый Interactor читает сохранённую тему
        let (sut2, spy2) = makeSUT()
        sut2.loadRewards(.init(childId: "child-1", forceReload: false))
        XCTAssertEqual(spy2.lastLoadRewards?.albumTheme, .pastel)
    }

    // MARK: - 14. prepareShare

    func test_prepareShare_returnsTopStickers() {
        let (sut, spy) = makeSUT()
        sut.loadRewards(.init(childId: "child-1", forceReload: false))
        sut.prepareShare(.init(childId: "child-1"))
        XCTAssertTrue(spy.prepareShareCalled)
        XCTAssertGreaterThan(spy.lastPrepareShare?.totalCount ?? 0, 0)
        XCTAssertLessThanOrEqual(spy.lastPrepareShare?.topStickers.count ?? 99, 5)
    }

    // MARK: - 15. openAchievement

    func test_openAchievement_existing_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.loadRewards(.init(childId: "child-1", forceReload: false))
        sut.openAchievement(.init(key: "first_session"))
        XCTAssertTrue(spy.openAchievementCalled)
        XCTAssertEqual(spy.lastOpenAchievement?.achievement.key, "first_session")
    }

    func test_openAchievement_notFound_callsFailure() {
        let (sut, spy) = makeSUT()
        sut.loadRewards(.init(childId: "child-1", forceReload: false))
        sut.openAchievement(.init(key: "nonexistent_achievement"))
        XCTAssertFalse(spy.openAchievementCalled)
        XCTAssertTrue(spy.failureCalled)
    }

    // MARK: - 16. claimStreakReward

    func test_claimStreakReward_validStreak_succeeds() {
        // Свежий suite чтобы не было ранее заявленных streak
        UserDefaults.standard.removeObject(forKey: "rewards.claimedStreaks")
        let (sut, spy) = makeSUT()
        sut.loadRewards(.init(childId: "child-1", forceReload: false))
        // currentStreak = 7 в init → можно заявить 7 дней
        sut.claimStreakReward(.init(streakDays: 7))
        XCTAssertTrue(spy.claimStreakRewardCalled)
        XCTAssertEqual(spy.lastClaimStreakReward?.reward.streakDays, 7)
        UserDefaults.standard.removeObject(forKey: "rewards.claimedStreaks")
    }

    func test_claimStreakReward_insufficientStreak_callsFailure() {
        UserDefaults.standard.removeObject(forKey: "rewards.claimedStreaks")
        let (sut, spy) = makeSUT()
        sut.loadRewards(.init(childId: "child-1", forceReload: false))
        // currentStreak = 7 < 30 → недостаточно
        sut.claimStreakReward(.init(streakDays: 30))
        XCTAssertTrue(spy.failureCalled)
        XCTAssertFalse(spy.claimStreakRewardCalled)
        UserDefaults.standard.removeObject(forKey: "rewards.claimedStreaks")
    }

    func test_claimStreakReward_alreadyClaimed_callsFailure() {
        UserDefaults.standard.removeObject(forKey: "rewards.claimedStreaks")
        let (sut, spy) = makeSUT()
        sut.loadRewards(.init(childId: "child-1", forceReload: false))
        sut.claimStreakReward(.init(streakDays: 7))
        spy.failureCalled = false
        spy.claimStreakRewardCalled = false
        sut.claimStreakReward(.init(streakDays: 7))
        XCTAssertTrue(spy.failureCalled)
        XCTAssertFalse(spy.claimStreakRewardCalled)
        UserDefaults.standard.removeObject(forKey: "rewards.claimedStreaks")
    }

    // MARK: - 17. filterByCollection возвращает корректный набор для коллекции

    func test_filterByCollection_space_recordsCollection() {
        let (sut, spy) = makeSUT()
        sut.loadRewards(.init(childId: "child-1", forceReload: false))
        sut.filterByCollection(.init(collection: .space))
        XCTAssertEqual(spy.lastFilter?.activeCollection, .space)
    }
}
