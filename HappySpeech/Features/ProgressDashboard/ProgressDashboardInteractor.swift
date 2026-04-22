import Foundation
import OSLog

// MARK: - ProgressDashboardBusinessLogic

@MainActor
protocol ProgressDashboardBusinessLogic: AnyObject {
    func fetch(_ request: ProgressDashboardModels.Fetch.Request)
    func update(_ request: ProgressDashboardModels.Update.Request)
}

// MARK: - ProgressDashboardInteractor

@MainActor
final class ProgressDashboardInteractor: ProgressDashboardBusinessLogic {

    var presenter: (any ProgressDashboardPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "ProgressDashboard")

    // MARK: - fetch
    func fetch(_ request: ProgressDashboardModels.Fetch.Request) {
        let response = ProgressDashboardModels.Fetch.Response()
        presenter?.presentFetch(response)
    }

    // MARK: - update
    func update(_ request: ProgressDashboardModels.Update.Request) {
        let response = ProgressDashboardModels.Update.Response()
        presenter?.presentUpdate(response)
    }
}
