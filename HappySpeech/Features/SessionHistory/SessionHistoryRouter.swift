import SwiftUI

// MARK: - SessionHistoryRoutingLogic

@MainActor
protocol SessionHistoryRoutingLogic {
    func routeBack()
    func routeOpenDetail(id: String)
}

// MARK: - SessionHistoryRouter
//
// Router без жёсткой ссылки на координатор — View задаёт колбэки.
// Это позволяет встраивать экран в push-стек, sheet и preview без зависимости
// от `AppCoordinator`.

@MainActor
final class SessionHistoryRouter: SessionHistoryRoutingLogic {

    var onDismiss: (() -> Void)?
    var onOpenDetail: ((String) -> Void)?

    func routeBack() {
        onDismiss?()
    }

    func routeOpenDetail(id: String) {
        onOpenDetail?(id)
    }
}
