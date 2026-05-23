import Foundation
import OSLog

// MARK: - WordRhymeGameInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class WordRhymeGameInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "WordRhymeGame"
    )

    let childId: String
    var state: WordRhymeGameModels.ViewState

    init(childId: String) {
        self.childId = childId
        self.state = .initial
    }

    func answer(_ optionId: String) {
        guard let current = state.current else { return }
        if optionId == current.correctOptionId {
            state.score += 1
            state.feedback = .correct
            Self.logger.info("correct \(current.id, privacy: .public)")
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(700))
                await MainActor.run { self?.advance() }
            }
        } else {
            state.feedback = .wrong(optionId)
            Self.logger.info("wrong \(current.id, privacy: .public)")
        }
    }

    func advance() {
        state.index += 1
        state.feedback = .none
    }

    func reset() {
        state = .initial
    }
}
