import SwiftUI

// MARK: - SessionShellRoutingLogic

@MainActor
protocol SessionShellRoutingLogic: AnyObject {
    func routeToResults(activities: [SessionActivity])
    func routeToHome()
}

// MARK: - SessionShellRouter

@MainActor
final class SessionShellRouter: SessionShellRoutingLogic {

    weak var coordinator: AppCoordinator?

    init(coordinator: AppCoordinator? = nil) {
        self.coordinator = coordinator
    }

    func routeToResults(activities: [SessionActivity]) {
        coordinator?.navigate(to: .sessionComplete)
    }

    func routeToHome() {
        coordinator?.popToRoot()
    }
}
