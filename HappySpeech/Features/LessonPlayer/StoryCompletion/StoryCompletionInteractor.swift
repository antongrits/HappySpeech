import Foundation
import OSLog

// MARK: - StoryCompletionBusinessLogic

@MainActor
protocol StoryCompletionBusinessLogic: AnyObject {
    func loadSession(_ request: StoryCompletionModels.LoadSession.Request)
    func submitAttempt(_ request: StoryCompletionModels.SubmitAttempt.Request)
}

// MARK: - StoryCompletionInteractor

@MainActor
final class StoryCompletionInteractor: StoryCompletionBusinessLogic {

    var presenter: (any StoryCompletionPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "StoryCompletion")

    // MARK: - loadSession
    func loadSession(_ request: StoryCompletionModels.LoadSession.Request) {
        let response = StoryCompletionModels.LoadSession.Response()
        presenter?.presentLoadSession(response)
    }

    // MARK: - submitAttempt
    func submitAttempt(_ request: StoryCompletionModels.SubmitAttempt.Request) {
        let response = StoryCompletionModels.SubmitAttempt.Response()
        presenter?.presentSubmitAttempt(response)
    }
}
