import Foundation
import OSLog

// MARK: - SpeechRiddlesInteractor

/// Бизнес-логика игры «Речевые загадки».
///
/// Загадки собираются `SpeechRiddlesWorker` из реального словаря под рабочие
/// звуки ребёнка. Каждый ответ фиксируется в интервальном планировщике
/// повторов (`AdaptivePlannerService`), по завершении — итоговый SM-2 результат.
@MainActor
@Observable
final class SpeechRiddlesInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SpeechRiddles"
    )

    let childId: String
    var state: SpeechRiddlesModels.ViewState = .initial

    private let worker: (any SpeechRiddlesWorkerProtocol)?
    private let adaptivePlanner: (any AdaptivePlannerService)?

    init(
        childId: String,
        worker: (any SpeechRiddlesWorkerProtocol)? = nil,
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
        let riddles = await worker.buildRiddles(childId: childId)
        state.riddles = riddles
        state.currentIndex = 0
        state.score = 0
        state.feedback = .none
        state.isLoaded = true
        Self.logger.info("loaded \(riddles.count, privacy: .public) riddles")
    }

    func answer(_ optionId: String) {
        guard let current = state.current else { return }
        let isCorrect = optionId == current.correctOptionId
        if isCorrect {
            state.score += 1
            state.feedback = .correct
            recordOutcome(riddle: current, correct: true)
            Self.logger.info("correct riddle=\(current.id, privacy: .public)")
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(700))
                await MainActor.run { self?.advance() }
            }
        } else {
            state.feedback = .wrong(optionId)
            recordOutcome(riddle: current, correct: false)
            Self.logger.info("wrong riddle=\(current.id, privacy: .public)")
        }
    }

    func advance() {
        state.currentIndex += 1
        state.feedback = .none
        if state.isComplete {
            recordSession()
        }
    }

    func reset() {
        state.currentIndex = 0
        state.score = 0
        state.feedback = .none
    }

    // MARK: - Persistence

    private func recordOutcome(riddle: SpeechRiddlesModels.Riddle, correct: Bool) {
        guard let planner = adaptivePlanner, !childId.isEmpty else { return }
        Task { [weak self] in
            guard let self else { return }
            await planner.recordItemOutcome(
                childId: self.childId,
                itemId: riddle.id,
                sound: riddle.targetLetter,
                correct: correct
            )
        }
    }

    private func recordSession() {
        guard let planner = adaptivePlanner, !childId.isEmpty, !state.riddles.isEmpty else { return }
        let rate = Double(state.score) / Double(state.riddles.count)
        let quality = SM2Quality.fromSuccessRate(rate)
        let sound = state.riddles.first?.targetLetter ?? "С"
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
