import SwiftUI

// MARK: - PermissionsRoutingLogic

@MainActor
protocol PermissionsRoutingLogic {
    func routeBack()
}

// MARK: - PermissionsRouter

@MainActor
final class PermissionsRouter: PermissionsRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeBack() {
        coordinator?.pop()
    }
}
