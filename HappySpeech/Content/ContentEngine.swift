import Foundation
import OSLog

// MARK: - ContentEngine

/// Assembles Lessons from content packs using the (sound × stage × template) matrix.
/// Supports 6000+ content units through combinatorial expansion.
@Observable
public final class ContentEngine {

    // MARK: - Properties

    var loadedPacks: [String: ContentPack] = [:]
    private let contentService: any ContentService

    public init(contentService: any ContentService) {
        self.contentService = contentService
    }

    // MARK: - Public API

    /// Builds a Lesson for the given parameters.
    public func buildLesson(
        sound: String,
        stage: CorrectionStage,
        template: TemplateType,
        difficulty: Int = 1,
        wordCount: Int = 10
    ) async throws -> Lesson {
        let packId = packID(sound: sound, stage: stage, template: template)

        // Load pack if needed
        if loadedPacks[packId] == nil {
            let pack = try await contentService.loadPack(id: packId)
            loadedPacks[packId] = pack
        }

        let pack = loadedPacks[packId]!
        let items = filterItems(from: pack.items, difficulty: difficulty, count: wordCount)

        HSLogger.content.info("Built lesson: \(sound) \(stage.rawValue) \(template.rawValue) ×\(items.count)")
        return Lesson(
            id: UUID().uuidString,
            sound: sound,
            stage: stage,
            template: template,
            difficulty: difficulty,
            items: items
        )
    }

    /// Returns all available packs for a given sound.
    public func availableLessons(for sound: String) -> [LessonDescriptor] {
        CorrectionStage.allCases.flatMap { stage in
            TemplateType.allCases.compactMap { template in
                guard isTemplateCompatible(template, with: stage) else { return nil }
                return LessonDescriptor(
                    sound: sound,
                    stage: stage,
                    template: template,
                    packId: packID(sound: sound, stage: stage, template: template)
                )
            }
        }
    }

    /// Estimates total content count via the matrix formula.
    public var estimatedContentCount: Int {
        let sounds = 22  // С З Ц Ш Ж Ч Щ Р Рь Л Ль К Г Х + variants
        let stages = CorrectionStage.allCases.count
        let templates = TemplateType.allCases.count
        let wordsPerPack = 40
        return sounds * stages * min(templates, 6) * wordsPerPack
    }

    // MARK: - Private Helpers

    private func packID(sound: String, stage: CorrectionStage, template: TemplateType) -> String {
        "\(sound)-\(stage.rawValue)-\(template.rawValue)-v1"
    }

    private func filterItems(from items: [ContentItem], difficulty: Int, count: Int) -> [ContentItem] {
        let filtered = items.filter { $0.difficulty <= difficulty + 1 }
        let shuffled = filtered.shuffled()
        return Array(shuffled.prefix(count))
    }

    /// Returns true if the template makes sense for the given correction stage.
    private func isTemplateCompatible(_ template: TemplateType, with stage: CorrectionStage) -> Bool {
        switch stage {
        case .prep:
            return [.articulationImitation, .breathing, .rhythm, .arActivity].contains(template)
        case .isolated:
            return [.listenAndChoose, .sorting, .soundHunter, .articulationImitation, .arActivity].contains(template)
        case .syllable:
            return [.listenAndChoose, .sorting, .repeatAfterModel, .bingo, .rhythm].contains(template)
        case .wordInit, .wordMed, .wordFinal:
            return [.listenAndChoose, .repeatAfterModel, .dragAndMatch, .memory, .bingo,
                    .soundHunter, .puzzleReveal, .visualAcoustic, .minimalPairs].contains(template)
        case .phrase:
            return [.storyCompletion, .dragAndMatch, .repeatAfterModel, .sorting, .minimalPairs].contains(template)
        case .sentence:
            return [.storyCompletion, .narrativeQuest, .repeatAfterModel, .minimalPairs].contains(template)
        case .story:
            return [.narrativeQuest, .storyCompletion].contains(template)
        case .diff:
            return [.minimalPairs, .sorting, .listenAndChoose, .memory].contains(template)
        }
    }
}

// MARK: - Lesson

public struct Lesson: Sendable {
    public let id: String
    public let sound: String
    public let stage: CorrectionStage
    public let template: TemplateType
    public let difficulty: Int
    public let items: [ContentItem]

    public var wordCount: Int { items.count }
}

// MARK: - LessonDescriptor

public struct LessonDescriptor: Sendable {
    public let sound: String
    public let stage: CorrectionStage
    public let template: TemplateType
    public let packId: String
}

// MARK: - Seed Content

/// Hardcoded seed content for С, Ш, Р sound groups.
/// Production content loaded from bundled JSON packs in Resources/Content/.
public enum SeedContent {

    // MARK: - Р (sonorant) — Stage wordInit (40 words)
    public static let rWordInit: [ContentItem] = [
        "рак", "рыба", "роза", "рот", "рис", "ром", "рог", "ряд",
        "рай", "река", "рожь", "рот", "рос", "руль", "рой", "рот",
        "радуга", "ракета", "робот", "рукав", "рябина", "рыбак",
        "рояль", "рулон", "ромашка", "роща", "рынок", "рысь",
        "решётка", "ребёнок", "рогатка", "родник", "рубашка",
        "русалка", "ручей", "расчёска", "радость", "рисунок",
        "родители", "родина"
    ].enumerated().map { idx, word in
        ContentItem(id: "r-wordinit-\(idx)", word: word, imageAsset: nil, audioAsset: nil,
                    hint: nil, stage: .wordInit, difficulty: idx < 20 ? 1 : 2)
    }

    // MARK: - С (whistling) — Stage wordInit (40 words)
    public static let sWordInit: [ContentItem] = [
        "сад", "сок", "суп", "сом", "сон", "сор", "сук", "сыр",
        "сам", "сор", "собака", "сумка", "слива", "снег", "стол",
        "стул", "стакан", "сапог", "салат", "самолёт", "сарафан",
        "светофор", "свитер", "сердце", "сестра", "скамейка",
        "скрипка", "слон", "сметана", "смородина", "снежинка",
        "совёнок", "соловей", "сосна", "сосулька", "спасибо",
        "спина", "стрекоза", "субботник", "сухарик"
    ].enumerated().map { idx, word in
        ContentItem(id: "s-wordinit-\(idx)", word: word, imageAsset: nil, audioAsset: nil,
                    hint: nil, stage: .wordInit, difficulty: idx < 20 ? 1 : 2)
    }

    // MARK: - Ш (hissing) — Stage wordInit (40 words)
    public static let shWordInit: [ContentItem] = [
        "шар", "шум", "шаг", "шёл", "шов", "шест", "шея", "шило",
        "шапка", "шарф", "шкаф", "шлем", "шнур", "шорты", "шубка",
        "шалаш", "шахмат", "шахта", "шахтёр", "шашки", "швабра",
        "шведский", "шиповник", "шоколад", "шорник", "штаны",
        "шторка", "шофёр", "шпаргалка", "шпилька", "шприц",
        "шрифт", "шурин", "шутка", "шхуна", "шахматист",
        "шоколадка", "шапочка", "шарфик", "шнурок"
    ].enumerated().map { idx, word in
        ContentItem(id: "sh-wordinit-\(idx)", word: word, imageAsset: nil, audioAsset: nil,
                    hint: nil, stage: .wordInit, difficulty: idx < 20 ? 1 : 2)
    }
}
