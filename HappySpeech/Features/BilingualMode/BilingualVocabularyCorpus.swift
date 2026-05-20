import Foundation
import OSLog

// MARK: - BilingualVocabularyCorpus

/// Стат-фасад над `pack_bilingual_vocabulary.json`. При отказе бандла
/// (например, json не подключён в Resources) — отдаёт безопасный fallback
/// из 6 базовых слов, чтобы фича оставалась рабочей.
enum BilingualVocabularyCorpus {

    static let words: [BilingualWord] = BilingualVocabularyPackLoader.shared.words
    static let categoriesInOrder: [String] = BilingualVocabularyPackLoader.shared.categoriesInOrder
    static let categoryTitles: [String: String] = BilingualVocabularyPackLoader.shared.categoryTitles

    /// Все слова, у которых есть перевод на указанный язык.
    static func words(for language: BilingualSecondLanguage) -> [BilingualWord] {
        guard language != .off else { return [] }
        return words.filter { $0.translation(for: language) != nil }
    }

    /// Группирует слова по категории, сохраняя `categoriesInOrder`.
    static func grouped(
        for language: BilingualSecondLanguage
    ) -> [(category: String, items: [BilingualWord])] {
        let available = words(for: language)
        return categoriesInOrder.compactMap { category in
            let items = available.filter { $0.category == category }
            return items.isEmpty ? nil : (category, items)
        }
    }
}

// MARK: - Pack loader

struct BilingualVocabularyPackLoader {

    static let shared = BilingualVocabularyPackLoader()

    let words: [BilingualWord]
    let categoriesInOrder: [String]
    let categoryTitles: [String: String]

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "BilingualMode.PackLoader"
    )

    // MARK: - DTO

    private struct Pack: Decodable {
        let categoriesInOrder: [String]
        let categoryTitles: [String: String]
        let words: [BilingualWord]
    }

    // MARK: - Init

    private init() {
        guard let url = Bundle.main.url(
            forResource: "pack_bilingual_vocabulary",
            withExtension: "json"
        ) else {
            Self.logger.error(
                "pack_bilingual_vocabulary.json not found — using fallback corpus"
            )
            self.words = Self.fallback()
            self.categoriesInOrder = Self.fallbackCategories
            self.categoryTitles = Self.fallbackCategoryTitles
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let pack = try JSONDecoder().decode(Pack.self, from: data)
            self.words = pack.words
            self.categoriesInOrder = pack.categoriesInOrder
            self.categoryTitles = pack.categoryTitles
            let count = pack.words.count
            Self.logger.info("Loaded \(count) bilingual vocabulary words.")
        } catch {
            Self.logger.error(
                "Decode failed: \(error.localizedDescription) — fallback corpus"
            )
            self.words = Self.fallback()
            self.categoriesInOrder = Self.fallbackCategories
            self.categoryTitles = Self.fallbackCategoryTitles
        }
    }

    // MARK: - Fallback

    private static let fallbackCategories = ["семья", "дом", "животные"]
    private static let fallbackCategoryTitles: [String: String] = [
        "семья":     "Семья",
        "дом":       "Дом",
        "животные":  "Животные"
    ]

    private static func fallback() -> [BilingualWord] {
        [
            BilingualWord(
                id: "fb-1",
                russian: "мама",
                category: "семья",
                symbol: "person.fill",
                translations: ["be-BY": "мама",   "en-US": "mom"]
            ),
            BilingualWord(
                id: "fb-2",
                russian: "папа",
                category: "семья",
                symbol: "person.fill",
                translations: ["be-BY": "тата",   "en-US": "dad"]
            ),
            BilingualWord(
                id: "fb-3",
                russian: "дом",
                category: "дом",
                symbol: "house.fill",
                translations: ["be-BY": "хата",   "en-US": "house"]
            ),
            BilingualWord(
                id: "fb-4",
                russian: "стол",
                category: "дом",
                symbol: "table.furniture.fill",
                translations: ["be-BY": "стол",   "en-US": "table"]
            ),
            BilingualWord(
                id: "fb-5",
                russian: "кот",
                category: "животные",
                symbol: "cat.fill",
                translations: ["be-BY": "кот",    "en-US": "cat"]
            ),
            BilingualWord(
                id: "fb-6",
                russian: "собака",
                category: "животные",
                symbol: "dog.fill",
                translations: ["be-BY": "сабака", "en-US": "dog"]
            )
        ]
    }
}
