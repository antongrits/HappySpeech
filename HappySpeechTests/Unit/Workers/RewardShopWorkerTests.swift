@testable import HappySpeech
import XCTest

// MARK: - RewardShopWorkerTests
//
// Фаза E, Волна 8. LiveRewardShopWorker — преимущественно ТОНКАЯ обёртка над
// RealmActor (loadInventory / loadEarnedCoins / loadSpentCoins / purchase
// просто пробрасывают в RealmActor; бизнес-логика «хватает ли монет / куплено
// ли» — в Interactor). Здесь покрываем доступную чистую часть:
//  • catalog() = RewardShopCorpus.allStickers;
//  • инварианты корпуса (уникальные id, поиск по id);
//  • модель PurchaseError / StickerItem.
// Realm-методы создаются с реальным RealmActor(), но в тестах не вызываются.

@MainActor
final class RewardShopWorkerTests: XCTestCase {

    private func makeSUT() -> LiveRewardShopWorker {
        LiveRewardShopWorker(realmActor: RealmActor())
    }

    // MARK: - catalog

    func test_catalog_matchesCorpus() {
        let sut = makeSUT()
        XCTAssertEqual(sut.catalog().map(\.id), RewardShopCorpus.allStickers.map(\.id))
    }

    func test_catalog_isStableAcrossCalls() {
        let sut = makeSUT()
        XCTAssertEqual(sut.catalog().map(\.id), sut.catalog().map(\.id),
                       "Каталог кэшируется и стабилен")
    }

    func test_catalog_stickerIdsAreUnique() {
        let sut = makeSUT()
        let ids = sut.catalog().map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_catalog_pricesAreNonNegative() {
        let sut = makeSUT()
        XCTAssertTrue(sut.catalog().allSatisfy { $0.price >= 0 })
    }

    // MARK: - RewardShopCorpus.sticker(byId:)

    func test_corpus_stickerById_unknownReturnsNil() {
        XCTAssertNil(RewardShopCorpus.sticker(byId: "no-such-sticker"))
    }

    func test_corpus_stickerById_knownRoundTrips() throws {
        guard let any = RewardShopCorpus.allStickers.first else {
            throw XCTSkip("Каталог стикеров пуст (пак не в test bundle)")
        }
        XCTAssertEqual(RewardShopCorpus.sticker(byId: any.id)?.id, any.id)
    }

    // MARK: - PurchaseError model (pure)

    func test_purchaseError_notEnoughCoins_carriesAmounts() {
        let error = PurchaseError.notEnoughCoins(have: 3, need: 10)
        XCTAssertEqual(error, .notEnoughCoins(have: 3, need: 10))
        XCTAssertNotEqual(error, .notEnoughCoins(have: 3, need: 9))
    }

    func test_purchaseError_distinctCases() {
        XCTAssertNotEqual(PurchaseError.alreadyOwned, PurchaseError.unknownSticker)
    }

    // MARK: - StickerCategory / rarity model

    func test_stickerCategory_titleKeysAreDistinct() {
        let keys = StickerCategory.allCases.map(\.titleKey)
        XCTAssertEqual(keys.count, Set(keys).count)
    }
}
