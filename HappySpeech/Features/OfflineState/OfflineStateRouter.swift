import SwiftUI

// MARK: - OfflineStateRoutingLogic

@MainActor
protocol OfflineStateRoutingLogic {
    func routeBack()
    func routeToActiveChild(childId: String)
    func routeToAuth()
}

// MARK: - OfflineStateRouter

@MainActor
final class OfflineStateRouter: OfflineStateRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeBack() {
        coordinator?.pop()
    }

    func routeToActiveChild(childId: String) {
        coordinator?.navigate(to: .childHome(childId: childId))
    }

    func routeToAuth() {
        coordinator?.navigate(to: .auth)
    }
}
