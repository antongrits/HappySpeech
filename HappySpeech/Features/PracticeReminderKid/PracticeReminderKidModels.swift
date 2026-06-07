import Foundation

// MARK: - PracticeReminderKidModels (Clean Swift: Models)
//
// Детское напоминание о практике. Числа РЕАЛЬНЫЕ: минуты сегодня —
// из сессий ребёнка (`SessionRepository`), серия — из профиля/сессий
// (паттерн `GoalTrackerKid`). `.initial` нейтрален (нули + loading),
// никакой фабрикации «Серия 4 / 5 мин».

enum PracticeReminderKidModels {

    struct ViewState: Equatable {
        /// Минуты практики сегодня (реальные).
        var minutesToday: Int
        /// Текущая серия активных дней (реальная).
        var streakDays: Int
        var isDismissed: Bool
        var isLoading: Bool

        static let initial = ViewState(
            minutesToday: 0,
            streakDays: 0,
            isDismissed: false,
            isLoading: true
        )
    }
}
