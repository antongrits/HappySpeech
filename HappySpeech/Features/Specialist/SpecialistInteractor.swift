import Foundation
import OSLog

// MARK: - SpecialistBusinessLogic

@MainActor
protocol SpecialistBusinessLogic: AnyObject {
    func fetch(_ request: SpecialistModels.Fetch.Request)
    func update(_ request: SpecialistModels.Update.Request)
}

// MARK: - SpecialistInteractor

@MainActor
final class SpecialistInteractor: SpecialistBusinessLogic {

    var presenter: (any SpecialistPresentationLogic)?

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
}
