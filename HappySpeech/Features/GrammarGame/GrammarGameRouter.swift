import SwiftUI

// MARK: - GrammarGameRoutingLogic

@MainActor
protocol GrammarGameRoutingLogic: AnyObject {
    func dismissGame()
    func routeToSessionComplete(successRate: Float, mode: GrammarGameMode)
}

// MARK: - GrammarGameRouter

/// Роутер GrammarGame. Работает через closure-коллбеки, переданные от родительского
/// NavigationStack/Sheet-координатора (SessionShell или WorldMap).
@MainActor
final class GrammarGameRouter: GrammarGameRoutingLogic {

    /// Закрыть экран (передаётся от координатора).
    var onDismiss: (() -> Void)?

    /// Перейти к SessionComplete (передаётся от координатора).
    var onSessionComplete: ((Float, GrammarGameMode) -> Void)?

    func dismissGame() {
        onDismiss?()
    }

    func routeToSessionComplete(successRate: Float, mode: GrammarGameMode) {
        onSessionComplete?(successRate, mode)
    }
}
