import SwiftUI

// MARK: - NarrativeQuestRoutingLogic

@MainActor
protocol NarrativeQuestRoutingLogic {
    func routeToSessionComplete()
    func routeBack()
}

// MARK: - NarrativeQuestRouter

@MainActor
final class NarrativeQuestRouter: NarrativeQuestRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeToSessionComplete() {
        coordinator?.navigate(to: .sessionComplete)
    }

    func routeBack() {
        coordinator?.pop()
    }
}
