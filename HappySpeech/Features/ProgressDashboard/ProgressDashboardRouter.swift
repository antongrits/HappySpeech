import OSLog
import SwiftUI

// MARK: - ProgressDashboardRoutingLogic

@MainActor
protocol ProgressDashboardRoutingLogic {
    func routeBack()
    func routeOpenSoundDetail(sound: String)
    func dismiss()
    func routeToSoundDetail(phoneme: String)
}

// MARK: - ProgressDashboardRouter

/// Навигация дашборда. Реальное закрытие/проталкивание экрана делает SwiftUI
/// (через NavigationStack path и dismiss-environment), а роутер только
/// логирует событие и при наличии замыкания делегирует наружу.
@MainActor
final class ProgressDashboardRouter: ProgressDashboardRoutingLogic {

    var onDismiss: (() -> Void)?
    var onOpenSoundDetail: ((String) -> Void)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "ProgressDashboardRouter")

    func routeBack() {
        logger.info("routeBack")
        onDismiss?()
    }

    func routeOpenSoundDetail(sound: String) {
        logger.info("routeOpenSoundDetail sound=\(sound, privacy: .public)")
        onOpenSoundDetail?(sound)
    }

    /// Симметричное alias-имя для дисмисса.
    func dismiss() { routeBack() }

    /// Симметричное alias-имя для открытия деталей звука.
    func routeToSoundDetail(phoneme: String) { routeOpenSoundDetail(sound: phoneme) }
}
