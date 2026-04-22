import Foundation
import OSLog

// MARK: - NarrativeQuestBusinessLogic

@MainActor
protocol NarrativeQuestBusinessLogic: AnyObject {
    func loadSession(_ request: NarrativeQuestModels.LoadSession.Request)
    func submitAttempt(_ request: NarrativeQuestModels.SubmitAttempt.Request)
}

// MARK: - NarrativeQuestInteractor

@MainActor
final class NarrativeQuestInteractor: NarrativeQuestBusinessLogic {

    var presenter: (any NarrativeQuestPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "NarrativeQuest")

    // MARK: - loadSession
    func loadSession(_ request: NarrativeQuestModels.LoadSession.Request) {
        let response = NarrativeQuestModels.LoadSession.Response()
        presenter?.presentLoadSession(response)
    }

    // MARK: - submitAttempt
    func submitAttempt(_ request: NarrativeQuestModels.SubmitAttempt.Request) {
        let response = NarrativeQuestModels.SubmitAttempt.Response()
        presenter?.presentSubmitAttempt(response)
    }
}
