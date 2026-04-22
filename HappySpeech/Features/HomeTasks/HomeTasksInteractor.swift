import Foundation
import OSLog

// MARK: - HomeTasksBusinessLogic

@MainActor
protocol HomeTasksBusinessLogic: AnyObject {
    func fetch(_ request: HomeTasksModels.Fetch.Request)
    func update(_ request: HomeTasksModels.Update.Request)
}

// MARK: - HomeTasksInteractor

@MainActor
final class HomeTasksInteractor: HomeTasksBusinessLogic {

    var presenter: (any HomeTasksPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "HomeTasks")

    // MARK: - fetch
    func fetch(_ request: HomeTasksModels.Fetch.Request) {
        let response = HomeTasksModels.Fetch.Response()
        presenter?.presentFetch(response)
    }

    // MARK: - update
    func update(_ request: HomeTasksModels.Update.Request) {
        let response = HomeTasksModels.Update.Response()
        presenter?.presentUpdate(response)
    }
}
