import Foundation
import OSLog

// MARK: - HabitStreakDashboardInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class HabitStreakDashboardInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "HabitStreakDashboard"
    )

    let childId: String
    var state: HabitStreakDashboardModels.ViewState

    init(childId: String) {
        self.childId = childId
        self.state = .initial
    }

    func select(_ day: HabitStreakDashboardModels.Day) {
        state.selected = day
        Self.logger.info("select day=\(day.id) minutes=\(day.minutes)")
    }

    func clearSelection() {
        state.selected = nil
    }
}
