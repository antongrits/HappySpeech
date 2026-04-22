import Foundation
import OSLog

// MARK: - OfflineStateBusinessLogic

@MainActor
protocol OfflineStateBusinessLogic: AnyObject {
    func fetch(_ request: OfflineStateModels.Fetch.Request)
    func update(_ request: OfflineStateModels.Update.Request)
}

// MARK: - OfflineStateInteractor

@MainActor
final class OfflineStateInteractor: OfflineStateBusinessLogic {

    var presenter: (any OfflineStatePresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "OfflineState")

    // MARK: - fetch
    func fetch(_ request: OfflineStateModels.Fetch.Request) {
        let response = OfflineStateModels.Fetch.Response()
        presenter?.presentFetch(response)
    }

    // MARK: - update
    func update(_ request: OfflineStateModels.Update.Request) {
        let response = OfflineStateModels.Update.Response()
        presenter?.presentUpdate(response)
    }
}
