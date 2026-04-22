import SwiftUI

// MARK: - ListenAndChooseRoutingLogic

@MainActor
protocol ListenAndChooseRoutingLogic {
    func routeToSessionComplete()
    func routeBack()
}

// MARK: - ListenAndChooseRouter

@MainActor
final class ListenAndChooseRouter: ListenAndChooseRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeToSessionComplete() {
        coordinator?.navigate(to: .sessionComplete)
    }

    func routeBack() {
        coordinator?.pop()
    }
}
