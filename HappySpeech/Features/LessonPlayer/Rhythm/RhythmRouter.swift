import SwiftUI

// MARK: - RhythmRoutingLogic

@MainActor
protocol RhythmRoutingLogic {
    func routeToSessionComplete()
    func routeBack()
}

// MARK: - RhythmRouter

@MainActor
final class RhythmRouter: RhythmRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeToSessionComplete() {
        coordinator?.navigate(to: .sessionComplete)
    }

    func routeBack() {
        coordinator?.pop()
    }
}
