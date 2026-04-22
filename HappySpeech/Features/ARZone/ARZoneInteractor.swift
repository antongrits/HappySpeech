import Foundation
import OSLog

// MARK: - ARZoneBusinessLogic

@MainActor
protocol ARZoneBusinessLogic: AnyObject {
    func fetch(_ request: ARZoneModels.Fetch.Request)
    func update(_ request: ARZoneModels.Update.Request)
}

// MARK: - ARZoneInteractor

@MainActor
final class ARZoneInteractor: ARZoneBusinessLogic {

    var presenter: (any ARZonePresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "ARZone")

    // MARK: - fetch
    func fetch(_ request: ARZoneModels.Fetch.Request) {
        let response = ARZoneModels.Fetch.Response()
        presenter?.presentFetch(response)
    }

    // MARK: - update
    func update(_ request: ARZoneModels.Update.Request) {
        let response = ARZoneModels.Update.Response()
        presenter?.presentUpdate(response)
    }
}
