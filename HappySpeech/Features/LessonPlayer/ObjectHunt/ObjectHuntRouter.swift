import Foundation

// MARK: - ObjectHuntRouter

/// Навигация ObjectHunt. Минимальная — только routeToComplete,
/// который вызывает колбэк onComplete из SessionShell.
@MainActor
final class ObjectHuntRouter: ObjectHuntRoutingLogic {

    // MARK: - Callbacks

    /// Вызывается когда игра полностью завершена. `score` — 0.0…1.0.
    var onComplete: ((Float) -> Void)?

    // MARK: - ObjectHuntRoutingLogic

    func routeToComplete() {
        onComplete?(1.0)
    }

    /// Передаём точный итоговый score из Interactor.
    func routeToCompleteWith(score: Float) {
        onComplete?(score)
    }
}
