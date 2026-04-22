import Foundation
import OSLog

// MARK: - VisualAcousticBusinessLogic

@MainActor
protocol VisualAcousticBusinessLogic: AnyObject {
    func loadSession(_ request: VisualAcousticModels.LoadSession.Request)
    func submitAttempt(_ request: VisualAcousticModels.SubmitAttempt.Request)
}

// MARK: - VisualAcousticInteractor

@MainActor
final class VisualAcousticInteractor: VisualAcousticBusinessLogic {

    var presenter: (any VisualAcousticPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "VisualAcoustic")

    // MARK: - loadSession
    func loadSession(_ request: VisualAcousticModels.LoadSession.Request) {
        let response = VisualAcousticModels.LoadSession.Response()
        presenter?.presentLoadSession(response)
    }

    // MARK: - submitAttempt
    func submitAttempt(_ request: VisualAcousticModels.SubmitAttempt.Request) {
        let response = VisualAcousticModels.SubmitAttempt.Response()
        presenter?.presentSubmitAttempt(response)
    }
}
