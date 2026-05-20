import Foundation
import OSLog

// MARK: - RewardShopCorpus
//
// v31 Волна C, Функция Ф.1 «Магазин наград».
//
// Загружает каталог стикеров из bundled JSON
// `Content/Seed/pack_sticker_shop.json` (≈40 стикеров в 5 категориях).
// Полностью offline / on-device.

public enum RewardShopCorpus {

    public static var allStickers: [StickerItem] { loadOnce() }

    public static func sticker(byId id: String) -> StickerItem? {
        allStickers.first { $0.id == id }
    }

    // MARK: - Private

    private nonisolated(unsafe) static var cached: [StickerItem] = []
    private nonisolated(unsafe) static var didLoad = false
    private static let cacheLock = NSLock()

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "RewardShop.Corpus"
    )

    private static func loadOnce() -> [StickerItem] {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if didLoad { return cached }
        didLoad = true
        cached = decodeBundledPack()
        logger.info("RewardShopCorpus loaded: \(cached.count, privacy: .public) stickers")
        return cached
    }

    private static func decodeBundledPack() -> [StickerItem] {
        guard let url = Bundle.main.url(forResource: "pack_sticker_shop", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            logger.warning("pack_sticker_shop.json не найден — каталог пуст")
            return []
        }
        do {
            let pack = try JSONDecoder().decode(StickerPackDTO.self, from: data)
            return pack.stickers.map { dto in
                StickerItem(
                    id: dto.id,
                    name: dto.name,
                    price: dto.price,
                    category: StickerCategory(rawValue: dto.category) ?? .achievement,
                    imageName: dto.imageName,
                    rarity: ShopStickerRarity(rawValue: dto.rarity) ?? .common
                )
            }
        } catch {
            logger.error("pack_sticker_shop.json decode error: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}

// MARK: - JSON DTO

private struct StickerPackDTO: Decodable {
    let version: String
    let stickers: [StickerDTO]

    struct StickerDTO: Decodable {
        let id: String
        let name: String
        let price: Int
        let category: String
        let imageName: String
        let rarity: String
    }
}
