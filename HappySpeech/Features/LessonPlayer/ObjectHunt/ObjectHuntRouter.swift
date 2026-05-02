import Foundation

// MARK: - ObjectHuntRouter

/// Навигация ObjectHunt. Единственный переход — routeToComplete,
/// который вызывает колбэк onComplete из SessionShell.
@MainActor
final class ObjectHuntRouter: ObjectHuntRoutingLogic {

    // MARK: - Callbacks

    /// Вызывается когда игра полностью завершена. `score` — 0.0…1.0.
    var onComplete: ((Float) -> Void)?

    // MARK: - ObjectHuntRoutingLogic

    func routeToComplete(score: Float) {
        onComplete?(score)
    }
}
