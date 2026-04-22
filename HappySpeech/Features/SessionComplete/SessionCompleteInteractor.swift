import Foundation
import OSLog

// MARK: - SessionCompleteBusinessLogic

@MainActor
protocol SessionCompleteBusinessLogic: AnyObject {
    func fetch(_ request: SessionCompleteModels.Fetch.Request)
    func update(_ request: SessionCompleteModels.Update.Request)
}

// MARK: - SessionCompleteInteractor

@MainActor
final class SessionCompleteInteractor: SessionCompleteBusinessLogic {

    var presenter: (any SessionCompletePresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SessionComplete")

    // MARK: - fetch
    func fetch(_ request: SessionCompleteModels.Fetch.Request) {
        let response = SessionCompleteModels.Fetch.Response()
        presenter?.presentFetch(response)
    }

    // MARK: - update
    func update(_ request: SessionCompleteModels.Update.Request) {
        let response = SessionCompleteModels.Update.Response()
        presenter?.presentUpdate(response)
    }
}
