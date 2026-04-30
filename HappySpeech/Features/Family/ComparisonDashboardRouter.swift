import SwiftUI

// MARK: - ComparisonDashboardRouter

@MainActor
final class ComparisonDashboardRouter {
    private weak var coordinator: AppCoordinator?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    func dismiss() {
        coordinator?.pop()
    }
}
