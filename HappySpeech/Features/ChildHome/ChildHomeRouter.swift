import SwiftUI

// MARK: - ChildHomeRoutingLogic

@MainActor
protocol ChildHomeRoutingLogic {
    func routeToParentHome()
    func routeToWorldMap(childId: String, sound: String)
    func routeToARZone()
    func routeToRewards(childId: String)
    func routeToLesson(childId: String, template: String)
}

// MARK: - ChildHomeRouter

@MainActor
final class ChildHomeRouter: ChildHomeRoutingLogic {
    weak var coordinator: AppCoordinator?

    func routeToParentHome() {
        coordinator?.navigate(to: .parentHome)
    }

    func routeToWorldMap(childId: String, sound: String) {
        coordinator?.navigate(to: .worldMap(childId: childId, targetSound: sound))
    }

    func routeToARZone() {
        coordinator?.navigate(to: .arZone)
    }

    func routeToRewards(childId: String) {
        coordinator?.navigate(to: .rewards(childId: childId))
    }

    func routeToLesson(childId: String, template: String) {
        coordinator?.navigate(to: .lessonPlayer(templateType: template, childId: childId))
    }
}
