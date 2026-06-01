import Foundation
import OSLog

// MARK: - PhonemeJourneyMapInteractor

/// Бизнес-логика карты «путешествия по фонемам».
///
/// Прогресс по этапам — РЕАЛЬНЫЙ: целевой звук и завершённые этапы загружаются
/// из `PhonemeJourneyMapWorker` (`ChildRepository` + `SessionRepository`).
/// Никаких фиксированных «Р» с двумя готовыми этапами и никакого ручного
/// переключения статуса — это read-only отражение накопленного прогресса.
/// Без данных все этапы показаны незавершёнными (честное «ещё в пути»).
@MainActor
@Observable
final class PhonemeJourneyMapInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "PhonemeJourneyMap"
    )

    let childId: String
    var state: PhonemeJourneyMapModels.ViewState

    private let worker: (any PhonemeJourneyProgressLoading)?

    init(childId: String, worker: (any PhonemeJourneyProgressLoading)? = nil) {
        self.childId = childId
        self.worker = worker
        self.state = .empty
    }

    /// Загружает реальный прогресс из репозиториев.
    func load() {
        guard let worker else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let progress = await worker.loadProgress(childId: self.childId)
            self.apply(progress)
        }
    }

    private func apply(_ progress: PhonemeJourneyProgress) {
        let sound = progress.targetSound.isEmpty
            ? String(localized: "phonemeJourney.defaultSound")
            : progress.targetSound
        let stages = PhonemeJourneyMapModels.Stage.allCases.map { stage in
            PhonemeJourneyMapModels.StageItem(
                id: stage,
                isComplete: progress.completed[stage] ?? false
            )
        }
        state = PhonemeJourneyMapModels.ViewState(targetSound: sound, stages: stages)
        Self.logger.info("loaded progress sound=\(sound, privacy: .public) done=\(stages.filter(\.isComplete).count, privacy: .public)")
    }
}
