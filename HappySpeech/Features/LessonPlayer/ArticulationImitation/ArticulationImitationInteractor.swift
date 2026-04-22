import Foundation
import OSLog

// MARK: - ArticulationImitationBusinessLogic

@MainActor
protocol ArticulationImitationBusinessLogic: AnyObject {
    func loadSession(_ request: ArticulationImitationModels.LoadSession.Request)
    func submitAttempt(_ request: ArticulationImitationModels.SubmitAttempt.Request)
}

// MARK: - ArticulationImitationInteractor

@MainActor
final class ArticulationImitationInteractor: ArticulationImitationBusinessLogic {

    var presenter: (any ArticulationImitationPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "ArticulationImitation")

    // MARK: - loadSession
    func loadSession(_ request: ArticulationImitationModels.LoadSession.Request) {
        let response = ArticulationImitationModels.LoadSession.Response()
        presenter?.presentLoadSession(response)
    }

    // MARK: - submitAttempt
    func submitAttempt(_ request: ArticulationImitationModels.SubmitAttempt.Request) {
        let response = ArticulationImitationModels.SubmitAttempt.Response()
        presenter?.presentSubmitAttempt(response)
    }
}
