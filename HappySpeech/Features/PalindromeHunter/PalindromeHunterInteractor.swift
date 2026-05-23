import Foundation
import OSLog

// MARK: - PalindromeHunterInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class PalindromeHunterInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "PalindromeHunter"
    )

    let childId: String
    var state: PalindromeHunterModels.ViewState

    init(childId: String) {
        self.childId = childId
        self.state = .initial
    }

    func pick(_ word: String) -> Bool {
        guard let round = state.currentRound else { return false }
        let isCorrect = (word == round.palindrome)
        if isCorrect {
            state.correctCount += 1
        }
        state.currentRoundIndex = min(state.currentRoundIndex + 1, state.rounds.count)
        Self.logger.info("pick \(word, privacy: .public) correct=\(isCorrect)")
        return isCorrect
    }

    func reset() {
        state = .initial
    }
}
