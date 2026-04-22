import SwiftUI

// MARK: - BingoRoutingLogic

@MainActor
protocol BingoRoutingLogic {
    func routeToSessionComplete()
    func routeBack()
}

// MARK: - BingoRouter

@MainActor
final class BingoRouter: BingoRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeToSessionComplete() {
        coordinator?.navigate(to: .sessionComplete)
    }

    func routeBack() {
        coordinator?.pop()
    }
}
