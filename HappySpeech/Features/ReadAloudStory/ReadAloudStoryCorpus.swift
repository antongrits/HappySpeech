import Foundation
import OSLog

// MARK: - ReadAloudStoryCorpus
//
// v31 Волна D Ф.1 — корпус историй для «Слушай и понимай».
//
// Загружает `pack_readaloud_stories.json` из bundle. Offline / on-device.

enum ReadAloudStoryCorpus {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ReadAloudStory.Corpus"
    )

    /// JSON-обёртка для декодера.
    private struct PackFile: Decodable {
        let stories: [ReadAloudStory]
    }

    /// Все истории корпуса. Кэшируется при первом обращении.
    static let allStories: [ReadAloudStory] = loadFromBundle()

    /// Возвращает случайную историю, исключая `excludeStoryId` (если задан).
    static func randomStory(excluding excludeStoryId: String?) -> ReadAloudStory? {
        let pool = allStories.filter { $0.id != excludeStoryId }
        return pool.randomElement() ?? allStories.first
    }

    /// Возвращает историю по идентификатору.
    static func story(id: String) -> ReadAloudStory? {
        allStories.first { $0.id == id }
    }

    // MARK: - Loading

    private static func loadFromBundle() -> [ReadAloudStory] {
        guard let url = Bundle.main.url(
            forResource: "pack_readaloud_stories",
            withExtension: "json"
        ) else {
            logger.warning("pack_readaloud_stories.json не найден — корпус пуст")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let pack = try JSONDecoder().decode(PackFile.self, from: data)
            logger.info("Загружено историй: \(pack.stories.count, privacy: .public)")
            return pack.stories
        } catch {
            logger.error(
                "Не удалось разобрать pack_readaloud_stories.json: \(error.localizedDescription, privacy: .public)"
            )
            return []
        }
    }
}
