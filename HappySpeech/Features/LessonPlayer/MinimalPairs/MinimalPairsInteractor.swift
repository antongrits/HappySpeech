import Foundation
import OSLog

// MARK: - MinimalPairsBusinessLogic

@MainActor
protocol MinimalPairsBusinessLogic: AnyObject {
    func loadSession(_ request: MinimalPairsModels.LoadSession.Request)
    func submitAttempt(_ request: MinimalPairsModels.SubmitAttempt.Request)
}

// MARK: - MinimalPairsInteractor

@MainActor
final class MinimalPairsInteractor: MinimalPairsBusinessLogic {

    var presenter: (any MinimalPairsPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "MinimalPairs")

    // MARK: - loadSession
    func loadSession(_ request: MinimalPairsModels.LoadSession.Request) {
        let response = MinimalPairsModels.LoadSession.Response()
        presenter?.presentLoadSession(response)
    }

    // MARK: - submitAttempt
    func submitAttempt(_ request: MinimalPairsModels.SubmitAttempt.Request) {
        let response = MinimalPairsModels.SubmitAttempt.Response()
        presenter?.presentSubmitAttempt(response)
    }
}
