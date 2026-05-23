import Foundation
import OSLog

// MARK: - SpecialistScheduleInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class SpecialistScheduleInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SpecialistSchedule"
    )

    let specialistId: String
    var state: SpecialistScheduleModels.ViewState

    init(specialistId: String) {
        self.specialistId = specialistId
        self.state = .initial
    }

    func select(_ weekday: SpecialistScheduleModels.Weekday) {
        state.selectedWeekday = weekday
        Self.logger.info("select weekday \(weekday.rawValue)")
    }
}
