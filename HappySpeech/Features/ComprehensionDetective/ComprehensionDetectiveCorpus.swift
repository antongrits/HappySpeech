import Foundation
import OSLog

// MARK: - ComprehensionDetectiveCorpus
//
// v31 Волна B, Функция Ф.2 «Понимание-детектив».
//
// Загрузчик корпуса инструкций для импрессивной речи из bundled JSON
// `Content/Seed/pack_impressive_speech.json`. ~120 пунктов на 4 уровня
// грамматической сложности по Левиной. Полностью offline / on-device.

public enum ComprehensionDetectiveCorpus {

    public static var allItems: [DetectiveItem] { loadOnce() }

    public static func items(for tier: GrammarTier) -> [DetectiveItem] {
        allItems.filter { $0.tier == tier }
    }

    public static var availableTiers: [GrammarTier] {
        let present = Set(allItems.map(\.tier))
        return GrammarTier.allCases.filter { present.contains($0) }
    }

    // MARK: - Private

    private nonisolated(unsafe) static var cached: [DetectiveItem] = []
    private nonisolated(unsafe) static var didLoad = false
    private static let cacheLock = NSLock()

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ComprehensionDetective.Corpus"
    )

    private static func loadOnce() -> [DetectiveItem] {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if didLoad { return cached }
        didLoad = true
        cached = decodeBundledPack()
        logger.info("DetectiveCorpus loaded: \(cached.count, privacy: .public) items")
        return cached
    }

    private static func decodeBundledPack() -> [DetectiveItem] {
        guard let url = Bundle.main.url(forResource: "pack_impressive_speech", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            logger.warning("pack_impressive_speech.json не найден в bundle — корпус пуст")
            return []
        }
        do {
            let pack = try JSONDecoder().decode(DetectivePackDTO.self, from: data)
            return pack.tiers.flatMap { tierDTO -> [DetectiveItem] in
                guard let tier = GrammarTier(rawValue: tierDTO.tier) else { return [] }
                return tierDTO.items.compactMap { item in
                    Self.makeItem(itemDTO: item, tier: tier)
                }
            }
        } catch {
            logger.error("pack_impressive_speech.json decode error: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private static func makeItem(itemDTO: DetectivePackDTO.ItemDTO, tier: GrammarTier) -> DetectiveItem? {
        // Картинки: первая — правильная (correct), затем distractor'ы.
        let allSymbols = [itemDTO.correct] + itemDTO.distractors
        let pictures = allSymbols.map { symbol -> DetectivePicture in
            let label = itemDTO.labels[symbol] ?? symbol
            return DetectivePicture(
                id: "\(itemDTO.id)-\(symbol)",
                symbolName: symbol,
                label: label
            )
        }
        guard let correctPicture = pictures.first else { return nil }
        return DetectiveItem(
            id: itemDTO.id,
            tier: tier,
            instruction: itemDTO.instruction,
            pictures: pictures,
            correctPictureId: correctPicture.id
        )
    }
}

// MARK: - JSON DTOs

private struct DetectivePackDTO: Decodable {
    let tiers: [TierDTO]

    struct TierDTO: Decodable {
        let tier: Int
        let items: [ItemDTO]
    }

    struct ItemDTO: Decodable {
        let id: String
        let instruction: String
        let correct: String
        let distractors: [String]
        let labels: [String: String]
    }
}
