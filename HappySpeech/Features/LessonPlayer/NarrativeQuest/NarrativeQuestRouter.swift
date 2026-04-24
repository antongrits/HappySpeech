import SwiftUI

// MARK: - NarrativeQuestRoutingLogic

@MainActor
protocol NarrativeQuestRoutingLogic: AnyObject {
    func routeBack()
    func routeToSessionComplete()
}

// MARK: - NarrativeQuestRouter

/// Маршрутизатор, отделяющий `AppCoordinator` от интерактора.
/// В рамках урока NarrativeQuest «завершение» делегируется родителю через
/// `onComplete` в View, поэтому router — лёгкий и отвечает только за назад.
@MainActor
final class NarrativeQuestRouter: NarrativeQuestRoutingLogic {

    weak var coordinator: AppCoordinator?

    /// Колбэк dismiss, переданный из SwiftUI. Интерактор может его не знать.
    var onDismiss: (() -> Void)?

    init(coordinator: AppCoordinator? = nil, onDismiss: (() -> Void)? = nil) {
        self.coordinator = coordinator
        self.onDismiss = onDismiss
    }

    func routeBack() {
        onDismiss?()
        coordinator?.pop()
    }

    func routeToSessionComplete() {
        coordinator?.navigate(to: .sessionComplete)
    }
}
