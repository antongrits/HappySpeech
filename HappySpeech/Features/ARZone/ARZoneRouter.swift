import SwiftUI

// MARK: - ARZoneRoutingLogic

@MainActor
protocol ARZoneRoutingLogic {
    func routeBack()
}

// MARK: - ARZoneRouter

@MainActor
final class ARZoneRouter: ARZoneRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeBack() {
        coordinator?.pop()
    }
}
