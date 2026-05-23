import Foundation

// MARK: - SpecialistReportPDFGenModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum SpecialistReportPDFGenModels {

    enum Section: String, CaseIterable, Hashable, Identifiable {
        case summary
        case progress
        case sounds
        case sessions
        case recommendations

        var id: String { rawValue }

        var title: String {
            switch self {
            case .summary:         return "Краткое резюме"
            case .progress:        return "Прогресс по неделям"
            case .sounds:          return "Звуки и точность"
            case .sessions:        return "Список сессий"
            case .recommendations: return "Рекомендации"
            }
        }

        var icon: String {
            switch self {
            case .summary:         return "doc.text"
            case .progress:        return "chart.line.uptrend.xyaxis"
            case .sounds:          return "waveform"
            case .sessions:        return "list.bullet.rectangle"
            case .recommendations: return "lightbulb"
            }
        }
    }

    struct ViewState: Equatable {
        var sections: Set<Section>
        var childName: String
        var periodLabel: String
        var isGenerating: Bool

        static let initial = ViewState(
            sections: Set(Section.allCases),
            childName: "Аня Кравцова",
            periodLabel: "Май 2026",
            isGenerating: false
        )
    }
}
