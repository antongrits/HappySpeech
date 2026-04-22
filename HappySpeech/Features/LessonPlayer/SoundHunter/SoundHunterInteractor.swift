import Foundation
import OSLog

// MARK: - SoundHunterBusinessLogic

@MainActor
protocol SoundHunterBusinessLogic: AnyObject {
    func loadSession(_ request: SoundHunterModels.LoadSession.Request)
    func submitAttempt(_ request: SoundHunterModels.SubmitAttempt.Request)
}

// MARK: - SoundHunterInteractor

@MainActor
final class SoundHunterInteractor: SoundHunterBusinessLogic {

    var presenter: (any SoundHunterPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SoundHunter")

    // MARK: - loadSession
    func loadSession(_ request: SoundHunterModels.LoadSession.Request) {
        let response = SoundHunterModels.LoadSession.Response()
        presenter?.presentLoadSession(response)
    }

    // MARK: - submitAttempt
    func submitAttempt(_ request: SoundHunterModels.SubmitAttempt.Request) {
        let response = SoundHunterModels.SubmitAttempt.Response()
        presenter?.presentSubmitAttempt(response)
    }
}
