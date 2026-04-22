import Foundation
import OSLog

// MARK: - BreathingBusinessLogic

@MainActor
protocol BreathingBusinessLogic: AnyObject {
    func loadSession(_ request: BreathingModels.LoadSession.Request)
    func submitAttempt(_ request: BreathingModels.SubmitAttempt.Request)
}

// MARK: - BreathingInteractor

@MainActor
final class BreathingInteractor: BreathingBusinessLogic {

    var presenter: (any BreathingPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Breathing")

    // MARK: - loadSession
    func loadSession(_ request: BreathingModels.LoadSession.Request) {
        let response = BreathingModels.LoadSession.Response()
        presenter?.presentLoadSession(response)
    }

    // MARK: - submitAttempt
    func submitAttempt(_ request: BreathingModels.SubmitAttempt.Request) {
        let response = BreathingModels.SubmitAttempt.Response()
        presenter?.presentSubmitAttempt(response)
    }
}
