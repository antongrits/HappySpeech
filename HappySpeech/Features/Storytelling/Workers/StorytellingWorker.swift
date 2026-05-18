import Foundation
import OSLog

// MARK: - StorytellingWorkerProtocol

@MainActor
protocol StorytellingWorkerProtocol: AnyObject {
    /// Загружает темы-стимулы для рассказа.
    func loadTopics(childId: String) async -> StorytellingModels.LoadTopics.Response
    /// Возвращает тему по идентификатору.
    func topic(id: String) -> StorytellingModels.StartTopic.Response?
}

// MARK: - StorytellingWorker (Clean Swift: Worker)
//
// v29 Фаза 8, Функция 11 «Я расскажу историю».
//
// Загружает темы-стимулы из локального корпуса. Offline / on-device.

@MainActor
final class StorytellingWorker: StorytellingWorkerProtocol {

    private let childRepository: any ChildRepository

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "Storytelling.Worker"
    )

    init(childRepository: any ChildRepository) {
        self.childRepository = childRepository
    }

    func loadTopics(
        childId: String
    ) async -> StorytellingModels.LoadTopics.Response {
        do {
            _ = try await childRepository.fetch(id: childId)
        } catch {
            Self.logger.error(
                "Child read failed, topics still served: \(error.localizedDescription, privacy: .public)"
            )
        }
        return .init(topics: StorytellingCorpus.topics)
    }

    func topic(id: String) -> StorytellingModels.StartTopic.Response? {
        guard let topic = StorytellingCorpus.topic(id: id) else {
            Self.logger.error("Unknown topic: \(id, privacy: .public)")
            return nil
        }
        return .init(topic: topic)
    }
}
