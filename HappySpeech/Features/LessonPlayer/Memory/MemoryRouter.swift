import SwiftUI

// MARK: - MemoryRoutingLogic

@MainActor
protocol MemoryRoutingLogic {
    func routeToSessionComplete()
    func routeBack()
}

// MARK: - MemoryRouter

@MainActor
final class MemoryRouter: MemoryRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeToSessionComplete() {
        coordinator?.navigate(to: .sessionComplete)
    }

    func routeBack() {
        coordinator?.pop()
    }
}
