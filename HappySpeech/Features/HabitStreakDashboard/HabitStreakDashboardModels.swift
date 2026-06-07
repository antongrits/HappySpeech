import Foundation

// MARK: - HabitStreakDashboardModels

/// Тепловая карта практики ребёнка за 12 недель. Минуты по дням берутся из
/// реальной истории сессий (`HabitStreakDashboardInteractor.refresh()`).
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

        /// Текущая непрерывная серия: подряд идущие активные дни (intensity > 0),
        /// заканчивающиеся сегодня или вчера. Консистентно с методикой daily-streak
        /// (см. SessionComplete.updateStreak, StutteringInteractor.incrementStreak):
        /// сегодня неактивен, но вчера был — серия продолжается до вчера; разрыв
        /// внутри последовательности сбрасывает серию в 0.
        ///
        /// `days` отсортирован по возрастанию dayOffset, последний элемент — сегодня.
        var currentStreak: Int {
            guard let today = days.last else { return 0 }
            // Если ни сегодня, ни вчера не было практики — серия прервана.
            let yesterdayActive = days.count >= 2 && days[days.count - 2].intensity > 0
            guard today.intensity > 0 || yesterdayActive else { return 0 }

            // Если сегодня неактивен (но вчера был) — стартуем отсчёт со «вчера».
            let startIndex = today.intensity > 0 ? days.count - 1 : days.count - 2
            var streak = 0
            for index in stride(from: startIndex, through: 0, by: -1) {
                guard days[index].intensity > 0 else { break }
                streak += 1
            }
            return streak
        }

        var totalMinutes: Int {
            days.reduce(0) { $0 + $1.minutes }
        }

        /// Общее число ячеек сетки (12 × 7 = 84).
        static var totalCells: Int { weeks * daysPerWeek }

        /// Пустая карта (все дни по 0 минут) — честный baseline для загрузки
        /// реальных данных.
        static let empty: ViewState = {
            let days = (0..<totalCells).map { offset in
                Day(id: offset, intensity: 0, minutes: 0)
            }
            return ViewState(days: days, selected: nil)
        }()

        /// Строит карту из словаря «смещение дня → минуты».
        /// `minutesByOffset` индексируется 0…(totalCells-1), где последний — сегодня.
        static func make(minutesByOffset: [Int: Int]) -> ViewState {
            let days = (0..<totalCells).map { offset -> Day in
                let minutes = max(0, minutesByOffset[offset] ?? 0)
                return Day(
                    id: offset,
                    intensity: Day.intensityForMinutes(minutes),
                    minutes: minutes
                )
            }
            return ViewState(days: days, selected: nil)
        }
    }
}
