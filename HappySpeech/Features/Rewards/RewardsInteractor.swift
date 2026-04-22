import Foundation
import OSLog

// MARK: - RewardsBusinessLogic

@MainActor
protocol RewardsBusinessLogic: AnyObject {
    func fetch(_ request: RewardsModels.Fetch.Request)
    func update(_ request: RewardsModels.Update.Request)
}

// MARK: - RewardsInteractor

@MainActor
final class RewardsInteractor: RewardsBusinessLogic {

    var presenter: (any RewardsPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Rewards")

    // MARK: - fetch
    func fetch(_ request: RewardsModels.Fetch.Request) {
        let response = RewardsModels.Fetch.Response()
        presenter?.presentFetch(response)
    }

    // MARK: - update
    func update(_ request: RewardsModels.Update.Request) {
        let response = RewardsModels.Update.Response()
        presenter?.presentUpdate(response)
    }
}
