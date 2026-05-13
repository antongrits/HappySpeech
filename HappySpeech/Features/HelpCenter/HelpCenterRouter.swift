import Foundation
import SwiftUI

// MARK: - HelpCenterRoutingLogic

@MainActor
protocol HelpCenterRoutingLogic: AnyObject {
    func dismiss()
    func routeToLogopedistChat()
}

// MARK: - HelpCenterRouter (Clean Swift: Router)
//
// Block AE v21 — навигация для HelpCenter.
//
// Detail видео отображается inline (через AVPlayer-обёртку), не требует
// внешней навигации. Контакт-CTA уводит в существующий `LogopedistChat`
// (deep link через callback).

@MainActor
final class HelpCenterRouter: HelpCenterRoutingLogic {

    var dismissAction: (() -> Void)?
    var openLogopedistChatAction: (() -> Void)?

    init(
        dismissAction: (() -> Void)? = nil,
        openLogopedistChatAction: (() -> Void)? = nil
    ) {
        self.dismissAction = dismissAction
        self.openLogopedistChatAction = openLogopedistChatAction
    }

    func dismiss() {
        dismissAction?()
    }

    func routeToLogopedistChat() {
        openLogopedistChatAction?()
    }
}
