import Foundation
import SwiftUI

// MARK: - WordBankRoutingLogic

@MainActor
protocol WordBankRoutingLogic: AnyObject {
    func routeToPractice(word: String, targetSound: String)
    func routeToWorldMap()
    func dismiss()
}

// MARK: - WordBankRouter (Clean Swift: Router)
//
// F-303 v25 — навигация.
//   • routeToPractice — «Сказать снова» → LessonPlayer (RepeatAfterModel).
//   • routeToWorldMap — кнопка «К урокам» в empty state.
//   • dismiss — закрытие экрана.

@MainActor
final class WordBankRouter: WordBankRoutingLogic {

    private weak var coordinator: AppCoordinator?
    private let childId: String
    private let dismissAction: () -> Void

    init(
        coordinator: AppCoordinator?,
        childId: String,
        dismissAction: @escaping () -> Void
    ) {
        self.coordinator = coordinator
        self.childId = childId
        self.dismissAction = dismissAction
    }

    func routeToPractice(word: String, targetSound: String) {
        guard let coordinator else { return }
        coordinator.navigate(
            to: .lessonPlayer(templateType: "repeat-after-model", childId: childId)
        )
    }

    func routeToWorldMap() {
        guard let coordinator else {
            dismissAction()
            return
        }
        coordinator.navigate(to: .worldMap(childId: childId, targetSound: "С"))
    }

    func dismiss() {
        dismissAction()
    }
}
