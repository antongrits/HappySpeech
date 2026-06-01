import Foundation

// MARK: - GoalTrackerKidModels

/// Ежедневные цели ребёнка. Текущие значения целей считаются из реальных
/// данных за сегодня (минуты практики, число отработанных звуков, серия дней).
enum GoalTrackerKidModels {

    enum GoalKind: String, Hashable, CaseIterable, Identifiable {
        case minutesToday
        case newSounds
        case streakDays

        var id: String { rawValue }

        var title: String {
            switch self {
            case .minutesToday: return "Минуты сегодня"
            case .newSounds:    return "Новые звуки"
            case .streakDays:   return "Серия дней"
            }
        }

        var iconSystemName: String {
            switch self {
            case .minutesToday: return "clock.fill"
            case .newSounds:    return "waveform"
            case .streakDays:   return "flame.fill"
            }
        }

        var unit: String {
            switch self {
            case .minutesToday: return "мин"
            case .newSounds:    return "шт"
            case .streakDays:   return "дн"
            }
        }
    }

    struct Goal: Identifiable, Hashable {
        let id: GoalKind
        var current: Int
        var target: Int

        var progress: Double {
            guard target > 0 else { return 0 }
            return min(1.0, Double(current) / Double(target))
        }

        var isReached: Bool {
            current >= target
        }
    }

    struct ViewState: Equatable {
        var goals: [Goal]

        var overallProgress: Double {
            guard !goals.isEmpty else { return 0 }
            return goals.map(\.progress).reduce(0, +) / Double(goals.count)
        }

        /// Стартовое состояние — цели с честными нулями (до загрузки реальных
        /// данных). Целевые планки фиксированы методически (дневная норма).
        static let initial = ViewState(goals: [
            Goal(id: .minutesToday, current: 0, target: 10),
            Goal(id: .newSounds, current: 0, target: 3),
            Goal(id: .streakDays, current: 0, target: 7)
        ])

        /// Целевые планки по виду цели (методическая дневная норма).
        static func target(for kind: GoalKind) -> Int {
            switch kind {
            case .minutesToday: return 10
            case .newSounds:    return 3
            case .streakDays:   return 7
            }
        }
    }
}
