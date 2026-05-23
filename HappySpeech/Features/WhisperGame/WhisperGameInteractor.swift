import Foundation
import OSLog

// MARK: - WhisperGameInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class WhisperGameInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "WhisperGame"
    )

    let childId: String
    var state: WhisperGameModels.ViewState

    init(childId: String) {
        self.childId = childId
        self.state = .initial
    }

    func setMode(_ mode: WhisperGameModels.Mode) {
        state.mode = mode
        // simulate matching attempt
        state.currentLevel = mode.targetLevel * Double.random(in: 0.85...1.15)
        Self.logger.info("setMode \(mode.rawValue, privacy: .public)")
    }

    func completeRound() {
        state.roundsCompleted += 1
        Self.logger.info("round \(self.state.roundsCompleted) completed")
    }
}
