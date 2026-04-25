import SwiftUI
import UIKit

// MARK: - PermissionsRoutingLogic

@MainActor
protocol PermissionsRoutingLogic {
    func routeBack()
    func routeFinished()
    func routeOpenSystemSettings(url: URL)
}

// MARK: - PermissionsRouter
//
// Лёгкий router без AppCoordinator. View задаёт колбэки: onDismiss / onFinished
// (для onboarding-перехода к следующему шагу).

@MainActor
final class PermissionsRouter: PermissionsRoutingLogic {

    var onDismiss: (() -> Void)?
    var onFinished: (() -> Void)?

    func routeBack() {
        onDismiss?()
    }

    func routeFinished() {
        onFinished?()
    }

    func routeOpenSystemSettings(url: URL) {
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}
