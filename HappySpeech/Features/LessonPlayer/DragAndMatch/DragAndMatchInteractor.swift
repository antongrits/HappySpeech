import Foundation
import OSLog

// MARK: - DragAndMatchBusinessLogic

@MainActor
protocol DragAndMatchBusinessLogic: AnyObject {
    func loadSession(_ request: DragAndMatchModels.LoadSession.Request)
    func submitAttempt(_ request: DragAndMatchModels.SubmitAttempt.Request)
}

// MARK: - DragAndMatchInteractor

@MainActor
final class DragAndMatchInteractor: DragAndMatchBusinessLogic {

    var presenter: (any DragAndMatchPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "DragAndMatch")

    // MARK: - loadSession
    func loadSession(_ request: DragAndMatchModels.LoadSession.Request) {
        let response = DragAndMatchModels.LoadSession.Response()
        presenter?.presentLoadSession(response)
    }

    // MARK: - submitAttempt
    func submitAttempt(_ request: DragAndMatchModels.SubmitAttempt.Request) {
        let response = DragAndMatchModels.SubmitAttempt.Response()
        presenter?.presentSubmitAttempt(response)
    }
}
