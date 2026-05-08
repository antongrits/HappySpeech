import SwiftUI

// MARK: - NeurolinguistInsightsRoutingLogic

@MainActor
protocol NeurolinguistInsightsRoutingLogic {
    func dismiss()
    func routeToProgressDashboard(childId: String)
    func routeToSessionHistory(childId: String)
}

// MARK: - NeurolinguistInsightsRouter

@MainActor
final class NeurolinguistInsightsRouter: NeurolinguistInsightsRoutingLogic {

    weak var coordinator: AppCoordinator?

    init(coordinator: AppCoordinator?) {
        self.coordinator = coordinator
    }

    func dismiss() {
        coordinator?.pop()
    }

    func routeToProgressDashboard(childId: String) {
        coordinator?.navigate(to: .progressDashboard(childId: childId))
    }

    func routeToSessionHistory(childId: String) {
        coordinator?.navigate(to: .sessionHistory(childId: childId))
    }
}
