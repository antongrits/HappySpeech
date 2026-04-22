import Foundation
import OSLog

// MARK: - ARActivityBusinessLogic

@MainActor
protocol ARActivityBusinessLogic: AnyObject {
    func loadSession(_ request: ARActivityModels.LoadSession.Request)
    func submitAttempt(_ request: ARActivityModels.SubmitAttempt.Request)
}

// MARK: - ARActivityInteractor

@MainActor
final class ARActivityInteractor: ARActivityBusinessLogic {

    var presenter: (any ARActivityPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "ARActivity")

    // MARK: - loadSession
    func loadSession(_ request: ARActivityModels.LoadSession.Request) {
        let response = ARActivityModels.LoadSession.Response()
        presenter?.presentLoadSession(response)
    }

    // MARK: - submitAttempt
    func submitAttempt(_ request: ARActivityModels.SubmitAttempt.Request) {
        let response = ARActivityModels.SubmitAttempt.Response()
        presenter?.presentSubmitAttempt(response)
    }
}
