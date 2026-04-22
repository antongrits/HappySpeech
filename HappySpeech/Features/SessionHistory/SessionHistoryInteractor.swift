import Foundation
import OSLog

// MARK: - SessionHistoryBusinessLogic

@MainActor
protocol SessionHistoryBusinessLogic: AnyObject {
    func fetch(_ request: SessionHistoryModels.Fetch.Request)
    func update(_ request: SessionHistoryModels.Update.Request)
}

// MARK: - SessionHistoryInteractor

@MainActor
final class SessionHistoryInteractor: SessionHistoryBusinessLogic {

    var presenter: (any SessionHistoryPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SessionHistory")

    // MARK: - fetch
    func fetch(_ request: SessionHistoryModels.Fetch.Request) {
        let response = SessionHistoryModels.Fetch.Response()
        presenter?.presentFetch(response)
    }

    // MARK: - update
    func update(_ request: SessionHistoryModels.Update.Request) {
        let response = SessionHistoryModels.Update.Response()
        presenter?.presentUpdate(response)
    }
}
