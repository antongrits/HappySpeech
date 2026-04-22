import Foundation
import OSLog

// MARK: - PuzzleRevealBusinessLogic

@MainActor
protocol PuzzleRevealBusinessLogic: AnyObject {
    func loadSession(_ request: PuzzleRevealModels.LoadSession.Request)
    func submitAttempt(_ request: PuzzleRevealModels.SubmitAttempt.Request)
}

// MARK: - PuzzleRevealInteractor

@MainActor
final class PuzzleRevealInteractor: PuzzleRevealBusinessLogic {

    var presenter: (any PuzzleRevealPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "PuzzleReveal")

    // MARK: - loadSession
    func loadSession(_ request: PuzzleRevealModels.LoadSession.Request) {
        let response = PuzzleRevealModels.LoadSession.Response()
        presenter?.presentLoadSession(response)
    }

    // MARK: - submitAttempt
    func submitAttempt(_ request: PuzzleRevealModels.SubmitAttempt.Request) {
        let response = PuzzleRevealModels.SubmitAttempt.Response()
        presenter?.presentSubmitAttempt(response)
    }
}
