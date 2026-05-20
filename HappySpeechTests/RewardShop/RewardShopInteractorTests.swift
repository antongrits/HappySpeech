@testable import HappySpeech
import XCTest

// MARK: - Stub Worker

@MainActor
private final class StubRewardShopWorker: RewardShopWorkerProtocol {

    var stickers: [StickerItem]
    var earnedCoins: Int = 0
    var spentCoins: Int = 0
    var inventory: [StickerInventoryData] = []
    var purchaseShouldFail: Bool = false
    private(set) var purchaseCallCount = 0

    init(
        stickers: [StickerItem] = StubRewardShopWorker.defaultCatalog(),
        earnedCoins: Int = 0,
        inventory: [StickerInventoryData] = []
    ) {
        self.stickers = stickers
        self.earnedCoins = earnedCoins
        self.inventory = inventory
    }

    func catalog() -> [StickerItem] { stickers }
    func loadInventory(childId: String) async -> [StickerInventoryData] { inventory }
    func loadEarnedCoins(childId: String) async -> Int { earnedCoins }
    func loadSpentCoins(childId: String) async -> Int { spentCoins }

    func purchase(childId: String, stickerId: String, price: Int) async -> Bool {
        purchaseCallCount += 1
        if purchaseShouldFail { return false }
        spentCoins += price
        inventory.append(StickerInventoryData(
            id: UUID().uuidString,
            childId: childId,
            stickerId: stickerId,
            purchasedAt: Date(),
            priceSpent: price
        ))
        return true
    }

    static func defaultCatalog() -> [StickerItem] {
        [
            StickerItem(id: "s_low", name: "Низкий", price: 10,
                        category: .achievement, imageName: "img_low", rarity: .common),
            StickerItem(id: "s_mid", name: "Средний", price: 50,
                        category: .animal, imageName: "img_mid", rarity: .uncommon),
            StickerItem(id: "s_top", name: "Дорогой", price: 200,
                        category: .lyalya, imageName: "img_top", rarity: .epic)
        ]
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpyRewardShopPresenter:
    RewardShopPresentationLogic, @unchecked Sendable {
    var loadCount = 0
    var successCount = 0
    var failureCount = 0
    var lastSuccess: RewardShopModels.Purchase.Response?
    var lastFailure: RewardShopModels.Purchase.FailureResponse?
    var lastLoad: RewardShopModels.Load.Response?

    func presentLoad(response: RewardShopModels.Load.Response) async {
        loadCount += 1
        lastLoad = response
    }

    func presentPurchaseSuccess(response: RewardShopModels.Purchase.Response) async {
        successCount += 1
        lastSuccess = response
    }

    func presentPurchaseFailure(response: RewardShopModels.Purchase.FailureResponse) async {
        failureCount += 1
        lastFailure = response
    }
}

// MARK: - Interactor Tests

@MainActor
final class RewardShopInteractorTests: XCTestCase {

    private func makeSUT(
        earned: Int = 100,
        owned: [String] = []
    ) -> (RewardShopInteractor, SpyRewardShopPresenter, StubRewardShopWorker, SpyHapticService) {
        let inventory = owned.map { id in
            StickerInventoryData(
                id: UUID().uuidString,
                childId: "child-1",
                stickerId: id,
                purchasedAt: Date(),
                priceSpent: 0
            )
        }
        let worker = StubRewardShopWorker(earnedCoins: earned, inventory: inventory)
        let haptic = SpyHapticService()
        let interactor = RewardShopInteractor(
            childId: "child-1",
            worker: worker,
            hapticService: haptic
        )
        let spy = SpyRewardShopPresenter()
        interactor.presenter = spy
        return (interactor, spy, worker, haptic)
    }

    func test_load_presentsCatalogAndCoins() async {
        let (sut, spy, _, _) = makeSUT(earned: 80)
        await sut.load(request: .init(childId: "child-1"))
        XCTAssertEqual(spy.loadCount, 1)
        XCTAssertEqual(spy.lastLoad?.coinsEarned, 80)
        XCTAssertEqual(spy.lastLoad?.coinsSpent, 0)
        XCTAssertEqual(spy.lastLoad?.catalog.count, 3)
    }

    func test_purchase_withSufficientCoins_succeeds() async {
        let (sut, spy, worker, haptic) = makeSUT(earned: 100)
        await sut.load(request: .init(childId: "child-1"))
        await sut.purchase(request: .init(childId: "child-1", stickerId: "s_low"))
        XCTAssertEqual(spy.successCount, 1)
        XCTAssertEqual(worker.purchaseCallCount, 1)
        XCTAssertEqual(haptic.notificationCount, 1)
        XCTAssertEqual(sut.ownedStickerIds, ["s_low"])
        XCTAssertEqual(sut.coinsSpent, 10)
    }

    func test_purchase_withInsufficientCoins_fails() async {
        let (sut, spy, worker, _) = makeSUT(earned: 5)
        await sut.load(request: .init(childId: "child-1"))
        await sut.purchase(request: .init(childId: "child-1", stickerId: "s_low"))
        XCTAssertEqual(spy.failureCount, 1)
        XCTAssertEqual(worker.purchaseCallCount, 0)
        if case .notEnoughCoins(let have, let need) = spy.lastFailure?.reason {
            XCTAssertEqual(have, 5)
            XCTAssertEqual(need, 10)
        } else {
            XCTFail("Expected notEnoughCoins")
        }
    }

    func test_purchase_unknownSticker_fails() async {
        let (sut, spy, _, _) = makeSUT(earned: 100)
        await sut.load(request: .init(childId: "child-1"))
        await sut.purchase(request: .init(childId: "child-1", stickerId: "non_existent"))
        XCTAssertEqual(spy.failureCount, 1)
        XCTAssertEqual(spy.lastFailure?.reason, .unknownSticker)
    }

    func test_purchase_alreadyOwned_fails() async {
        let (sut, spy, _, _) = makeSUT(earned: 200, owned: ["s_mid"])
        await sut.load(request: .init(childId: "child-1"))
        await sut.purchase(request: .init(childId: "child-1", stickerId: "s_mid"))
        XCTAssertEqual(spy.failureCount, 1)
        XCTAssertEqual(spy.lastFailure?.reason, .alreadyOwned)
    }

    func test_doublePurchase_secondAttemptIsRejected() async {
        let (sut, spy, worker, _) = makeSUT(earned: 200)
        await sut.load(request: .init(childId: "child-1"))
        await sut.purchase(request: .init(childId: "child-1", stickerId: "s_low"))
        XCTAssertEqual(spy.successCount, 1)
        await sut.purchase(request: .init(childId: "child-1", stickerId: "s_low"))
        XCTAssertEqual(spy.successCount, 1)
        XCTAssertEqual(spy.failureCount, 1)
        XCTAssertEqual(worker.purchaseCallCount, 1, "БД не должна вызываться повторно")
    }

    func test_purchase_workerFailure_isReportedAsAlreadyOwned() async {
        let (sut, spy, worker, _) = makeSUT(earned: 100)
        await sut.load(request: .init(childId: "child-1"))
        worker.purchaseShouldFail = true
        await sut.purchase(request: .init(childId: "child-1", stickerId: "s_low"))
        XCTAssertEqual(spy.failureCount, 1)
        XCTAssertEqual(spy.lastFailure?.reason, .alreadyOwned)
    }

    func test_balanceCalculation_subtractsSpent() async {
        let (sut, spy, _, _) = makeSUT(earned: 100)
        await sut.load(request: .init(childId: "child-1"))
        await sut.purchase(request: .init(childId: "child-1", stickerId: "s_low"))
        // После покупки баланс презентуется заново.
        XCTAssertEqual(spy.lastLoad?.coinsEarned, 100)
        XCTAssertEqual(spy.lastLoad?.coinsSpent, 10)
    }

    func test_load_setsOwnedSet() async {
        let (sut, _, _, _) = makeSUT(earned: 100, owned: ["s_mid", "s_top"])
        await sut.load(request: .init(childId: "child-1"))
        XCTAssertEqual(sut.ownedStickerIds, ["s_mid", "s_top"])
    }

    func test_load_initialBalance_isZeroWhenNothingEarned() async {
        let (sut, spy, _, _) = makeSUT(earned: 0)
        await sut.load(request: .init(childId: "child-1"))
        XCTAssertEqual(spy.lastLoad?.coinsEarned, 0)
        // С 0 монет ничего нельзя купить.
        await sut.purchase(request: .init(childId: "child-1", stickerId: "s_low"))
        XCTAssertEqual(spy.failureCount, 1)
    }
}

// MARK: - Presenter Tests

@MainActor
private final class FakeDisplayLogic:
    RewardShopDisplayLogic, @unchecked Sendable {
    var loadVM: RewardShopModels.Load.ViewModel?
    var successVM: RewardShopModels.Purchase.ViewModel?
    var failureVM: RewardShopModels.Purchase.FailureViewModel?

    func displayLoad(viewModel: RewardShopModels.Load.ViewModel) async { loadVM = viewModel }
    func displayPurchaseSuccess(viewModel: RewardShopModels.Purchase.ViewModel) async { successVM = viewModel }
    func displayPurchaseFailure(viewModel: RewardShopModels.Purchase.FailureViewModel) async { failureVM = viewModel }
}

@MainActor
final class RewardShopPresenterTests: XCTestCase {

    func test_presentLoad_groupsByCategory_andOrdersByPrice() async {
        let display = FakeDisplayLogic()
        let presenter = RewardShopPresenter(displayLogic: display)
        let response = RewardShopModels.Load.Response(
            coinsEarned: 50,
            coinsSpent: 0,
            ownedStickerIds: [],
            catalog: [
                StickerItem(id: "a", name: "A", price: 20, category: .achievement, imageName: "img", rarity: .common),
                StickerItem(id: "b", name: "B", price: 10, category: .achievement, imageName: "img", rarity: .common),
                StickerItem(id: "c", name: "C", price: 30, category: .animal, imageName: "img", rarity: .common)
            ]
        )
        await presenter.presentLoad(response: response)
        XCTAssertEqual(display.loadVM?.coinsBalance, 50)
        XCTAssertEqual(display.loadVM?.categories.count, 2)
        XCTAssertEqual(display.loadVM?.categories.first?.stickers.first?.id, "b") // cheapest first
    }

    func test_presentLoad_marksAffordableVsLocked() async {
        let display = FakeDisplayLogic()
        let presenter = RewardShopPresenter(displayLogic: display)
        let response = RewardShopModels.Load.Response(
            coinsEarned: 15,
            coinsSpent: 0,
            ownedStickerIds: [],
            catalog: [
                StickerItem(id: "cheap", name: "Дешёвый", price: 10,
                            category: .achievement, imageName: "img", rarity: .common),
                StickerItem(id: "expensive", name: "Дорогой", price: 100,
                            category: .achievement, imageName: "img", rarity: .common)
            ]
        )
        await presenter.presentLoad(response: response)
        let stickers = display.loadVM?.categories.first?.stickers ?? []
        let cheap = stickers.first(where: { $0.id == "cheap" })
        let exp = stickers.first(where: { $0.id == "expensive" })
        XCTAssertEqual(cheap?.isAffordable, true)
        XCTAssertEqual(exp?.isAffordable, false)
    }

    func test_presentPurchaseFailure_NotEnoughCoinsMessageContainsDelta() async {
        let display = FakeDisplayLogic()
        let presenter = RewardShopPresenter(displayLogic: display)
        await presenter.presentPurchaseFailure(response: .init(
            stickerId: "x",
            reason: .notEnoughCoins(have: 5, need: 20)
        ))
        XCTAssertNotNil(display.failureVM)
        XCTAssertTrue(display.failureVM?.toastMessage.contains("15") ?? false)
    }
}

// MARK: - Corpus Tests

final class RewardShopCorpusTests: XCTestCase {

    func test_corpusLoads_atLeast30Stickers() {
        XCTAssertGreaterThanOrEqual(RewardShopCorpus.allStickers.count, 30)
    }

    func test_stickerIds_areUnique() {
        let ids = RewardShopCorpus.allStickers.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_pricesAreInExpectedRange() {
        for sticker in RewardShopCorpus.allStickers {
            XCTAssertGreaterThanOrEqual(sticker.price, 15)
            XCTAssertLessThanOrEqual(sticker.price, 300)
        }
    }

    func test_catalogCoversAllCategories() {
        let categories = Set(RewardShopCorpus.allStickers.map(\.category))
        XCTAssertTrue(categories.contains(.achievement))
        XCTAssertTrue(categories.contains(.lyalya))
        XCTAssertTrue(categories.contains(.animal))
    }
}
