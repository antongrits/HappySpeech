import SwiftUI

// MARK: - FamilyVoiceRouter

@MainActor
final class FamilyVoiceRouter {

    weak var coordinator: AppCoordinator?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    func routeToSplitView() {
        coordinator?.navigate(to: .familyVoiceSplit)
    }

    func routeBackToParentHome() {
        coordinator?.navigate(to: .parentHome)
    }
}
