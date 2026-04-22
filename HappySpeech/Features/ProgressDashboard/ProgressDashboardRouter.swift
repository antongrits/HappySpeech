import SwiftUI

// MARK: - ProgressDashboardRoutingLogic

@MainActor
protocol ProgressDashboardRoutingLogic {
    func routeBack()
}

// MARK: - ProgressDashboardRouter

@MainActor
final class ProgressDashboardRouter: ProgressDashboardRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeBack() {
        coordinator?.pop()
    }
}
