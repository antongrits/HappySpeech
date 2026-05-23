import Foundation
import OSLog

// MARK: - SpeechRiddlesInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class SpeechRiddlesInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SpeechRiddles"
    )

    let childId: String
    var state: SpeechRiddlesModels.ViewState

    init(childId: String) {
        self.childId = childId
        self.state = .initial
    }

    func answer(_ optionId: String) {
        guard let current = state.current else { return }
        if optionId == current.correctOptionId {
            state.score += 1
            state.feedback = .correct
            Self.logger.info("correct riddle=\(current.id, privacy: .public)")
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(700))
                await MainActor.run { self?.advance() }
            }
        } else {
            state.feedback = .wrong(optionId)
            Self.logger.info("wrong riddle=\(current.id, privacy: .public) option=\(optionId, privacy: .public)")
        }
    }

    func advance() {
        state.currentIndex += 1
        state.feedback = .none
    }

    func reset() {
        state = .initial
    }
}
