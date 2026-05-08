import SwiftUI

// MARK: - VoiceCloningRoutingLogic

@MainActor
protocol VoiceCloningRoutingLogic {
    func dismiss()
    func routeToParentHome()
}

// MARK: - VoiceCloningRouter

@MainActor
final class VoiceCloningRouter: VoiceCloningRoutingLogic {

    weak var coordinator: AppCoordinator?

    init(coordinator: AppCoordinator?) {
        self.coordinator = coordinator
    }

    func dismiss() {
        coordinator?.pop()
    }

    func routeToParentHome() {
        coordinator?.navigate(to: .parentHome)
    }
}
