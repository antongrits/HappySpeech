import Foundation
import OSLog

// MARK: - AchievementCalendarInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class AchievementCalendarInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "AchievementCalendar"
    )

    let childId: String
    var state: AchievementCalendarModels.ViewState

    init(childId: String) {
        self.childId = childId
        self.state = .initial
    }

    func selectDay(_ day: Int) {
        state.selectedDay = (state.selectedDay == day) ? nil : day
        Self.logger.info("selectDay \(day)")
    }

    var selectedEntry: AchievementCalendarModels.DayEntry? {
        guard let day = state.selectedDay else { return nil }
        return state.days.first(where: { $0.day == day })
    }
}
