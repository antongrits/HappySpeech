import Foundation
import OSLog

// MARK: - ListenAndChooseBusinessLogic

@MainActor
protocol ListenAndChooseBusinessLogic: AnyObject {
    func loadSession(_ request: ListenAndChooseModels.LoadSession.Request)
    func submitAttempt(_ request: ListenAndChooseModels.SubmitAttempt.Request)
}

// MARK: - ListenAndChooseInteractor

@MainActor
final class ListenAndChooseInteractor: ListenAndChooseBusinessLogic {

    var presenter: (any ListenAndChoosePresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "ListenAndChoose")

    // MARK: - loadSession
    func loadSession(_ request: ListenAndChooseModels.LoadSession.Request) {
        let response = ListenAndChooseModels.LoadSession.Response()
        presenter?.presentLoadSession(response)
    }

    // MARK: - submitAttempt
    func submitAttempt(_ request: ListenAndChooseModels.SubmitAttempt.Request) {
        let response = ListenAndChooseModels.SubmitAttempt.Response()
        presenter?.presentSubmitAttempt(response)
    }
}
