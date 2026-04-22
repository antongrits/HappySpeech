import SwiftUI

// MARK: - RewardsRoutingLogic

@MainActor
protocol RewardsRoutingLogic {
    func routeBack()
}

// MARK: - RewardsRouter

@MainActor
final class RewardsRouter: RewardsRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeBack() {
        coordinator?.pop()
    }
}
