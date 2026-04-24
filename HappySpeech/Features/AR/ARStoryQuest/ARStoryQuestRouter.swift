import SwiftUI

// MARK: - ARStoryQuestRouter
//
// Упрощённый router: SwiftUI-версия не использует UIViewController, поэтому
// router получает closure'ы из View (dismiss, openReward) и делегирует им.
// Это оставляет View-слой чистым SwiftUI, сохраняя Clean Swift границу.

@MainActor
protocol ARStoryQuestRoutingLogic: AnyObject {
    func routeBack()
    func routeToRewardCelebration(stars: Int, totalScore: Float)
}

@MainActor
final class ARStoryQuestRouter: ARStoryQuestRoutingLogic {

    /// View вызывает `dismiss` при `.dismiss` request — например, crown-X.
    var dismiss: (() -> Void)?

    /// View отображает reward-оверлей, когда квест завершён.
    /// Router просто прокидывает значения наружу: финальную UI реализует View.
    var onQuestCompleted: ((_ stars: Int, _ totalScore: Float) -> Void)?

    func routeBack() {
        dismiss?()
    }

    func routeToRewardCelebration(stars: Int, totalScore: Float) {
        onQuestCompleted?(stars, totalScore)
    }
}
