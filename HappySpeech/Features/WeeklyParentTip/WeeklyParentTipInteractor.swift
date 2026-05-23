import Foundation
import OSLog

// MARK: - WeeklyParentTipInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class WeeklyParentTipInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "WeeklyParentTip"
    )

    var state: WeeklyParentTipModels.ViewState

    init() {
        self.state = .initial
    }

    func recordShare() {
        Self.logger.info("share tip \(self.state.tip.id, privacy: .public)")
    }
}
