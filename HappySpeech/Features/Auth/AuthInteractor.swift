import Foundation
import OSLog

// MARK: - AuthBusinessLogic

@MainActor
protocol AuthBusinessLogic: AnyObject {
    func fetch(_ request: AuthModels.Fetch.Request)
    func update(_ request: AuthModels.Update.Request)
}

// MARK: - AuthInteractor

@MainActor
final class AuthInteractor: AuthBusinessLogic {

    var presenter: (any AuthPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Auth")

    // MARK: - fetch
    func fetch(_ request: AuthModels.Fetch.Request) {
        let response = AuthModels.Fetch.Response()
        presenter?.presentFetch(response)
    }

    // MARK: - update
    func update(_ request: AuthModels.Update.Request) {
        let response = AuthModels.Update.Response()
        presenter?.presentUpdate(response)
    }
}
