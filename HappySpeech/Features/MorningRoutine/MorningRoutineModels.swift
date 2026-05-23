import Foundation

// MARK: - MorningRoutineModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum MorningRoutineModels {

    enum StepKind: String, Hashable, CaseIterable {
        case wash
        case articulation
        case wordPractice

        var iconSystemName: String {
            switch self {
            case .wash:           return "drop.fill"
            case .articulation:   return "mouth.fill"
            case .wordPractice:   return "text.bubble.fill"
            }
        }

        var title: String {
            switch self {
            case .wash:           return "Умоемся"
            case .articulation:   return "Разминка для язычка"
            case .wordPractice:   return "3 быстрых слова"
            }
        }

        var subtitle: String {
            switch self {
            case .wash:           return "Вода, мыло, улыбка"
            case .articulation:   return "5 коротких упражнений"
            case .wordPractice:   return "Повтори за Лялей"
            }
        }
    }

    struct Step: Identifiable, Hashable {
        let id: StepKind
        var isDone: Bool
    }

    struct ViewState: Equatable {
        var steps: [Step]
        var progress: Double {
            guard !steps.isEmpty else { return 0 }
            let done = steps.filter { $0.isDone }.count
            return Double(done) / Double(steps.count)
        }

        var isCompleted: Bool {
            steps.allSatisfy { $0.isDone }
        }

        static let initial = ViewState(
            steps: StepKind.allCases.map { Step(id: $0, isDone: false) }
        )
    }
}
