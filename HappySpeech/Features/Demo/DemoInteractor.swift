import Foundation
import OSLog

// MARK: - DemoBusinessLogic

@MainActor
protocol DemoBusinessLogic: AnyObject {
    func fetch(_ request: DemoModels.Fetch.Request)
    func update(_ request: DemoModels.Update.Request)
}

// MARK: - DemoInteractor

@MainActor
final class DemoInteractor: DemoBusinessLogic {

    var presenter: (any DemoPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Demo")

    // MARK: - fetch
    func fetch(_ request: DemoModels.Fetch.Request) {
        let response = DemoModels.Fetch.Response()
        presenter?.presentFetch(response)
    }

    // MARK: - update
    func update(_ request: DemoModels.Update.Request) {
        let response = DemoModels.Update.Response()
        presenter?.presentUpdate(response)
    }
}
