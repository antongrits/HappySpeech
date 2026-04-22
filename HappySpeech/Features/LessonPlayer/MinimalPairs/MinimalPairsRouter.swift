import SwiftUI

// MARK: - MinimalPairsRoutingLogic

@MainActor
protocol MinimalPairsRoutingLogic {
    func routeToSessionComplete()
    func routeBack()
}

// MARK: - MinimalPairsRouter

@MainActor
final class MinimalPairsRouter: MinimalPairsRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeToSessionComplete() {
        coordinator?.navigate(to: .sessionComplete)
    }

    func routeBack() {
        coordinator?.pop()
    }
}
