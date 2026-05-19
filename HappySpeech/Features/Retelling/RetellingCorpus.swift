import Foundation
import OSLog

// MARK: - RetellingCorpus
//
// v29 Фаза 8, Функция 2 «Расскажи по-настоящему».
//
// Корпус коротких историй с серией кадров-предложений и разметкой смысловых
// звеньев (герой / место / проблема / решение). Тексты возрастные (6–8 лет),
// частотная лексика, простой синтаксис (Ткаченко, Нищева).
//
// Контент загружается из бандл-ресурса `pack_retelling.json` (~36 историй).
// Полностью offline / on-device.

enum RetellingCorpus {

    /// Полный корпус историй (из `pack_retelling.json`).
    static let stories: [RetellingStory] = RetellingPackLoader.shared.stories

    /// История по идентификатору.
    static func story(id: String) -> RetellingStory? {
        stories.first { $0.id == id }
    }

    /// Случайная история для сессии.
    static func randomStory() -> RetellingStory {
        stories.randomElement() ?? RetellingPackLoader.fallbackStories[0]
    }
}

// MARK: - RetellingPackLoader
//
// Разбирает `pack_retelling.json` один раз. При отказе бандла возвращает
// безопасный минимальный набор, чтобы модуль оставался рабочим.

struct RetellingPackLoader {

    static let shared = RetellingPackLoader()

    let stories: [RetellingStory]

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "Retelling.PackLoader"
    )

    private struct Pack: Decodable {
        let stories: [StoryDTO]
    }

    private struct StoryDTO: Decodable {
        let id: String
        let title: String
        let frames: [FrameDTO]
    }

    private struct FrameDTO: Decodable {
        let id: String
        let sentence: String
        let link: String
        let symbolName: String
    }

    private init() {
        guard let url = Bundle.main.url(
            forResource: "pack_retelling", withExtension: "json"
        ) else {
            Self.logger.error("pack_retelling.json not found in bundle — using fallback")
            stories = RetellingPackLoader.fallbackStories
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let pack = try JSONDecoder().decode(Pack.self, from: data)
            stories = pack.stories.compactMap { dto in
                let frames = dto.frames.compactMap { frame -> StoryFrame? in
                    guard let link = SemanticLinkKind(rawValue: frame.link) else {
                        Self.logger.error("Unknown link: \(frame.link, privacy: .public)")
                        return nil
                    }
                    return StoryFrame(
                        id: frame.id,
                        sentence: frame.sentence,
                        link: link,
                        symbolName: frame.symbolName
                    )
                }
                guard !frames.isEmpty else { return nil }
                return RetellingStory(id: dto.id, title: dto.title, frames: frames)
            }
        } catch {
            Self.logger.error(
                "pack_retelling.json decode error: \(error.localizedDescription, privacy: .public)"
            )
            stories = RetellingPackLoader.fallbackStories
        }
    }

    /// Минимальный безопасный набор на случай отказа бандла.
    static let fallbackStories: [RetellingStory] = [
        RetellingStory(
            id: "cat-and-bird", title: "Кот и птичка",
            frames: [
                .init(id: "cb-1", sentence: "Жил во дворе пушистый кот Мурзик.",
                      link: .hero, symbolName: "cat.fill"),
                .init(id: "cb-2", sentence: "Он гулял по зелёному саду.",
                      link: .place, symbolName: "tree.fill"),
                .init(id: "cb-3", sentence: "Вдруг кот увидел птенчика, который выпал из гнезда.",
                      link: .problem, symbolName: "exclamationmark.bubble.fill"),
                .init(id: "cb-4", sentence: "Мурзик осторожно отнёс птенчика обратно в гнездо.",
                      link: .solution, symbolName: "checkmark.seal.fill")
            ]
        ),
        RetellingStory(
            id: "lost-mitten", title: "Потерянная варежка",
            frames: [
                .init(id: "lm-1", sentence: "Маленькая девочка Катя пошла гулять зимой.",
                      link: .hero, symbolName: "person.fill"),
                .init(id: "lm-2", sentence: "Она каталась с горки в снежном парке.",
                      link: .place, symbolName: "snowflake"),
                .init(id: "lm-3", sentence: "Дома Катя заметила, что потеряла одну варежку.",
                      link: .problem, symbolName: "exclamationmark.bubble.fill"),
                .init(id: "lm-4", sentence: "Мама помогла связать новую тёплую варежку.",
                      link: .solution, symbolName: "checkmark.seal.fill")
            ]
        )
    ]
}
