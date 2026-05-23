import Foundation

// MARK: - AchievementCalendarModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
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

        static let initial: ViewState = {
            var days: [DayEntry] = []
            for d in 1...30 {
                let count: Int
                let top: String?
                switch d {
                case 3:  count = 2; top = "Первый звук"
                case 7:  count = 1; top = "Серия 5 дней"
                case 12: count = 3; top = "Грамота-старт"
                case 15: count = 1; top = "Утренний ритуал"
                case 18: count = 2; top = "Скороговорка"
                case 22: count = 1; top = "Дневник"
                case 28: count = 4; top = "Месяц практики"
                default: count = 0; top = nil
                }
                days.append(DayEntry(id: d, day: d, achievementCount: count, topAchievement: top))
            }
            return ViewState(month: "Май 2026", days: days, selectedDay: nil)
        }()
    }
}
