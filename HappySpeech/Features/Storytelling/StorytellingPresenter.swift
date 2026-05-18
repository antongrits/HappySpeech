import Foundation
import OSLog

// MARK: - StorytellingPresentationLogic

@MainActor
protocol StorytellingPresentationLogic: AnyObject {
    func presentTopics(response: StorytellingModels.LoadTopics.Response) async
    func presentTopicStart(response: StorytellingModels.StartTopic.Response) async
    func presentToggle(response: StorytellingModels.ToggleStep.Response) async
    func presentFinish(response: StorytellingModels.Finish.Response) async
}

// MARK: - StorytellingPresenter (Clean Swift: Presenter)
//
// v29 Фаза 8, Функция 11 «Я расскажу историю».
//
// Строит ViewModel выбора темы, плана-схемы и итоговой сводки.
// Все строки — String(localized:).

@MainActor
final class StorytellingPresenter: StorytellingPresentationLogic {

    weak var displayLogic: (any StorytellingDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "Storytelling.Presenter"
    )

    init(displayLogic: (any StorytellingDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Topics

    func presentTopics(response: StorytellingModels.LoadTopics.Response) async {
        let cards = response.topics.map { topic in
            StorytellingModels.LoadTopics.TopicCardViewModel(
                id: topic.id,
                title: topic.title,
                symbolName: topic.symbolName,
                accessibilityLabel: String(
                    format: String(localized: "storytelling.topic.a11y"),
                    topic.title
                )
            )
        }
        let viewModel = StorytellingModels.LoadTopics.ViewModel(
            title: String(localized: "storytelling.title"),
            topics: cards
        )
        await displayLogic?.displayTopics(viewModel: viewModel)
    }

    // MARK: - Topic start

    func presentTopicStart(response: StorytellingModels.StartTopic.Response) async {
        let steps = response.topic.plan.map { step in
            StorytellingModels.StartTopic.StepViewModel(
                id: step.id,
                question: step.question,
                symbolName: step.symbolName,
                accessibilityLabel: String(
                    format: String(localized: "storytelling.step.a11y"),
                    step.question
                )
            )
        }
        let viewModel = StorytellingModels.StartTopic.ViewModel(
            topicTitle: response.topic.title,
            symbolName: response.topic.symbolName,
            steps: steps
        )
        await displayLogic?.displayTopicStart(viewModel: viewModel)
    }

    // MARK: - Toggle

    func presentToggle(response: StorytellingModels.ToggleStep.Response) async {
        let fraction = response.totalSteps > 0
            ? Double(response.completedStepIds.count) / Double(response.totalSteps)
            : 0
        let viewModel = StorytellingModels.ToggleStep.ViewModel(
            completedStepIds: response.completedStepIds,
            progressLabel: String(
                format: String(localized: "storytelling.progress"),
                response.completedStepIds.count,
                response.totalSteps
            ),
            progressFraction: fraction
        )
        await displayLogic?.displayToggle(viewModel: viewModel)
    }

    // MARK: - Finish

    func presentFinish(response: StorytellingModels.Finish.Response) async {
        let fraction = response.totalSteps > 0
            ? Double(response.completedCount) / Double(response.totalSteps)
            : 0
        let saved = fraction >= StorytellingInteractor.bookSaveThreshold
        let viewModel = StorytellingModels.Finish.ViewModel(
            title: saved
                ? String(localized: "storytelling.summary.saved")
                : String(localized: "storytelling.summary.title"),
            scoreText: String(
                format: String(localized: "storytelling.summary.score"),
                response.completedCount,
                response.totalSteps
            ),
            progressFraction: fraction,
            savedToBook: saved,
            encouragement: Self.encouragement(for: fraction)
        )
        await displayLogic?.displayFinish(viewModel: viewModel)
    }

    // MARK: - Helpers

    private static func encouragement(for fraction: Double) -> String {
        if fraction >= 0.75 {
            return String(localized: "storytelling.encourage.great")
        } else if fraction >= 0.4 {
            return String(localized: "storytelling.encourage.good")
        } else {
            return String(localized: "storytelling.encourage.keepGoing")
        }
    }
}
