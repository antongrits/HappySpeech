import SwiftUI

// MARK: - HomeTasksRoutingLogic

@MainActor
protocol HomeTasksRoutingLogic {
    func routeBack()
    func routeOpenDetail(taskId: String)
}

// MARK: - HomeTasksRouter
//
// Лёгкий router без coordinator-ссылки: View задаёт колбэки `onDismiss` и
// `onOpenDetail`. Это позволяет встраивать экран и в push-стек, и в sheet,
// и в preview без зависимостей от `AppCoordinator`.

@MainActor
final class HomeTasksRouter: HomeTasksRoutingLogic {

    var onDismiss: (() -> Void)?
    var onOpenDetail: ((String) -> Void)?

    func routeBack() {
        onDismiss?()
    }

    func routeOpenDetail(taskId: String) {
        onOpenDetail?(taskId)
    }
}
