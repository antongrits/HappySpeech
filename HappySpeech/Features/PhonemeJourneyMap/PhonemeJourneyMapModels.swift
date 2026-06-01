import Foundation

// MARK: - PhonemeJourneyMapModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum PhonemeJourneyMapModels {

    enum Stage: Int, CaseIterable, Identifiable, Hashable {
        case isolated  = 0
        case syllables
        case words
        case phrases
        case freeSpeech

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .isolated:   return "Изолированно"
            case .syllables:  return "Слоги"
            case .words:      return "Слова"
            case .phrases:    return "Фразы"
            case .freeSpeech: return "Свободная речь"
            }
        }

        var caption: String {
            switch self {
            case .isolated:   return "Произнеси звук отдельно"
            case .syllables:  return "Слоги ра-ро-ру"
            case .words:      return "Простые слова со звуком"
            case .phrases:    return "Короткие фразы"
            case .freeSpeech: return "Рассказывай свободно"
            }
        }

        var iconSystemName: String {
            switch self {
            case .isolated:   return "circle.fill"
            case .syllables:  return "music.note.list"
            case .words:      return "text.bubble"
            case .phrases:    return "text.alignleft"
            case .freeSpeech: return "person.wave.2"
            }
        }
    }

    struct StageItem: Identifiable, Hashable {
        let id: Stage
        var isComplete: Bool
    }

    struct ViewState: Equatable {
        var targetSound: String
        var stages: [StageItem]

        var currentIndex: Int {
            stages.firstIndex(where: { !$0.isComplete }) ?? stages.count - 1
        }

        var progress: Double {
            let done = stages.filter(\.isComplete).count
            return Double(done) / Double(stages.count)
        }

        /// Пустое стартовое состояние: все этапы не завершены, пока не загружен
        /// реальный прогресс из репозиториев. Никаких выдуманных «готовых» этапов.
        static let empty = ViewState(
            targetSound: "",
            stages: Stage.allCases.map { StageItem(id: $0, isComplete: false) }
        )
    }
}
