import SwiftUI

// MARK: - SortingRoutingLogic

@MainActor
protocol SortingRoutingLogic {
    func routeToSessionComplete()
    func routeBack()
}

// MARK: - SortingRouter

@MainActor
final class SortingRouter: SortingRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeToSessionComplete() {
        coordinator?.navigate(to: .sessionComplete)
    }

    func routeBack() {
        coordinator?.pop()
    }
}
