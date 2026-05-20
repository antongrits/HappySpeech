import Foundation

// MARK: - RewardShopWorkerProtocol

@MainActor
protocol RewardShopWorkerProtocol {
    func catalog() -> [StickerItem]
    func loadInventory(childId: String) async -> [StickerInventoryData]
    func loadEarnedCoins(childId: String) async -> Int
    func loadSpentCoins(childId: String) async -> Int
    func purchase(childId: String, stickerId: String, price: Int) async -> Bool
}

// MARK: - LiveRewardShopWorker
//
// v31 Волна C Ф.1. Persists всё через RealmActor. Бизнес-логика
// «достаточно ли монет» / «куплено ли уже» проверяется в Interactor
// до вызова worker.purchase — worker возвращает Bool из RealmActor
// (false если запись уже была — uniqueness защита на уровне БД).

@MainActor
final class LiveRewardShopWorker: RewardShopWorkerProtocol {

    private let realmActor: RealmActor

    init(realmActor: RealmActor) {
        self.realmActor = realmActor
    }

    func catalog() -> [StickerItem] {
        RewardShopCorpus.allStickers
    }

    func loadInventory(childId: String) async -> [StickerInventoryData] {
        await realmActor.fetchStickerInventory(childId: childId)
    }

    func loadEarnedCoins(childId: String) async -> Int {
        await realmActor.countRewardRecords(childId: childId)
    }

    func loadSpentCoins(childId: String) async -> Int {
        await realmActor.sumStickerSpending(childId: childId)
    }

    func purchase(childId: String, stickerId: String, price: Int) async -> Bool {
        await realmActor.persistStickerPurchase(
            childId: childId,
            stickerId: stickerId,
            price: price
        )
    }
}
