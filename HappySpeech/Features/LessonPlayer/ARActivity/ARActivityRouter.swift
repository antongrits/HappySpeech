import SwiftUI

// MARK: - ARActivityRoutingLogic

@MainActor
protocol ARActivityRoutingLogic {
    func routeToSessionComplete()
    func routeBack()
}

// MARK: - ARActivityRouter

@MainActor
final class ARActivityRouter: ARActivityRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeToSessionComplete() {
        coordinator?.navigate(to: .sessionComplete)
    }

    func routeBack() {
        coordinator?.pop()
    }
}
