import SwiftUI

// MARK: - VisualAcousticRoutingLogic

@MainActor
protocol VisualAcousticRoutingLogic {
    func routeToSessionComplete()
    func routeBack()
}

// MARK: - VisualAcousticRouter

@MainActor
final class VisualAcousticRouter: VisualAcousticRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeToSessionComplete() {
        coordinator?.navigate(to: .sessionComplete)
    }

    func routeBack() {
        coordinator?.pop()
    }
}
