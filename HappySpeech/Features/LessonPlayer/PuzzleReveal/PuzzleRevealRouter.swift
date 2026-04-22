import SwiftUI

// MARK: - PuzzleRevealRoutingLogic

@MainActor
protocol PuzzleRevealRoutingLogic {
    func routeToSessionComplete()
    func routeBack()
}

// MARK: - PuzzleRevealRouter

@MainActor
final class PuzzleRevealRouter: PuzzleRevealRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeToSessionComplete() {
        coordinator?.navigate(to: .sessionComplete)
    }

    func routeBack() {
        coordinator?.pop()
    }
}
