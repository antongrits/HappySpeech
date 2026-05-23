import Foundation
import OSLog

// MARK: - ParentDailyDigestInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class ParentDailyDigestInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ParentDailyDigest"
    )

    var state: ParentDailyDigestModels.ViewState

    init() {
        self.state = .initial
        Self.logger.info("digest loaded")
    }

    func refresh() {
        // stub for daily refresh
        Self.logger.info("digest refresh")
    }
}
