import SwiftUI

// MARK: - DragAndMatchRoutingLogic

@MainActor
protocol DragAndMatchRoutingLogic: AnyObject {
    func routeToSessionComplete()
    func routeBack()
}

// MARK: - DragAndMatchRouter

@MainActor
final class DragAndMatchRouter: DragAndMatchRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeToSessionComplete() {
        coordinator?.navigate(to: .sessionComplete)
    }

    func routeBack() {
        coordinator?.pop()
    }
}
