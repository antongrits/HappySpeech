import Foundation
import OSLog

// MARK: - SettingsBusinessLogic

@MainActor
protocol SettingsBusinessLogic: AnyObject {
    func fetch(_ request: SettingsModels.Fetch.Request)
    func update(_ request: SettingsModels.Update.Request)
}

// MARK: - SettingsInteractor

@MainActor
final class SettingsInteractor: SettingsBusinessLogic {

    var presenter: (any SettingsPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Settings")

    // MARK: - fetch
    func fetch(_ request: SettingsModels.Fetch.Request) {
        let response = SettingsModels.Fetch.Response()
        presenter?.presentFetch(response)
    }

    // MARK: - update
    func update(_ request: SettingsModels.Update.Request) {
        let response = SettingsModels.Update.Response()
        presenter?.presentUpdate(response)
    }
}
