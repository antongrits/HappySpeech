import Foundation
import OSLog

// MARK: - DailyMissionsHubInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class DailyMissionsHubInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "DailyMissionsHub"
    )

    let childId: String
    var state: DailyMissionsHubModels.ViewState = .init()

    init(childId: String) {
        self.childId = childId
    }

    func markCompleted(_ mission: DailyMissionsHubModels.Mission) {
        state.completed.insert(mission)
        Self.logger.info("Mission completed: \(mission.rawValue, privacy: .public)")
    }
}
