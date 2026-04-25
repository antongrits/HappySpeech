import SwiftUI

// MARK: - SettingsRoutingLogic

@MainActor
protocol SettingsRoutingLogic {
    func routeBack()
    func routeOpenPrivacyPolicy()
    func routeOpenTerms()
    func routeOpenSpecialistPanel()
}

// MARK: - SettingsRouter
//
// Router без жёсткой привязки к координатору. View задаёт колбэки —
// можно встраивать в любой контейнер (sheet, tab, push) без зависимостей
// от `AppCoordinator`.

@MainActor
final class SettingsRouter: SettingsRoutingLogic {

    var onDismiss: (() -> Void)?
    var onOpenPrivacyPolicy: (() -> Void)?
    var onOpenTerms: (() -> Void)?
    var onOpenSpecialistPanel: (() -> Void)?

    func routeBack() { onDismiss?() }
    func routeOpenPrivacyPolicy() { onOpenPrivacyPolicy?() }
    func routeOpenTerms() { onOpenTerms?() }
    func routeOpenSpecialistPanel() { onOpenSpecialistPanel?() }
}
