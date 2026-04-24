import SwiftUI

// MARK: - ARActivityRoutingLogic

@MainActor
protocol ARActivityRoutingLogic: AnyObject {
    func routeToARMirror()
    func routeToARStoryQuest()
    func dismiss()
}

// MARK: - ARActivityRouter
//
// ARActivity не использует `AppCoordinator.navigate(...)`, потому что
// дочерние AR-экраны открываются как `fullScreenCover` поверх SessionShell.
// Router держит коллбеки, которые View-слой привязывает к собственным
// `@State` флагам showARMirror / showARStoryQuest, а также коллбек
// завершения (score, stars) для передачи в родительский `onComplete`.
@MainActor
final class ARActivityRouter: ARActivityRoutingLogic {

    /// Показать ARMirrorView (артикуляционное зеркало).
    var onRouteToMirror: (() -> Void)?
    /// Показать ARStoryQuestView (нарративный квест).
    var onRouteToStoryQuest: (() -> Void)?
    /// Закрыть ARActivity и вернуться в SessionShell.
    var onDismiss: (() -> Void)?
    /// Упражнение завершено: (score, stars).
    var onCompleted: ((Float, Int) -> Void)?

    func routeToARMirror() {
        onRouteToMirror?()
    }

    func routeToARStoryQuest() {
        onRouteToStoryQuest?()
    }

    func dismiss() {
        onDismiss?()
    }
}
