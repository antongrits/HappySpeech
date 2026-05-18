import Foundation

// MARK: - StorytellingModels (Clean Swift: Models)
//
// v29 Фаза 8, Функция 11 «Я расскажу историю» — собственный нарратив ребёнка.
//
// Самостоятельное программирование развёрнутого высказывания по плану-схеме
// (начало — середина — конец / кто — что делает — какой — где) — высшая
// ступень связной речи. Венчает линию связной речи (Функции 2, 7, 11).
//
// VIP-модуль; контент — `StorytellingCorpus` (offline / on-device).

// MARK: - StoryPlanStep

/// Шаг плана-схемы рассказа.
public struct StoryPlanStep: Identifiable, Sendable, Equatable {
    public let id: String
    /// Вопрос-опора шага («Кто герой?», «Где это было?»).
    public let question: String
    /// SF Symbol шага.
    public let symbolName: String

    public init(id: String, question: String, symbolName: String) {
        self.id = id
        self.question = question
        self.symbolName = symbolName
    }
}

// MARK: - StoryTopic

/// Тема-стимул для рассказа.
public struct StoryTopic: Identifiable, Sendable, Equatable {
    public let id: String
    /// Название темы («Прогулка в зоопарк»).
    public let title: String
    /// SF Symbol-картинка темы.
    public let symbolName: String
    /// План-схема рассказа.
    public let plan: [StoryPlanStep]

    public init(id: String, title: String, symbolName: String, plan: [StoryPlanStep]) {
        self.id = id
        self.title = title
        self.symbolName = symbolName
        self.plan = plan
    }
}

// MARK: - StorytellingModels namespace

enum StorytellingModels {

    // MARK: LoadTopics

    enum LoadTopics {
        struct Request: Sendable {
            let childId: String
        }

        struct Response: Sendable {
            let topics: [StoryTopic]
        }

        struct ViewModel: Sendable {
            let title: String
            let topics: [TopicCardViewModel]
        }

        struct TopicCardViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let title: String
            let symbolName: String
            let accessibilityLabel: String
        }
    }

    // MARK: StartTopic

    enum StartTopic {
        struct Request: Sendable {
            let topicId: String
        }

        struct Response: Sendable {
            let topic: StoryTopic
        }

        struct ViewModel: Sendable {
            let topicTitle: String
            let symbolName: String
            let steps: [StepViewModel]
        }

        struct StepViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let question: String
            let symbolName: String
            let accessibilityLabel: String
        }
    }

    // MARK: ToggleStep

    enum ToggleStep {
        struct Request: Sendable {
            let stepId: String
        }

        struct Response: Sendable {
            let completedStepIds: Set<String>
            let totalSteps: Int
        }

        struct ViewModel: Sendable {
            let completedStepIds: Set<String>
            let progressLabel: String
            let progressFraction: Double
        }
    }

    // MARK: Finish

    enum Finish {
        struct Request: Sendable {
            let voiceRecorded: Bool
        }

        struct Response: Sendable {
            let completedCount: Int
            let totalSteps: Int
            let topicTitle: String
        }

        struct ViewModel: Sendable {
            let title: String
            let scoreText: String
            let progressFraction: Double
            /// Сохраняется ли рассказ в «Книжку историй».
            let savedToBook: Bool
            let encouragement: String
        }
    }
}
