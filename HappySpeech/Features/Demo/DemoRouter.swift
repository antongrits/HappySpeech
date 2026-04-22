import SwiftUI

// MARK: - DemoRoutingLogic

@MainActor
protocol DemoRoutingLogic {
    func routeBack()
}

// MARK: - DemoRouter

@MainActor
final class DemoRouter: DemoRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeBack() {
        coordinator?.pop()
    }
}
