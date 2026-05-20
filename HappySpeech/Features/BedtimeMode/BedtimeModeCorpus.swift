import Foundation
import OSLog

// MARK: - BedtimeModeCorpus
//
// v31 Волна B, Функция Ф.3 «Bedtime mode».
//
// Загружает спокойные истории на ночь из bundled JSON
// `Content/Seed/pack_bedtime_stories.json` (≈12 коротких сказок).
// Полностью offline / on-device.

public enum BedtimeModeCorpus {

    public static var allStories: [BedtimeStory] { loadOnce() }

    public static func randomStory(excluding excludeId: String? = nil) -> BedtimeStory? {
        let pool = allStories
        let remaining = pool.filter { $0.id != excludeId }
        return remaining.randomElement() ?? pool.randomElement()
    }

    // MARK: - Private

    private nonisolated(unsafe) static var cached: [BedtimeStory] = []
    private nonisolated(unsafe) static var didLoad = false
    private static let cacheLock = NSLock()

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "BedtimeMode.Corpus"
    )

    private static func loadOnce() -> [BedtimeStory] {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if didLoad { return cached }
        didLoad = true
        cached = decodeBundledPack()
        logger.info("BedtimeCorpus loaded: \(cached.count, privacy: .public) stories")
        return cached
    }

    private static func decodeBundledPack() -> [BedtimeStory] {
        guard let url = Bundle.main.url(forResource: "pack_bedtime_stories", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            logger.warning("pack_bedtime_stories.json не найден — корпус пуст")
            return []
        }
        do {
            let pack = try JSONDecoder().decode(BedtimePackDTO.self, from: data)
            return pack.stories.map { BedtimeStory(id: $0.id, title: $0.title, text: $0.text) }
        } catch {
            logger.error("pack_bedtime_stories.json decode error: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}

// MARK: - JSON DTO

private struct BedtimePackDTO: Decodable {
    let stories: [StoryDTO]

    struct StoryDTO: Decodable {
        let id: String
        let title: String
        let text: String
    }
}
