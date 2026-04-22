import Foundation
import OSLog

// MARK: - RhythmBusinessLogic

@MainActor
protocol RhythmBusinessLogic: AnyObject {
    func loadSession(_ request: RhythmModels.LoadSession.Request)
    func submitAttempt(_ request: RhythmModels.SubmitAttempt.Request)
}

// MARK: - RhythmInteractor

@MainActor
final class RhythmInteractor: RhythmBusinessLogic {

    var presenter: (any RhythmPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Rhythm")

    // MARK: - loadSession
    func loadSession(_ request: RhythmModels.LoadSession.Request) {
        let response = RhythmModels.LoadSession.Response()
        presenter?.presentLoadSession(response)
    }

    // MARK: - submitAttempt
    func submitAttempt(_ request: RhythmModels.SubmitAttempt.Request) {
        let response = RhythmModels.SubmitAttempt.Response()
        presenter?.presentSubmitAttempt(response)
    }
}
