import SwiftUI

// MARK: - SessionShellRoutingLogic

@MainActor
protocol SessionShellRoutingLogic: AnyObject {
    /// Final, "session finished" route — moves to the SessionComplete summary.
    func routeToResults(activities: [SessionActivity])
    /// Pop back to root (kid home).
    func routeToHome()
    /// Pop one screen back (used by the "Exit" button on the pause sheet
    /// after the user confirms abandoning the session).
    func routeBack()
}

// MARK: - SessionShellRouter

/// Coordinator-friendly router for SessionShell. The actual navigation is
/// performed by `AppCoordinator` so the SessionShell stays unaware of the
/// surrounding navigation graph.
@MainActor
final class SessionShellRouter: SessionShellRoutingLogic {

    weak var coordinator: AppCoordinator?

    init(coordinator: AppCoordinator? = nil) {
        self.coordinator = coordinator
    }

    func routeToResults(activities: [SessionActivity]) {
        coordinator?.navigate(to: .sessionComplete)
    }

    func routeToHome() {
        coordinator?.popToRoot()
    }

    func routeBack() {
        // AppCoordinator может не предоставлять "back-by-one" — для kid-circuit
        // безопаснее всегда возвращаться на корень kid-home, чтобы сессия
        // не "застревала" в навигационном стеке после ручного выхода.
        coordinator?.popToRoot()
    }
}

// MARK: - SessionShellRoute

/// Возможные next-step переходы из SessionShell. Используется при сериализации
/// прогресса в NavigationStack (Sprint 12 follow-up — deep-linking из push'ов).
enum SessionShellRoute: Equatable {
    /// Стандартный happy-path: завершение сессии → SessionComplete.
    case completion(activities: [SessionActivity])
    /// Принудительный выход (или fatigue alert) → kid home.
    case home
    /// Возврат на предыдущий экран (по умолчанию popToRoot для kid-circuit).
    case back
}
