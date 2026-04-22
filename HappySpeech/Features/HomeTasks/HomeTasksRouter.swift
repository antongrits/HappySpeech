import SwiftUI

// MARK: - HomeTasksRoutingLogic

@MainActor
protocol HomeTasksRoutingLogic {
    func routeBack()
}

// MARK: - HomeTasksRouter

@MainActor
final class HomeTasksRouter: HomeTasksRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeBack() {
        coordinator?.pop()
    }
}
