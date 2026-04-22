import SwiftUI

// MARK: - SessionCompleteRoutingLogic

@MainActor
protocol SessionCompleteRoutingLogic {
    func routeBack()
}

// MARK: - SessionCompleteRouter

@MainActor
final class SessionCompleteRouter: SessionCompleteRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeBack() {
        coordinator?.pop()
    }
}
