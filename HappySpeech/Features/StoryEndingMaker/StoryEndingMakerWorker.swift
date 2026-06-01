import Foundation
import OSLog

// MARK: - StoryEndingMakerWorkerProtocol

@MainActor
protocol StoryEndingMakerWorkerProtocol: AnyObject {
    /// Подбирает картинки-концовки из реального словаря под группы звуков ребёнка.
    func buildCards(childId: String) async -> [StoryEndingMakerModels.PictureCard]
}

// MARK: - StoryEndingMakerWorker (Clean Swift: Worker)
//
// Формирует набор «картинок-концовок» истории из bundled-манифеста
// (`LessonContentMap`) под рабочие звуки ребёнка. Ребёнок выбирает картинку и
// придумывает/записывает с ней концовку. Offline / on-device.

@MainActor
final class StoryEndingMakerWorker: StoryEndingMakerWorkerProtocol {

    static let cardCount = 3

    private let childRepository: any ChildRepository

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "StoryEndingMaker.Worker"
    )

    init(childRepository: any ChildRepository) {
        self.childRepository = childRepository
    }

    func buildCards(childId: String) async -> [StoryEndingMakerModels.PictureCard] {
        var targetSounds: [String] = []
        if !childId.isEmpty {
            do {
                targetSounds = try await childRepository.fetch(id: childId).targetSounds
            } catch {
                Self.logger.error("child fetch failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        let groups = KidWordContentProvider.groups(forTargetSounds: targetSounds)
        var pool: [KidWordContentProvider.GameWord] = []
        for group in groups {
            pool.append(contentsOf: KidWordContentProvider.words(in: group))
        }
        // Предпочитаем слова с иллюстрацией.
        let withAsset = pool.filter { $0.asset != nil }.shuffled()
        let chosen = (withAsset.isEmpty ? pool.shuffled() : withAsset).prefix(Self.cardCount)

        let cards = chosen.map { word in
            StoryEndingMakerModels.PictureCard(
                id: word.id,
                asset: word.asset,
                label: word.text
            )
        }
        Self.logger.debug("built \(cards.count) ending cards")
        return Array(cards)
    }
}
