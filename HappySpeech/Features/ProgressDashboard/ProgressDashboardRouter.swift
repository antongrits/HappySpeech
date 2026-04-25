import SwiftUI

// MARK: - ProgressDashboardRoutingLogic

@MainActor
protocol ProgressDashboardRoutingLogic {
    func routeBack()
    func routeOpenSoundDetail(sound: String)
}

// MARK: - ProgressDashboardRouter

@MainActor
final class ProgressDashboardRouter: ProgressDashboardRoutingLogic {

    var onDismiss: (() -> Void)?
    var onOpenSoundDetail: ((String) -> Void)?

    func routeBack() { onDismiss?() }
    func routeOpenSoundDetail(sound: String) { onOpenSoundDetail?(sound) }
}
