import Foundation
import OSLog

// MARK: - OralStoryCreatorCorpus

enum OralStoryCreatorCorpus {

    static let stimuli: [StimulusPicture] = StoryCreatorPackLoader.shared.stimuli
    static let categoriesInOrder: [String] = StoryCreatorPackLoader.shared.categoriesInOrder

    /// Сколько картинок ребёнок выбирает.
    static let pickCountTarget: Int = 3

    /// Группирует стимулы по категориям, сохраняя порядок из `categoriesInOrder`.
    static func grouped() -> [(category: String, items: [StimulusPicture])] {
        categoriesInOrder.map { category in
            (category, stimuli.filter { $0.category == category })
        }
    }
}

// MARK: - Loader

struct StoryCreatorPackLoader {

    static let shared = StoryCreatorPackLoader()

    let stimuli: [StimulusPicture]
    let categoriesInOrder: [String]

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "StoryCreator.PackLoader"
    )

    private struct Pack: Decodable {
        let categoriesInOrder: [String]
        let stimuli: [StimulusDTO]
    }

    private struct StimulusDTO: Decodable {
        let id: String
        let title: String
        let category: String
        let symbol: String
    }

    private init() {
        guard let url = Bundle.main.url(forResource: "pack_storycreator_stimuli", withExtension: "json") else {
            Self.logger.error("pack_storycreator_stimuli.json not found — fallback")
            self.stimuli = Self.fallback()
            self.categoriesInOrder = ["герои", "места", "предметы"]
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let pack = try JSONDecoder().decode(Pack.self, from: data)
            self.categoriesInOrder = pack.categoriesInOrder
            self.stimuli = pack.stimuli.map { dto in
                StimulusPicture(
                    id: dto.id,
                    title: dto.title,
                    category: dto.category,
                    symbol: dto.symbol
                )
            }
            let count = self.stimuli.count
            Self.logger.info("Loaded \(count) story-creator stimuli.")
        } catch {
            Self.logger.error("Decode failed: \(error.localizedDescription)")
            self.stimuli = Self.fallback()
            self.categoriesInOrder = ["герои", "места", "предметы"]
        }
    }

    private static func fallback() -> [StimulusPicture] {
        [
            .init(id: "h_fb_1", title: "Мама", category: "герои", symbol: "person.fill"),
            .init(id: "h_fb_2", title: "Котик", category: "герои", symbol: "cat.fill"),
            .init(id: "p_fb_1", title: "Парк", category: "места", symbol: "tree.fill"),
            .init(id: "o_fb_1", title: "Мяч", category: "предметы", symbol: "soccerball")
        ]
    }
}
