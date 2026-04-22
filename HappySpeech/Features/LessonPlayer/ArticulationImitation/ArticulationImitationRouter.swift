import SwiftUI

// MARK: - ArticulationImitationRoutingLogic

@MainActor
protocol ArticulationImitationRoutingLogic {
    func routeToSessionComplete()
    func routeBack()
}

// MARK: - ArticulationImitationRouter

@MainActor
final class ArticulationImitationRouter: ArticulationImitationRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeToSessionComplete() {
        coordinator?.navigate(to: .sessionComplete)
    }

    func routeBack() {
        coordinator?.pop()
    }
}
