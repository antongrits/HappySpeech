import Foundation

// MARK: - BreatheAndSpeakModels (Clean Swift: Models)
//
// v29 Фаза 8, Функция 10 «Дыши и говори».
//
// Артикуляционно-дыхательные комплексы под целевую группу звуков. Отдельные
// упражнения артикуляционной и дыхательной гимнастики собраны в методически
// верные комплексы с прогрессией (Фомичёва: гимнастика эффективна как
// ежедневный последовательный комплекс). Цель — дизартрия, дислалия
// (подготовительный этап), заикание, ОНР.
//
// VIP-модуль ведёт ребёнка по «комплексу дня»: каждый шаг — упражнение с
// удержанием позы или выдохом; модуль показывает инструкцию и счётчик
// удержания. Контент — `BreatheAndSpeakCorpus`.

// MARK: - ExerciseKind

/// Тип упражнения в комплексе.
public enum ExerciseKind: String, Sendable {
    /// Артикуляционная поза — удержание уклада органов речи.
    case articulation
    /// Дыхательное упражнение — плавный длительный выдох.
    case breathing
}

// MARK: - ComplexExercise

/// Одно упражнение комплекса.
public struct ComplexExercise: Identifiable, Sendable, Equatable {
    public let id: String
    public let kind: ExerciseKind
    /// Название упражнения («Грибок», «Лошадка», «Задуй свечу»).
    public let name: String
    /// Краткая инструкция для ребёнка.
    public let instruction: String
    /// SF Symbol для иллюстрации.
    public let symbolName: String
    /// Рекомендуемое время удержания позы / выдоха, секунды.
    public let holdSeconds: Int

    public init(
        id: String,
        kind: ExerciseKind,
        name: String,
        instruction: String,
        symbolName: String,
        holdSeconds: Int
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.instruction = instruction
        self.symbolName = symbolName
        self.holdSeconds = holdSeconds
    }
}

// MARK: - ArticulationComplex

/// Методический комплекс под группу звуков.
public struct ArticulationComplex: Identifiable, Sendable, Equatable {
    public let id: String
    /// Группа звуков, под которую собран комплекс («Р», «С», «Ш»).
    public let soundGroup: String
    /// Название комплекса для показа.
    public let title: String
    /// Упражнения в методически верном порядке.
    public let exercises: [ComplexExercise]

    public init(
        id: String,
        soundGroup: String,
        title: String,
        exercises: [ComplexExercise]
    ) {
        self.id = id
        self.soundGroup = soundGroup
        self.title = title
        self.exercises = exercises
    }
}

// MARK: - BreatheAndSpeakModels namespace

enum BreatheAndSpeakModels {

    // MARK: Start

    enum Start {
        struct Request: Sendable {
            let childId: String
        }

        struct Response: Sendable {
            let complex: ArticulationComplex
        }

        struct ViewModel: Sendable {
            let title: String
            let complexTitle: String
            let totalSteps: Int
            let firstStep: StepViewModel
        }

        struct StepViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let kind: ExerciseKind
            let name: String
            let instruction: String
            let symbolName: String
            let holdSeconds: Int
            let stepLabel: String
            let progressFraction: Double
            let accessibilityLabel: String
        }
    }

    // MARK: Advance
    //
    // Переход к следующему упражнению комплекса.

    enum Advance {
        struct Request: Sendable {}

        struct Response: Sendable {
            let isFinished: Bool
            let nextStep: ComplexExercise?
            let nextStepIndex: Int?
            let completedSteps: Int
            let totalSteps: Int
        }

        struct ViewModel: Sendable {
            let isFinished: Bool
            let nextStep: Start.StepViewModel?
            let summary: SummaryViewModel?
        }

        struct SummaryViewModel: Sendable {
            let title: String
            let completedSteps: Int
            let totalSteps: Int
            let encouragement: String
        }
    }
}
