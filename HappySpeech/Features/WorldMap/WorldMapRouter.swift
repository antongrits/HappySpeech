import SwiftUI

// MARK: - WorldMapRoutingLogic

@MainActor
protocol WorldMapRoutingLogic {
    func routeBack()
}

// MARK: - WorldMapRouter

@MainActor
final class WorldMapRouter: WorldMapRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeBack() {
        coordinator?.pop()
    }
}
