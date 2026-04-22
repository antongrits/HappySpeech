import SwiftUI

// MARK: - StoryCompletionRoutingLogic

@MainActor
protocol StoryCompletionRoutingLogic {
    func routeToSessionComplete()
    func routeBack()
}

// MARK: - StoryCompletionRouter

@MainActor
final class StoryCompletionRouter: StoryCompletionRoutingLogic {

    weak var coordinator: AppCoordinator?

    func routeToSessionComplete() {
        coordinator?.navigate(to: .sessionComplete)
    }

    func routeBack() {
        coordinator?.pop()
    }
}
