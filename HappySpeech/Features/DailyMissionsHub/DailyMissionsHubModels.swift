import Foundation

// MARK: - DailyMissionsHubModels

/// Хаб ежедневных миссий ребёнка. Выполнение миссий определяется реальной
/// активностью за сегодня (история сессий по `templateType`) плюс явные
/// отметки, сохраняемые на текущий день.
enum DailyMissionsHubModels {

    enum Mission: String, CaseIterable, Identifiable, Hashable {
        case warmup
        case soundOfDay
        case bingo
        case breathing
        case story

        var id: String { rawValue }

        /// `templateType` сессий, засчитывающих миссию как выполненную.
        /// Если сегодня была сессия с одним из этих типов — миссия авто-выполнена.
        var matchingTemplateTypes: Set<String> {
            switch self {
            case .warmup:
                return [TemplateType.articulationImitation.rawValue]
            case .soundOfDay:
                return [
                    TemplateType.repeatAfterModel.rawValue,
                    TemplateType.listenAndChoose.rawValue,
                    TemplateType.minimalPairs.rawValue
                ]
            case .bingo:
                return [TemplateType.bingo.rawValue, TemplateType.memory.rawValue]
            case .breathing:
                return [TemplateType.breathing.rawValue, TemplateType.rhythm.rawValue]
            case .story:
                return [
                    TemplateType.narrativeQuest.rawValue,
                    TemplateType.storyCompletion.rawValue
                ]
            }
        }

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

        var allDone: Bool {
            completed.count >= Mission.allCases.count
        }
    }
}
