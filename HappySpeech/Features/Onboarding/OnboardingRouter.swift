import SwiftUI

// MARK: - OnboardingRoutingLogic

@MainActor
protocol OnboardingRoutingLogic {
    func routeBack()
}

// MARK: - OnboardingRouter

@MainActor
final class OnboardingRouter: OnboardingRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeBack() {
        coordinator?.pop()
    }
}
