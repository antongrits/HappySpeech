import SwiftUI

// MARK: - RewardsRoutingLogic

@MainActor
protocol RewardsRoutingLogic {
    func routeDismiss()
    func routeOpenStickerDetail(id: String)
}

// MARK: - RewardsRouter
//
// View задаёт колбэки. Поддерживаем переиспользование экрана в push-стеке,
// в табах и в standalone-режиме без зависимости от `AppCoordinator`.

@MainActor
final class RewardsRouter: RewardsRoutingLogic {

    var onDismiss: (() -> Void)?
    var onOpenStickerDetail: ((String) -> Void)?

    func routeDismiss() { onDismiss?() }
    func routeOpenStickerDetail(id: String) { onOpenStickerDetail?(id) }
}
