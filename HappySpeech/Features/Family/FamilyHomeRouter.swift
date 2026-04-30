import SwiftUI

// MARK: - FamilyHomeRouter

@MainActor
final class FamilyHomeRouter {

    private weak var coordinator: AppCoordinator?
    private var container: AppContainer?

    init(coordinator: AppCoordinator, container: AppContainer) {
        self.coordinator = coordinator
        self.container = container
    }

    func routeToChildHome(childId: String) {
        container?.currentChildId = childId
        coordinator?.navigate(to: .childHome(childId: childId))
    }

    func routeToComparison() {
        coordinator?.navigate(to: .comparisonDashboard)
    }

    func routeToSiblingMultiplayer(childId: String) {
        coordinator?.navigate(to: .siblingMultiplayer(childId: childId))
    }

    func routeToSettings() {
        coordinator?.navigate(to: .settings)
    }
}
