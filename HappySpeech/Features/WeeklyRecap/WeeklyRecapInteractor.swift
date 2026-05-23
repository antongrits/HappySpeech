import Foundation
import OSLog

// MARK: - WeeklyRecapInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class WeeklyRecapInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "WeeklyRecap"
    )

    var state: WeeklyRecapModels.ViewState = .preview

    func share() -> String {
        Self.logger.info("Weekly recap share requested")
        return WeeklyRecapModels.shareText(state)
    }
}
