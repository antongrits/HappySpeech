import Foundation
import OSLog

// MARK: - RetellingBusinessLogic

@MainActor
protocol RetellingBusinessLogic: AnyObject {
    func start(request: RetellingModels.Start.Request) async
    func toggleLink(request: RetellingModels.ToggleLink.Request) async
    func finish(request: RetellingModels.Finish.Request) async
}

// MARK: - RetellingDataStore

@MainActor
protocol RetellingDataStore: AnyObject {
    var childId: String { get set }
    var story: RetellingStory? { get set }
    var coveredFrameIds: Set<String> { get set }
}

// MARK: - RetellingInteractor (Clean Swift: Interactor)
//
// v29 Фаза 8, Функция 2 «Расскажи по-настоящему».
//
// Бизнес-логика пересказа: подаёт историю, отмечает озвученные ребёнком
// смысловые звенья (кадры), на завершении считает покрытие и собирает
// наводящие вопросы по пропущенным звеньям. Без оценки «правильно/неверно» —
// методически верно для связной речи (важна полнота пересказа).

@MainActor
final class RetellingInteractor: RetellingBusinessLogic, RetellingDataStore {

    // MARK: - DataStore

    var childId: String
    var story: RetellingStory?
    var coveredFrameIds: Set<String> = []

    // MARK: - VIP

    var presenter: (any RetellingPresentationLogic)?

    // MARK: - Deps

    private let worker: any RetellingWorkerProtocol
    private let hapticService: any HapticService

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "Retelling.Interactor"
    )

    // MARK: - Init

    init(
        childId: String,
        worker: any RetellingWorkerProtocol,
        hapticService: any HapticService
    ) {
        self.childId = childId
        self.worker = worker
        self.hapticService = hapticService
    }

    // MARK: - Start

    func start(request: RetellingModels.Start.Request) async {
        childId = request.childId
        let response = await worker.pickStory(childId: request.childId)
        story = response.story
        coveredFrameIds = []
        Self.logger.debug("Started retelling: \(response.story.id, privacy: .public)")
        await presenter?.presentStart(response: response)
    }

    // MARK: - ToggleLink

    func toggleLink(request: RetellingModels.ToggleLink.Request) async {
        guard let story else {
            Self.logger.warning("Toggle before story loaded")
            return
        }
        if coveredFrameIds.contains(request.frameId) {
            coveredFrameIds.remove(request.frameId)
        } else {
            coveredFrameIds.insert(request.frameId)
            hapticService.notification(.success)
        }
        let response = RetellingModels.ToggleLink.Response(
            coveredFrameIds: coveredFrameIds,
            totalFrames: story.frames.count
        )
        await presenter?.presentToggle(response: response)
    }

    // MARK: - Finish

    func finish(request: RetellingModels.Finish.Request) async {
        guard let story else {
            Self.logger.warning("Finish before story loaded")
            return
        }
        let missed = story.frames
            .filter { !coveredFrameIds.contains($0.id) }
            .map(\.link)
        let response = RetellingModels.Finish.Response(
            coveredCount: coveredFrameIds.count,
            totalFrames: story.frames.count,
            missedLinks: missed
        )
        _ = request.voiceRecorded
        Self.logger.debug(
            "Retelling finished: \(self.coveredFrameIds.count)/\(story.frames.count) links"
        )
        await presenter?.presentFinish(response: response)
    }
}
