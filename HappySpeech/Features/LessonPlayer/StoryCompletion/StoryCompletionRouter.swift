import Foundation

// MARK: - StoryCompletionRoutingLogic
//
// StoryCompletion живёт внутри `SessionShellView`, поэтому собственный
// AppCoordinator ему не нужен. Маршрутизация ограничивается одним сценарием —
// выходом из игры с прокидыванием финального score родителю через `onDismiss`.

@MainActor
protocol StoryCompletionRoutingLogic: AnyObject {
    func routeBack()
}

// MARK: - StoryCompletionRouter

@MainActor
final class StoryCompletionRouter: StoryCompletionRoutingLogic {

    /// Замыкание вызывается, когда игра завершена и пользователь нажал
    /// «Завершить». `StoryCompletionView` подключает к нему прокидывание
    /// `onComplete` в родительский `SessionShellView`.
    var onDismiss: (() -> Void)?

    func routeBack() {
        onDismiss?()
    }
}
