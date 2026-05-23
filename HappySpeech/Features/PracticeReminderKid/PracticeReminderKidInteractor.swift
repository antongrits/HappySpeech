import Foundation
import OSLog

// MARK: - PracticeReminderKidInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class PracticeReminderKidInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "PracticeReminderKid"
    )

    let childId: String
    var state: PracticeReminderKidModels.ViewState

    init(childId: String) {
        self.childId = childId
        self.state = .initial
    }

    func snooze() {
        state.isDismissed = true
        Self.logger.info("snoozed reminder for \(self.childId, privacy: .public)")
    }
}
