import Foundation
import OSLog

// MARK: - PhonemeFamilyMatcherInteractor

/// Бизнес-логика игры «Разложи по семьям звуков».
///
/// Слова собираются `PhonemeFamilyMatcherWorker` из реального словаря. Каждое
/// назначение фиксируется в интервальном планировщике повторов, по завершении
/// (все слова разложены) — итоговый SM-2 результат для группы звуков.
@MainActor
@Observable
final class PhonemeFamilyMatcherInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "PhonemeFamilyMatcher"
    )

    let childId: String
    var state: PhonemeFamilyMatcherModels.ViewState = .initial

    private let worker: (any PhonemeFamilyMatcherWorkerProtocol)?
    private let adaptivePlanner: (any AdaptivePlannerService)?
    private var recordedSession = false

    init(
        childId: String,
        worker: (any PhonemeFamilyMatcherWorkerProtocol)? = nil,
        adaptivePlanner: (any AdaptivePlannerService)? = nil
    ) {
        self.childId = childId
        self.worker = worker
        self.adaptivePlanner = adaptivePlanner
    }

    func load() async {
        guard let worker else {
            state.isLoaded = true
            return
        }
        let words = await worker.buildWords(childId: childId)
        state.words = words
        state.isLoaded = true
        recordedSession = false
        Self.logger.info("loaded \(words.count, privacy: .public) words")
    }

    func assign(_ wordId: String, to family: PhonemeFamilyMatcherModels.Family) {
        guard let idx = state.words.firstIndex(where: { $0.id == wordId }) else { return }
        let word = state.words[idx]
        state.words[idx].assignedFamily = family
        let correct = word.family == family
        recordOutcome(word: word, correct: correct)
        Self.logger.info("assign \(wordId, privacy: .public) → \(family.rawValue, privacy: .public) correct=\(correct)")
        if state.allAssigned {
            recordSession()
        }
    }

    func reset() {
        for idx in state.words.indices {
            state.words[idx].assignedFamily = nil
        }
        recordedSession = false
    }

    // MARK: - Persistence

    private func recordOutcome(word: PhonemeFamilyMatcherModels.Word, correct: Bool) {
        guard let planner = adaptivePlanner, !childId.isEmpty else { return }
        Task { [weak self] in
            guard let self else { return }
            await planner.recordItemOutcome(
                childId: self.childId,
                itemId: word.id,
                sound: word.family.representativeSound,
                correct: correct
            )
        }
    }

    private func recordSession() {
        guard !recordedSession, let planner = adaptivePlanner, !childId.isEmpty, !state.words.isEmpty else { return }
        recordedSession = true
        let rate = Double(state.matchedCount) / Double(state.words.count)
        let quality = SM2Quality.fromSuccessRate(rate)
        // Записываем по группе с наибольшей долей слов в наборе (рабочая группа).
        let sound = state.words.first?.family.representativeSound ?? "С"
        Task { [weak self] in
            guard let self else { return }
            do {
                try await planner.recordSessionResult(
                    childId: self.childId,
                    soundTarget: sound,
                    qualityScore: quality
                )
            } catch {
                Self.logger.error("recordSession failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
