import Foundation
import OSLog

// MARK: - RetellingWorkerProtocol

@MainActor
protocol RetellingWorkerProtocol: AnyObject {
    /// Выбирает историю для пересказа.
    func pickStory(childId: String) async -> RetellingModels.Start.Response
}

// MARK: - RetellingWorker (Clean Swift: Worker)
//
// v29 Фаза 8, Функция 2 «Расскажи по-настоящему».
//
// Выбирает короткую историю из локального корпуса. Offline / on-device.

@MainActor
final class RetellingWorker: RetellingWorkerProtocol {

    private let childRepository: any ChildRepository

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "Retelling.Worker"
    )

    init(childRepository: any ChildRepository) {
        self.childRepository = childRepository
    }

    func pickStory(childId: String) async -> RetellingModels.Start.Response {
        // Чтение профиля подтверждает доступность ребёнка; история берётся
        // из корпуса (контент не зависит от целевых звуков).
        do {
            _ = try await childRepository.fetch(id: childId)
        } catch {
            Self.logger.error(
                "Child read failed, story still served: \(error.localizedDescription, privacy: .public)"
            )
        }
        let story = RetellingCorpus.randomStory()
        Self.logger.debug("Picked story: \(story.id, privacy: .public)")
        return .init(story: story)
    }
}
