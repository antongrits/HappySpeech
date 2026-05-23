import Foundation

// MARK: - SpecialistQuickAssessmentModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum SpecialistQuickAssessmentModels {

    enum Category: String, CaseIterable, Identifiable, Hashable {
        case engagement
        case articulation
        case comprehension
        case stamina
        case progress

        var id: String { rawValue }

        var title: String {
            switch self {
            case .engagement:    return "Вовлечённость"
            case .articulation:  return "Артикуляция"
            case .comprehension: return "Понимание задания"
            case .stamina:       return "Выносливость"
            case .progress:      return "Прогресс vs прошлая сессия"
            }
        }

        var subtitle: String {
            switch self {
            case .engagement:    return "Внимание и интерес"
            case .articulation:  return "Чёткость звуков"
            case .comprehension: return "Готовность к инструкции"
            case .stamina:       return "Длительность работы"
            case .progress:      return "Динамика навыков"
            }
        }

        var iconSystemName: String {
            switch self {
            case .engagement:    return "sparkles"
            case .articulation:  return "waveform"
            case .comprehension: return "brain.head.profile"
            case .stamina:       return "bolt.fill"
            case .progress:      return "chart.line.uptrend.xyaxis"
            }
        }
    }

    struct Rating: Identifiable, Hashable {
        let id: Category
        var stars: Int   // 0...5
    }

    struct ViewState: Equatable {
        var ratings: [Rating]
        var isSaved: Bool

        var averageStars: Double {
            guard !ratings.isEmpty else { return 0 }
            return Double(ratings.map(\.stars).reduce(0, +)) / Double(ratings.count)
        }

        static let initial = ViewState(
            ratings: Category.allCases.map { Rating(id: $0, stars: 0) },
            isSaved: false
        )
    }
}
