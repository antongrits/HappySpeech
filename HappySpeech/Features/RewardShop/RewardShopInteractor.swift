import Foundation
import OSLog

// MARK: - RewardShopBusinessLogic

@MainActor
protocol RewardShopBusinessLogic: AnyObject {
    func load(request: RewardShopModels.Load.Request) async
    func purchase(request: RewardShopModels.Purchase.Request) async
}

// MARK: - RewardShopDataStore

@MainActor
protocol RewardShopDataStore: AnyObject {
    var childId: String { get set }
    var coinsEarned: Int { get }
    var coinsSpent: Int { get }
    var ownedStickerIds: Set<String> { get }
}

// MARK: - RewardShopInteractor (Clean Swift: Interactor)
//
// v31 Волна C Ф.1 «Магазин наград».

@MainActor
final class RewardShopInteractor: RewardShopBusinessLogic, RewardShopDataStore {

    var childId: String
    private(set) var coinsEarned: Int = 0
    private(set) var coinsSpent: Int = 0
    private(set) var ownedStickerIds: Set<String> = []

    var presenter: (any RewardShopPresentationLogic)?

    private let worker: any RewardShopWorkerProtocol
    private let hapticService: any HapticService

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "RewardShop.Interactor"
    )

    init(
        childId: String,
        worker: any RewardShopWorkerProtocol,
        hapticService: any HapticService
    ) {
        self.childId = childId
        self.worker = worker
        self.hapticService = hapticService
    }

    func load(request: RewardShopModels.Load.Request) async {
        childId = request.childId
        let earned = await worker.loadEarnedCoins(childId: childId)
        let spent = await worker.loadSpentCoins(childId: childId)
        let inventory = await worker.loadInventory(childId: childId)
        let owned = Set(inventory.map(\.stickerId))
        let catalog = worker.catalog()
        coinsEarned = earned
        coinsSpent = spent
        ownedStickerIds = owned
        await presenter?.presentLoad(response: .init(
            coinsEarned: earned,
            coinsSpent: spent,
            ownedStickerIds: owned,
            catalog: catalog
        ))
    }

    func purchase(request: RewardShopModels.Purchase.Request) async {
        guard let sticker = worker.catalog().first(where: { $0.id == request.stickerId }) else {
            Self.logger.warning("Sticker \(request.stickerId, privacy: .public) not in catalog")
            await presenter?.presentPurchaseFailure(response: .init(
                stickerId: request.stickerId,
                reason: .unknownSticker
            ))
            return
        }
        if ownedStickerIds.contains(sticker.id) {
            await presenter?.presentPurchaseFailure(response: .init(
                stickerId: sticker.id,
                reason: .alreadyOwned
            ))
            return
        }
        let balance = max(0, coinsEarned - coinsSpent)
        guard balance >= sticker.price else {
            await presenter?.presentPurchaseFailure(response: .init(
                stickerId: sticker.id,
                reason: .notEnoughCoins(have: balance, need: sticker.price)
            ))
            return
        }
        let success = await worker.purchase(
            childId: childId,
            stickerId: sticker.id,
            price: sticker.price
        )
        guard success else {
            // Race condition защита — БД отказала (дубликат) — обрабатываем как уже куплено.
            await presenter?.presentPurchaseFailure(response: .init(
                stickerId: sticker.id,
                reason: .alreadyOwned
            ))
            return
        }
        coinsSpent += sticker.price
        ownedStickerIds.insert(sticker.id)
        hapticService.notification(.success)
        await presenter?.presentPurchaseSuccess(response: .init(
            stickerId: sticker.id,
            stickerName: sticker.name,
            newBalance: max(0, coinsEarned - coinsSpent)
        ))
        // Re-present catalog with new owned/balance state.
        await presenter?.presentLoad(response: .init(
            coinsEarned: coinsEarned,
            coinsSpent: coinsSpent,
            ownedStickerIds: ownedStickerIds,
            catalog: worker.catalog()
        ))
    }
}
