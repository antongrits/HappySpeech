import Foundation

// MARK: - MorningRoutineModels

/// Модели утренней рутины.
///
/// Набор коротких утренних шагов (умывание → дыхание → артикуляция → слоги →
/// слова → улыбка). Состояние выполненных шагов персистится на день через
/// `MorningRoutineStore`.
enum MorningRoutineModels {

    enum StepKind: String, Hashable, CaseIterable {
        case wash
        case breathing
        case articulation
        case syllables
        case wordPractice
        case smile

        var iconSystemName: String {
            switch self {
            case .wash:         return "drop.fill"
            case .breathing:    return "wind"
            case .articulation: return "mouth.fill"
            case .syllables:    return "music.note"
            case .wordPractice: return "text.bubble.fill"
            case .smile:        return "face.smiling.fill"
            }
        }

        var title: String {
            switch self {
            case .wash:         return String(localized: "morning.step.wash.title")
            case .breathing:    return String(localized: "morning.step.breathing.title")
            case .articulation: return String(localized: "morning.step.articulation.title")
            case .syllables:    return String(localized: "morning.step.syllables.title")
            case .wordPractice: return String(localized: "morning.step.words.title")
            case .smile:        return String(localized: "morning.step.smile.title")
            }
        }

        var subtitle: String {
            switch self {
            case .wash:         return String(localized: "morning.step.wash.subtitle")
            case .breathing:    return String(localized: "morning.step.breathing.subtitle")
            case .articulation: return String(localized: "morning.step.articulation.subtitle")
            case .syllables:    return String(localized: "morning.step.syllables.subtitle")
            case .wordPractice: return String(localized: "morning.step.words.subtitle")
            case .smile:        return String(localized: "morning.step.smile.subtitle")
            }
        }
    }

    struct Step: Identifiable, Hashable {
        let id: StepKind
        var isDone: Bool
    }

    struct ViewState: Equatable {
        var steps: [Step]
        var isLoaded: Bool = false

        var progress: Double {
            guard !steps.isEmpty else { return 0 }
            let done = steps.filter { $0.isDone }.count
            return Double(done) / Double(steps.count)
        }

        var isCompleted: Bool {
            !steps.isEmpty && steps.allSatisfy { $0.isDone }
        }

        var doneSet: Set<StepKind> {
            Set(steps.filter(\.isDone).map(\.id))
        }

        static let initial = ViewState(
            steps: StepKind.allCases.map { Step(id: $0, isDone: false) }
        )

        /// Состояние из набора выполненных шагов (восстановление из стора).
        static func make(doneSteps: Set<StepKind>) -> ViewState {
            var state = ViewState(
                steps: StepKind.allCases.map { Step(id: $0, isDone: doneSteps.contains($0)) }
            )
            state.isLoaded = true
            return state
        }
    }
}
