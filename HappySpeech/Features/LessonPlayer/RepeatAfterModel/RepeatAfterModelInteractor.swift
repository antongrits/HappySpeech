import Foundation
import OSLog

// MARK: - RepeatAfterModelBusinessLogic

@MainActor
protocol RepeatAfterModelBusinessLogic: AnyObject {
    func loadSession(_ request: RepeatAfterModelModels.LoadSession.Request)
    func submitAttempt(_ request: RepeatAfterModelModels.SubmitAttempt.Request)
}

// MARK: - RepeatAfterModelInteractor

@MainActor
final class RepeatAfterModelInteractor: RepeatAfterModelBusinessLogic {

    var presenter: (any RepeatAfterModelPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "RepeatAfterModel")

    // MARK: - loadSession
    func loadSession(_ request: RepeatAfterModelModels.LoadSession.Request) {
        let response = RepeatAfterModelModels.LoadSession.Response()
        presenter?.presentLoadSession(response)
    }

    // MARK: - submitAttempt
    func submitAttempt(_ request: RepeatAfterModelModels.SubmitAttempt.Request) {
        let response = RepeatAfterModelModels.SubmitAttempt.Response()
        presenter?.presentSubmitAttempt(response)
    }
}
