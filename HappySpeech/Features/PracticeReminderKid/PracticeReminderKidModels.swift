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
        /// Имя ребёнка для персонализированного заголовка.
        var childName: String
        /// Целевой звук дня (например «Р»).
        var targetSound: String

        static let initial = ViewState(
            minutesToday: 0,
            streakDays: 0,
            isDismissed: false,
            isLoading: true,
            childName: "",
            targetSound: ""
        )
    }
}
