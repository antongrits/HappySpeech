import Foundation
import Observation
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

        guard let pack = loadedPacks[packId] else {
            throw AppError.contentPackNotFound("Pack \(packId) failed to load")
        }
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

    // MARK: - Variation Generation (gap #2)

    @ObservationIgnored
    private var _variationGenerator: ContentVariationGenerator?

    /// Рантайм-генератор вариаций контента уроков. Собирает активности по матрице
    /// `звук × этап × шаблон [× тема]` из существующих паков, со строгой
    /// анти-пустышкой и методическими гейтами. См. ``ContentVariationGenerator``.
    /// Один shared-инстанс на движок (ленивая инициализация).
    public var variationGenerator: ContentVariationGenerator {
        if let existing = _variationGenerator { return existing }
        let new = ContentVariationGenerator(contentService: contentService)
        _variationGenerator = new
        return new
    }

    /// Полный каталог реально-наполняемых сгенерированных активностей (≈766 по
    /// матрице). Заменяет устаревший `estimatedContentCount`, который считал
    /// слова-копии. Ленивая, детерминированная генерация — без пустышек.
    public func generatedCatalog() async -> [GeneratedActivity] {
        await variationGenerator.fullCatalog()
    }

    /// Сгенерированные активности конкретного звука.
    public func generatedActivities(for sound: String) async -> [GeneratedActivity] {
        await variationGenerator.generateActivities(for: sound)
    }

    /// Честное число валидных активностей, реально выдаваемых генератором.
    /// Замена `estimatedContentCount`: считает активности (по правилам матрицы),
    /// а не слова-копии.
    public func generatedActivityCount() async -> Int {
        await variationGenerator.totalActivityCount()
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
