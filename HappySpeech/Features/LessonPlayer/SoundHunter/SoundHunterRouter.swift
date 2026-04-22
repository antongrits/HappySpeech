import SwiftUI

// MARK: - SoundHunterRoutingLogic

@MainActor
protocol SoundHunterRoutingLogic {
    func routeToSessionComplete()
    func routeBack()
}

// MARK: - SoundHunterRouter

@MainActor
final class SoundHunterRouter: SoundHunterRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeToSessionComplete() {
        coordinator?.navigate(to: .sessionComplete)
    }

    func routeBack() {
        coordinator?.pop()
    }
}
