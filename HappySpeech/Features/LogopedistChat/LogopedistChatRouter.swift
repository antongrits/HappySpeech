import Foundation
import SwiftUI

// MARK: - LogopedistChatRoutingLogic

@MainActor
protocol LogopedistChatRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - LogopedistChatRouter (Clean Swift: Router)
//
// Block R.2 v18 — модальная навигация (sheet).
// Внутри детальный просмотр attachments — local @State.

@MainActor
final class LogopedistChatRouter: LogopedistChatRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
