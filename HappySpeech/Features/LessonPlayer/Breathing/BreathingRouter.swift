import SwiftUI

// MARK: - BreathingRoutingLogic

@MainActor
protocol BreathingRoutingLogic {
    func routeToSessionComplete()
    func routeBack()
}

// MARK: - BreathingRouter

@MainActor
final class BreathingRouter: BreathingRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeToSessionComplete() {
        coordinator?.navigate(to: .sessionComplete)
    }

    func routeBack() {
        coordinator?.pop()
    }
}
