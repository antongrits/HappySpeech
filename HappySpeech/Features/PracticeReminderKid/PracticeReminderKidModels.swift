import Foundation

// MARK: - PracticeReminderKidModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum PracticeReminderKidModels {

    struct ViewState: Equatable {
        var estimatedMinutes: Int
        var streakDays: Int
        var isDismissed: Bool

        static let initial = ViewState(
            estimatedMinutes: 5,
            streakDays: 4,
            isDismissed: false
        )
    }
}
