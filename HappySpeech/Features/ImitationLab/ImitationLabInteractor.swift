import Foundation
import OSLog

// MARK: - ImitationLabInteractor

/// Бизнес-логика «Лаборатории подражания» (articulation-imitation).
///
/// Образцы отбираются под рабочие звуки ребёнка (`ImitationLabContent` через
/// `ChildRepository`). Цикл: послушать образец → повторить вслух → отметить
/// «получилось». Каждая отметка фиксируется в интервальном планировщике, по
/// завершении набора — итоговый SM-2 результат и рекорд звёзд. Без репозитория
/// (Preview/тесты) — стартовый набор.
@MainActor
@Observable
final class ImitationLabInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ImitationLab"
    )

    let childId: String
    var state: ImitationLabModels.ViewState = .empty

    private let childRepository: (any ChildRepository)?
    private let adaptivePlanner: (any AdaptivePlannerService)?
    private let scoreStore: KidGameScoreStore

    init(
        childId: String,
        childRepository: (any ChildRepository)? = nil,
        adaptivePlanner: (any AdaptivePlannerService)? = nil
    ) {
        self.childId = childId
        self.childRepository = childRepository
        self.adaptivePlanner = adaptivePlanner
        self.scoreStore = KidGameScoreStore(gameKey: "imitationLab", childId: childId)
    }

    /// Собирает набор образцов под рабочие звуки ребёнка.
    func load() async {
        var targets: [String] = []
        if let childRepository, !childId.isEmpty {
            do {
                targets = try await childRepository.fetch(id: childId).targetSounds
            } catch {
                Self.logger.error("child fetch failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        state.samples = ImitationLabContent.samples(forTargetSounds: targets)
        state.currentSampleId = nil
        state.bestStars = scoreStore.bestStars
        state.isLoaded = true
        Self.logger.info("loaded \(self.state.samples.count, privacy: .public) samples")
    }

    /// Прослушать образец (выделить активным).
    func playSample(_ id: String) {
        guard let idx = state.samples.firstIndex(where: { $0.id == id }) else { return }
        state.samples[idx].isPlayed = true
        state.currentSampleId = id
        Self.logger.info("play sample \(id, privacy: .public)")
    }

    /// Отметить, что ребёнок повторил образец вслух («получилось»).
    func markPracticed(_ id: String) {
        guard let idx = state.samples.firstIndex(where: { $0.id == id }),
              !state.samples[idx].isPracticed else { return }
        state.samples[idx].isPracticed = true
        let sample = state.samples[idx]
        recordOutcome(sample: sample)
        Self.logger.info("practiced \(id, privacy: .public)")
        if state.isComplete { finish() }
    }

    func reset() {
        state.samples = state.samples.map {
            var sample = $0
            sample.isPlayed = false
            sample.isPracticed = false
            return sample
        }
        state.currentSampleId = nil
    }

    // MARK: - Persistence

    private func recordOutcome(sample: ImitationLabModels.SoundSample) {
        guard let planner = adaptivePlanner, !childId.isEmpty else { return }
        Task { [weak self] in
            guard let self else { return }
            await planner.recordItemOutcome(
                childId: self.childId,
                itemId: "imitation-\(sample.id)",
                sound: sample.soundFamily,
                // Подражание — мягкий формат: отмеченный образец считаем удачным.
                correct: true
            )
        }
    }

    private func finish() {
        let starsEarned = state.stars
        if scoreStore.recordCompletion(stars: starsEarned) {
            state.bestStars = starsEarned
        }
        guard let planner = adaptivePlanner, !childId.isEmpty else { return }
        let sound = state.samples.first?.soundFamily ?? "С"
        Task { [weak self] in
            guard let self else { return }
            do {
                try await planner.recordSessionResult(
                    childId: self.childId,
                    soundTarget: sound,
                    qualityScore: .perfect
                )
            } catch {
                Self.logger.error("recordSession failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
