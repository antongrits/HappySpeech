import Foundation
import OSLog

// MARK: - ArticulationGymWorkerProtocol

/// Контракт воркера артикуляционной гимнастики.
protocol ArticulationGymWorkerProtocol: Sendable {
    /// Возвращает набор упражнений для звуковой группы.
    /// Если специфичный набор пуст — возвращает универсальный fallback.
    func loadExercises(soundGroup: ArticulationSoundGroup) -> [ArticulationItem]
}

// MARK: - ArticulationGymWorker (Clean Swift: Worker)
//
// F-302 v25 — изолированный доступ к каталогу упражнений.
//
// Ответственность:
//   • Подобрать набор упражнений по звуковой группе из ``ArticulationCatalog``.
//   • Гарантировать непустой результат — fallback на универсальный набор.
//
// Никаких обращений к микрофону / камере / ML — статичный каталог.

struct ArticulationGymWorker: ArticulationGymWorkerProtocol {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ArticulationGym.Worker"
    )

    func loadExercises(soundGroup: ArticulationSoundGroup) -> [ArticulationItem] {
        let exercises = ArticulationCatalog.exercises(for: soundGroup)
        if exercises.isEmpty {
            Self.logger.error("Empty set for \(soundGroup.rawValue, privacy: .public) — using universal fallback")
            return ArticulationCatalog.universal
        }
        Self.logger.debug("Loaded \(exercises.count) exercises for \(soundGroup.rawValue, privacy: .public)")
        return exercises
    }
}
