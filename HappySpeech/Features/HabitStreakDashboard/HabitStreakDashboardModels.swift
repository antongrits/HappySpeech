import Foundation

// MARK: - HabitStreakDashboardModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum HabitStreakDashboardModels {

    /// Один день в heat-map календаре. `intensity` от 0 до 4
    /// (как у GitHub contributions). 0 — нет практики.
    struct Day: Identifiable, Hashable {
        let id: Int          // dayOffset (от 0 = ровно 12 недель назад)
        let intensity: Int   // 0...4
        let minutes: Int

        static func intensityForMinutes(_ minutes: Int) -> Int {
            switch minutes {
            case 0:        return 0
            case 1...4:    return 1
            case 5...9:    return 2
            case 10...14:  return 3
            default:       return 4
            }
        }
    }

    struct ViewState: Equatable {
        var days: [Day]
        var selected: Day?

        /// 12 недель × 7 дней = 84 ячейки.
        static let weeks: Int = 12
        static let daysPerWeek: Int = 7

        var currentStreak: Int {
            var streak = 0
            for day in days.reversed() where day.intensity > 0 {
                streak += 1
            }
            // tally consecutive >0 from the end
            var counted = 0
            for day in days.reversed() {
                if day.intensity > 0 { counted += 1 } else { break }
            }
            return max(streak, counted)
        }

        var totalMinutes: Int {
            days.reduce(0) { $0 + $1.minutes }
        }

        static let initial: ViewState = {
            // Deterministic pseudo-random pattern using index seeding —
            // нужен предсказуемый preview без зависимостей от Calendar.
            var days: [Day] = []
            for offset in 0..<(weeks * daysPerWeek) {
                let seed = (offset * 7 + 3) % 23
                let minutes: Int
                switch seed {
                case 0...4:    minutes = 0
                case 5...9:    minutes = 3
                case 10...14:  minutes = 8
                case 15...19:  minutes = 12
                default:       minutes = 18
                }
                days.append(Day(
                    id: offset,
                    intensity: Day.intensityForMinutes(minutes),
                    minutes: minutes
                ))
            }
            return ViewState(days: days, selected: nil)
        }()
    }
}
