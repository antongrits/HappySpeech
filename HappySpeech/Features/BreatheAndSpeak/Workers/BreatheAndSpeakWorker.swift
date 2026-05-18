import Foundation
import OSLog

// MARK: - BreatheAndSpeakWorkerProtocol

@MainActor
protocol BreatheAndSpeakWorkerProtocol: AnyObject {
    /// Подбирает «комплекс дня» под целевые звуки ребёнка.
    func buildComplex(childId: String) async -> BreatheAndSpeakModels.Start.Response
}

// MARK: - BreatheAndSpeakWorker (Clean Swift: Worker)
//
// v29 Фаза 8, Функция 10 «Дыши и говори».
//
// Выбирает методический артикуляционно-дыхательный комплекс под целевую
// группу звуков ребёнка из локального корпуса. Offline / on-device.

@MainActor
final class BreatheAndSpeakWorker: BreatheAndSpeakWorkerProtocol {

    private let childRepository: any ChildRepository

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "BreatheAndSpeak.Worker"
    )

    init(childRepository: any ChildRepository) {
        self.childRepository = childRepository
    }

    func buildComplex(childId: String) async -> BreatheAndSpeakModels.Start.Response {
        let targetSounds: [String]
        do {
            let child = try await childRepository.fetch(id: childId)
            targetSounds = child.targetSounds
        } catch {
            Self.logger.error(
                "Failed to read child sounds, using default complex: \(error.localizedDescription, privacy: .public)"
            )
            targetSounds = []
        }
        let complex = BreatheAndSpeakCorpus.recommendedComplex(for: targetSounds)
        Self.logger.debug(
            "Built breathe-and-speak complex: \(complex.id, privacy: .public), \(complex.exercises.count) steps"
        )
        return .init(complex: complex)
    }
}
