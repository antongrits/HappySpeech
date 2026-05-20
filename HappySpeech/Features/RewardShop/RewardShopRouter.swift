import SwiftUI

// MARK: - RewardShopRoutingLogic

@MainActor
protocol RewardShopRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - RewardShopRouter (Clean Swift: Router)
//
// v31 Волна C Ф.1 «Магазин наград». Маршрут открывается из ChildHome
// и закрывается стандартным dismiss — экран модальный, без вложенной
// навигации. Если в будущем потребуется push-цепочка (например, sticker
// detail sheet) — router будет точкой расширения.

@MainActor
final class RewardShopRouter: RewardShopRoutingLogic {

    private let dismissAction: () -> Void

    init(dismissAction: @escaping () -> Void) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction()
    }
}
