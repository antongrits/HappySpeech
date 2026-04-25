import SwiftUI

// MARK: - SessionCompleteRoutingLogic

@MainActor
protocol SessionCompleteRoutingLogic {
    func routeContinue()
    func routeReplay()
    func routeShare(text: String)
    func routeDismiss()
}

// MARK: - SessionCompleteRouter
//
// Router без жёсткой ссылки на координатор — View задаёт колбэки.
// Это позволяет переиспользовать экран в навигационном стеке, шите или preview.

@MainActor
final class SessionCompleteRouter: SessionCompleteRoutingLogic {

    var onContinue: (() -> Void)?
    var onReplay: (() -> Void)?
    var onShare: ((String) -> Void)?
    var onDismiss: (() -> Void)?

    func routeContinue() { onContinue?() }
    func routeReplay() { onReplay?() }
    func routeShare(text: String) { onShare?(text) }
    func routeDismiss() { onDismiss?() }
}
