import Foundation
import SwiftUI

// MARK: - CulturalContentRoutingLogic

@MainActor
protocol CulturalContentRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - CulturalContentRouter (Clean Swift: Router)
//
// Block R.5 v18 — модальная навигация (sheet).
// Внутри переход на ItemReader экранно-локальный (через @State флаг).

@MainActor
final class CulturalContentRouter: CulturalContentRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
