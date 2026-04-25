import Foundation
import OSLog

// MARK: - SpecialistBusinessLogic

@MainActor
protocol SpecialistBusinessLogic: AnyObject {
    func fetch(_ request: SpecialistModels.Fetch.Request)
    func update(_ request: SpecialistModels.Update.Request)
    /// Открыть детальный обзор сессии (B1). Делегирует переход в `Router`.
    func openSessionReview(sessionId: String)
}

// MARK: - SpecialistInteractor

@MainActor
final class SpecialistInteractor: SpecialistBusinessLogic {

    var presenter: (any SpecialistPresentationLogic)?
    var router: SpecialistRouter?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Specialist")

    // MARK: - fetch
    func fetch(_ request: SpecialistModels.Fetch.Request) {
        let response = SpecialistModels.Fetch.Response()
        presenter?.presentFetch(response)
    }

    // MARK: - update
    func update(_ request: SpecialistModels.Update.Request) {
        let response = SpecialistModels.Update.Response()
        presenter?.presentUpdate(response)
    }

    // MARK: - SessionReview navigation (B1)

    func openSessionReview(sessionId: String) {
        guard !sessionId.isEmpty else {
            logger.warning("openSessionReview: empty sessionId — skip")
            return
        }
        router?.routeToSessionReview(sessionId: sessionId)
    }
}
