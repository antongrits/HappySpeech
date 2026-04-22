import SwiftUI

// MARK: - OfflineStateRoutingLogic

@MainActor
protocol OfflineStateRoutingLogic {
    func routeBack()
}

// MARK: - OfflineStateRouter

@MainActor
final class OfflineStateRouter: OfflineStateRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeBack() {
        coordinator?.pop()
    }
}
