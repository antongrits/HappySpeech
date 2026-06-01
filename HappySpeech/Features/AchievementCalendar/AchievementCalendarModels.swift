import Foundation

// MARK: - AchievementCalendarModels

/// Календарь достижений ребёнка за месяц. Заполняется реальной активностью
/// из истории сессий (`AchievementCalendarInteractor.refresh()`): успешные
/// сессии дают достижения, лучшая сессия дня даёт подпись.
enum AchievementCalendarModels {

    struct DayEntry: Identifiable, Hashable {
        let id: Int
        let day: Int
        let achievementCount: Int
        let topAchievement: String?
    }

    struct ViewState: Equatable {
        var month: String
        var days: [DayEntry]
        var selectedDay: Int?

        var totalAchievements: Int {
            days.reduce(0) { $0 + $1.achievementCount }
        }

        var hasAnyAchievements: Bool { totalAchievements > 0 }

        /// Пустой календарь текущего месяца (все дни по 0) — честный baseline.
        static func empty(now: Date = Date(), calendar: Calendar = .current) -> ViewState {
            let dayCount = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
            let days = (1...dayCount).map { d in
                DayEntry(id: d, day: d, achievementCount: 0, topAchievement: nil)
            }
            return ViewState(month: monthTitle(now, calendar: calendar), days: days, selectedDay: nil)
        }

        /// Стартовое состояние — пустой текущий месяц.
        static let initial: ViewState = .empty()

        /// Заголовок месяца на русском (например «Июнь 2026»).
        static func monthTitle(_ date: Date, calendar: Calendar = .current) -> String {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.locale = Locale(identifier: "ru_RU")
            formatter.dateFormat = "LLLL yyyy"
            return formatter.string(from: date).capitalized
        }
    }
}
