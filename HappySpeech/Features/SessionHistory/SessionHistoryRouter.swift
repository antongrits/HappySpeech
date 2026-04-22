import SwiftUI

// MARK: - SessionHistoryRoutingLogic

@MainActor
protocol SessionHistoryRoutingLogic {
    func routeBack()
}

// MARK: - SessionHistoryRouter

@MainActor
final class SessionHistoryRouter: SessionHistoryRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeBack() {
        coordinator?.pop()
    }
}
