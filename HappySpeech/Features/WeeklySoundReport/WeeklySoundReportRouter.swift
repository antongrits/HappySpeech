import Foundation
import SwiftUI

// MARK: - WeeklySoundReportRoutingLogic

@MainActor
protocol WeeklySoundReportRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - WeeklySoundReportRouter (Clean Swift: Router)
//
// F-301 v25 — навигация. Экран открывается push-ом из ParentHome.
// Share-функция реализуется через нативный `ShareLink` внутри View
// (UIActivityViewController), отдельного routing-вызова не требует.

@MainActor
final class WeeklySoundReportRouter: WeeklySoundReportRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
