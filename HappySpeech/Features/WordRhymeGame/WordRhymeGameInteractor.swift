import Foundation
import OSLog

// MARK: - WordRhymeGameInteractor

/// Бизнес-логика игры «Найди рифму».
///
/// Раунды собираются `WordRhymeGameWorker` из реального словаря под группы
/// звуков ребёнка. Каждый правильный/неправильный ответ фиксируется в
/// интервальном планировщике повторов (`AdaptivePlannerService`), по
/// завершении сессии — итоговый SM-2 результат. Без репозитория/childId
/// (Preview, тесты) экран остаётся на пустом загрузочном состоянии.
@MainActor
@Observable
final class WordRhymeGameInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "WordRhymeGame"
    )

    let childId: String
    var state: WordRhymeGameModels.ViewState = .initial

    private let worker: (any WordRhymeGameWorkerProtocol)?
    private let adaptivePlanner: (any AdaptivePlannerService)?

    init(
        childId: String,
        worker: (any WordRhymeGameWorkerProtocol)? = nil,
        adaptivePlanner: (any AdaptivePlannerService)? = nil
    ) {
        self.childId = childId
        self.worker = worker
        self.adaptivePlanner = adaptivePlanner
    }

    /// Загружает раунды из словаря. Без worker (Preview/тесты) помечает
    /// состояние загруженным с пустым списком (показывается empty-state).
    func load() async {
        guard let worker else {
            state.isLoaded = true
            return
        }
        let rounds = await worker.buildRounds(childId: childId)
        state.rounds = rounds
        state.index = 0
        state.score = 0
        state.feedback = .none
        state.isLoaded = true
        Self.logger.info("loaded \(rounds.count, privacy: .public) rounds")
    }

    func answer(_ optionId: String) {
        guard let current = state.current else { return }
        let isCorrect = optionId == current.correctOptionId
        if isCorrect {
            state.score += 1
            state.feedback = .correct
            recordOutcome(round: current, correct: true)
            Self.logger.info("correct \(current.id, privacy: .public)")
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(700))
                await MainActor.run { self?.advance() }
            }
        } else {
            state.feedback = .wrong(optionId)
            recordOutcome(round: current, correct: false)
            Self.logger.info("wrong \(current.id, privacy: .public)")
        }
    }

    func advance() {
        state.index += 1
        state.feedback = .none
        if state.isComplete {
            recordSession()
        }
    }

    func reset() {
        state.index = 0
        state.score = 0
        state.feedback = .none
    }

    // MARK: - Persistence

    private func recordOutcome(round: WordRhymeGameModels.Round, correct: Bool) {
        guard let planner = adaptivePlanner, !childId.isEmpty else { return }
        let sound = String(round.targetWord.prefix(1)).uppercased()
        Task { [weak self] in
            guard let self else { return }
            await planner.recordItemOutcome(
                childId: self.childId,
                itemId: round.id,
                sound: sound,
                correct: correct
            )
        }
    }

    private func recordSession() {
        guard let planner = adaptivePlanner, !childId.isEmpty, !state.rounds.isEmpty else { return }
        let rate = Double(state.score) / Double(state.rounds.count)
        let quality = SM2Quality.fromSuccessRate(rate)
        let sound = state.rounds.first.map { String($0.targetWord.prefix(1)).uppercased() } ?? "С"
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
