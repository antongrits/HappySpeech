import Foundation

// MARK: - DailyMissionsHubModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum DailyMissionsHubModels {

    enum Mission: String, CaseIterable, Identifiable, Hashable {
        case warmup
        case soundOfDay
        case bingo
        case breathing
        case story

        var id: String { rawValue }

        var title: String {
            switch self {
            case .warmup:      return "Разминка"
            case .soundOfDay:  return "Звук дня"
            case .bingo:       return "Бинго"
            case .breathing:   return "Дыхание"
            case .story:       return "История"
            }
        }

        var subtitle: String {
            switch self {
            case .warmup:      return "3 короткие позы"
            case .soundOfDay:  return "Сегодня тренируем 1 звук"
            case .bingo:       return "Найди 4 в ряд"
            case .breathing:   return "Спокойные вдохи"
            case .story:       return "Маленький рассказ"
            }
        }

        var icon: String {
            switch self {
            case .warmup:      return "figure.mind.and.body"
            case .soundOfDay:  return "speaker.wave.2.fill"
            case .bingo:       return "square.grid.3x3.fill"
            case .breathing:   return "wind"
            case .story:       return "book.fill"
            }
        }
    }

    struct ViewState {
        var completed: Set<Mission> = []

        var progress: Double {
            Double(completed.count) / Double(Mission.allCases.count)
        }
    }
}
