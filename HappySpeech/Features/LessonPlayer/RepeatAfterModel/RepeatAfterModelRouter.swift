import SwiftUI

// MARK: - RepeatAfterModelRoutingLogic

@MainActor
protocol RepeatAfterModelRoutingLogic {
    func routeToSessionComplete()
    func routeBack()
}

// MARK: - RepeatAfterModelRouter

@MainActor
final class RepeatAfterModelRouter: RepeatAfterModelRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeToSessionComplete() {
        coordinator?.navigate(to: .sessionComplete)
    }

    func routeBack() {
        coordinator?.pop()
    }
}
