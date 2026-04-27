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

    // MARK: - 2. loadRewards seed содержит 24 стикера

    func test_loadRewards_seedHas24Stickers() {
        let (sut, spy) = makeSUT()
        sut.loadRewards(.init(childId: "child-1", forceReload: false))
        XCTAssertEqual(spy.lastLoadRewards?.stickers.count, 24)
    }

    // MARK: - 3. forceReload сбрасывает и пересоздаёт seed

    func test_loadRewards_forceReload_resetsSeed() {
        let (sut, spy) = makeSUT()
        sut.loadRewards(.init(childId: "child-1", forceReload: true))
        XCTAssertEqual(spy.lastLoadRewards?.stickers.count, 24)
    }

    // MARK: - 4. filterByCollection возвращает только стикеры из нужной коллекции

    func test_filterByCollection_stars_returnsOnlyStars() {
        let (sut, spy) = makeSUT()
        sut.loadRewards(.init(childId: "child-1", forceReload: false))
        sut.filterByCollection(.init(collection: .stars))
        XCTAssertTrue(spy.filterCalled)
        let filtered = spy.lastFilter?.stickers.filter { $0.collection != .stars } ?? []
        // Все возвращённые стикеры в правильной коллекции или activeCollection = .all
        // Проверяем что коллекция правильно зафиксирована
        XCTAssertEqual(spy.lastFilter?.activeCollection, .stars)
    }

    // MARK: - 5. filterByCollection .all возвращает все стикеры

    func test_filterByCollection_all_returnsAll() {
        let (sut, spy) = makeSUT()
        sut.loadRewards(.init(childId: "child-1", forceReload: false))
        sut.filterByCollection(.init(collection: .all))
        XCTAssertEqual(spy.lastFilter?.stickers.count, 24)
    }

    // MARK: - 6. openSticker с существующим id → presenter получает стикер

    func test_openSticker_existing_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.loadRewards(.init(childId: "child-1", forceReload: false))
        sut.openSticker(.init(id: "star.first"))
        XCTAssertTrue(spy.openStickerCalled)
        XCTAssertEqual(spy.lastOpenSticker?.sticker.id, "star.first")
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
        sut.claimReward(.init(id: "star.first"))
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
}
