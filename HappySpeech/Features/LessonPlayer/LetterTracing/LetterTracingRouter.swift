import Foundation

// MARK: - LetterTracingRouter

/// Навигация LetterTracing. Вызывает onComplete по завершению сессии.
@MainActor
final class LetterTracingRouter: LetterTracingRoutingLogic {

    // MARK: - Callbacks

    /// Вызывается когда игра полностью завершена. `score` — 0.0…1.0.
    var onComplete: ((Float) -> Void)?

    // MARK: - LetterTracingRoutingLogic

    func routeToCompleteWith(score: Float) {
        onComplete?(score)
    }
}
