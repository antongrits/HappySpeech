import Foundation
import OSLog

// MARK: - CoPlayWorkerProtocol

@MainActor
protocol CoPlayWorkerProtocol: AnyObject {
    /// Выбирает сценарий совместной игры.
    func pickActivity(childId: String) async -> CoPlayModels.Start.Response
}

// MARK: - CoPlayWorker (Clean Swift: Worker)
//
// v29 Фаза 8, Функция 8 «Занятие вместе».
//
// Выбирает сценарий из локального корпуса. Offline / on-device.

@MainActor
final class CoPlayWorker: CoPlayWorkerProtocol {

    private let childRepository: any ChildRepository

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "CoPlay.Worker"
    )

    init(childRepository: any ChildRepository) {
        self.childRepository = childRepository
    }

    func pickActivity(childId: String) async -> CoPlayModels.Start.Response {
        do {
            _ = try await childRepository.fetch(id: childId)
        } catch {
            Self.logger.error(
                "Child read failed, activity still served: \(error.localizedDescription, privacy: .public)"
            )
        }
        let activity = CoPlayCorpus.randomActivity()
        Self.logger.debug("Picked co-play activity: \(activity.id, privacy: .public)")
        return .init(activity: activity)
    }
}
