import Foundation
import OSLog

// MARK: - WorldMapBusinessLogic

@MainActor
protocol WorldMapBusinessLogic: AnyObject {
    func fetch(_ request: WorldMapModels.Fetch.Request)
    func update(_ request: WorldMapModels.Update.Request)
}

// MARK: - WorldMapInteractor

@MainActor
final class WorldMapInteractor: WorldMapBusinessLogic {

    var presenter: (any WorldMapPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "WorldMap")

    // MARK: - fetch
    func fetch(_ request: WorldMapModels.Fetch.Request) {
        let response = WorldMapModels.Fetch.Response()
        presenter?.presentFetch(response)
    }

    // MARK: - update
    func update(_ request: WorldMapModels.Update.Request) {
        let response = WorldMapModels.Update.Response()
        presenter?.presentUpdate(response)
    }
}
