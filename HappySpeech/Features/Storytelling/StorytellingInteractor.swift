import Foundation
import OSLog

// MARK: - StorytellingBusinessLogic

@MainActor
protocol StorytellingBusinessLogic: AnyObject {
    func loadTopics(request: StorytellingModels.LoadTopics.Request) async
    func startTopic(request: StorytellingModels.StartTopic.Request) async
    func toggleStep(request: StorytellingModels.ToggleStep.Request) async
    func finish(request: StorytellingModels.Finish.Request) async
}

// MARK: - StorytellingDataStore

@MainActor
protocol StorytellingDataStore: AnyObject {
    var childId: String { get set }
    var activeTopic: StoryTopic? { get set }
    var completedStepIds: Set<String> { get set }
}

// MARK: - StorytellingInteractor (Clean Swift: Interactor)
//
// v29 Фаза 8, Функция 11 «Я расскажу историю».
//
// Бизнес-логика творческого нарратива: выбор темы, прохождение плана-схемы
// (ребёнок отмечает озвученные шаги), сохранение рассказа в «Книжку историй».
// Без оценки «правильно/неверно» — методически верно для продуцирования
// связной речи (важна полнота плана).

@MainActor
final class StorytellingInteractor: StorytellingBusinessLogic, StorytellingDataStore {

    // MARK: - DataStore

    var childId: String
    var activeTopic: StoryTopic?
    var completedStepIds: Set<String> = []

    // MARK: - VIP

    var presenter: (any StorytellingPresentationLogic)?

    // MARK: - Deps

    private let worker: any StorytellingWorkerProtocol
    private let hapticService: any HapticService

    /// Минимальная доля шагов плана для сохранения рассказа в книжку.
    static let bookSaveThreshold = 0.75

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "Storytelling.Interactor"
    )

    // MARK: - Init

    init(
        childId: String,
        worker: any StorytellingWorkerProtocol,
        hapticService: any HapticService
    ) {
        self.childId = childId
        self.worker = worker
        self.hapticService = hapticService
    }

    // MARK: - LoadTopics

    func loadTopics(request: StorytellingModels.LoadTopics.Request) async {
        childId = request.childId
        let response = await worker.loadTopics(childId: request.childId)
        Self.logger.debug("Loaded \(response.topics.count) story topics")
        await presenter?.presentTopics(response: response)
    }

    // MARK: - StartTopic

    func startTopic(request: StorytellingModels.StartTopic.Request) async {
        guard let response = worker.topic(id: request.topicId) else {
            Self.logger.warning("Unknown topic: \(request.topicId, privacy: .public)")
            return
        }
        activeTopic = response.topic
        completedStepIds = []
        await presenter?.presentTopicStart(response: response)
    }

    // MARK: - ToggleStep

    func toggleStep(request: StorytellingModels.ToggleStep.Request) async {
        guard let topic = activeTopic else {
            Self.logger.warning("Toggle before topic loaded")
            return
        }
        if completedStepIds.contains(request.stepId) {
            completedStepIds.remove(request.stepId)
        } else {
            completedStepIds.insert(request.stepId)
            hapticService.notification(.success)
        }
        let response = StorytellingModels.ToggleStep.Response(
            completedStepIds: completedStepIds,
            totalSteps: topic.plan.count
        )
        await presenter?.presentToggle(response: response)
    }

    // MARK: - Finish

    func finish(request: StorytellingModels.Finish.Request) async {
        guard let topic = activeTopic else {
            Self.logger.warning("Finish before topic loaded")
            return
        }
        _ = request.voiceRecorded
        let response = StorytellingModels.Finish.Response(
            completedCount: completedStepIds.count,
            totalSteps: topic.plan.count,
            topicTitle: topic.title
        )
        Self.logger.debug(
            "Storytelling finished: \(self.completedStepIds.count)/\(topic.plan.count) steps"
        )
        await presenter?.presentFinish(response: response)
    }
}
