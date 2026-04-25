import SwiftUI

// MARK: - ChildHomeRoutingLogic

@MainActor
protocol ChildHomeRoutingLogic {
    func routeToParentHome()
    func routeToWorldMap(childId: String, sound: String)
    func routeToARZone()
    func routeToRewards(childId: String)
    func routeToLesson(childId: String, template: String)
    func routeToSessionHistory(childId: String)
}

// MARK: - ChildHomeRouter

@MainActor
final class ChildHomeRouter: ChildHomeRoutingLogic {

    weak var coordinator: AppCoordinator?

    /// Опциональные коллбэки (M8.7) — позволяют вьюшке/тестам перехватывать
    /// навигацию без модификации `AppCoordinator`. Если коллбэк задан —
    /// он используется вместо стандартного маршрута.
    var onStartGame: ((_ childId: String, _ template: String) -> Void)?
    var onOpenHistory: ((_ childId: String) -> Void)?

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
        if let onStartGame {
            onStartGame(childId, template)
            return
        }
        coordinator?.navigate(to: .lessonPlayer(templateType: template, childId: childId))
    }

    func routeToSessionHistory(childId: String) {
        if let onOpenHistory {
            onOpenHistory(childId)
            return
        }
        coordinator?.navigate(to: .sessionHistory(childId: childId))
    }
}
