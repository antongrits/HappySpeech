import Foundation
import OSLog

// MARK: - PermissionsBusinessLogic

@MainActor
protocol PermissionsBusinessLogic: AnyObject {
    func fetch(_ request: PermissionsModels.Fetch.Request)
    func update(_ request: PermissionsModels.Update.Request)
}

// MARK: - PermissionsInteractor

@MainActor
final class PermissionsInteractor: PermissionsBusinessLogic {

    var presenter: (any PermissionsPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Permissions")

    // MARK: - fetch
    func fetch(_ request: PermissionsModels.Fetch.Request) {
        let response = PermissionsModels.Fetch.Response()
        presenter?.presentFetch(response)
    }

    // MARK: - update
    func update(_ request: PermissionsModels.Update.Request) {
        let response = PermissionsModels.Update.Response()
        presenter?.presentUpdate(response)
    }
}
