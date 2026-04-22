import Foundation
import OSLog

// MARK: - SortingBusinessLogic

@MainActor
protocol SortingBusinessLogic: AnyObject {
    func loadSession(_ request: SortingModels.LoadSession.Request)
    func submitAttempt(_ request: SortingModels.SubmitAttempt.Request)
}

// MARK: - SortingInteractor

@MainActor
final class SortingInteractor: SortingBusinessLogic {

    var presenter: (any SortingPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Sorting")

    // MARK: - loadSession
    func loadSession(_ request: SortingModels.LoadSession.Request) {
        let response = SortingModels.LoadSession.Response()
        presenter?.presentLoadSession(response)
    }

    // MARK: - submitAttempt
    func submitAttempt(_ request: SortingModels.SubmitAttempt.Request) {
        let response = SortingModels.SubmitAttempt.Response()
        presenter?.presentSubmitAttempt(response)
    }
}
