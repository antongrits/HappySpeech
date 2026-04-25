import Foundation
import OSLog

// MARK: - HomeTasksRoutingLogic

@MainActor
protocol HomeTasksRoutingLogic {
    func routeBack()
    func routeOpenDetail(taskId: String)
    func routeToGame(exerciseType: String, targetSound: String)
}

// MARK: - HomeTasksRouter
//
// Лёгкий router без coordinator-ссылки: View задаёт колбэки `onDismiss`,
// `onOpenDetail` и `onStartGame`. Это позволяет встраивать экран и в push-стек,
// и в sheet, и в preview без зависимостей от `AppCoordinator`.
//
// `routeToGame` реализован через `HomeTasksGameRouting`-протокол —
// Interactor вызывает router через эту абстракцию. На текущем спринте
// внешнего callback нет → роутер только пишет в OSLog. Когда появится общий
// game-coordinator, View передаст `onStartGame` и навигация заработает.

@MainActor
final class HomeTasksRouter: HomeTasksRoutingLogic, HomeTasksGameRouting {

    var onDismiss: (() -> Void)?
    var onOpenDetail: ((String) -> Void)?
    var onStartGame: ((_ exerciseType: String, _ targetSound: String) -> Void)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "HomeTasksRouter")

    func routeBack() {
        onDismiss?()
    }

    func routeOpenDetail(taskId: String) {
        onOpenDetail?(taskId)
    }

    func routeToGame(exerciseType: String, targetSound: String) {
        logger.info("routeToGame exerciseType=\(exerciseType, privacy: .public) targetSound=\(targetSound, privacy: .public)")
        onStartGame?(exerciseType, targetSound)
    }
}
