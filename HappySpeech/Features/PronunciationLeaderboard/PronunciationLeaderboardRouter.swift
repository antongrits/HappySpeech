import SwiftUI

// MARK: - PronunciationLeaderboardRoutingLogic

@MainActor
protocol PronunciationLeaderboardRoutingLogic {
    func dismiss()
    func routeToChildProgress(childId: String)
}

// MARK: - PronunciationLeaderboardRouter

@MainActor
final class PronunciationLeaderboardRouter: PronunciationLeaderboardRoutingLogic {

    weak var coordinator: AppCoordinator?

    init(coordinator: AppCoordinator?) {
        self.coordinator = coordinator
    }

    func dismiss() {
        coordinator?.pop()
    }

    func routeToChildProgress(childId: String) {
        coordinator?.navigate(to: .progressDashboard(childId: childId))
    }
}
