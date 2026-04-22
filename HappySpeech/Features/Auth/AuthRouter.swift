import SwiftUI

// MARK: - AuthRoutingLogic

@MainActor
protocol AuthRoutingLogic {
    func routeBack()
}

// MARK: - AuthRouter

@MainActor
final class AuthRouter: AuthRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeBack() {
        coordinator?.pop()
    }
}
