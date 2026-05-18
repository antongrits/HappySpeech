import Foundation
import OSLog

// MARK: - CoPlayBusinessLogic

@MainActor
protocol CoPlayBusinessLogic: AnyObject {
    func start(request: CoPlayModels.Start.Request) async
    func nextTurn(request: CoPlayModels.NextTurn.Request) async
}

// MARK: - CoPlayDataStore

@MainActor
protocol CoPlayDataStore: AnyObject {
    var childId: String { get set }
    var activity: CoPlayActivity? { get set }
    var currentIndex: Int { get set }
}

// MARK: - CoPlayInteractor (Clean Swift: Interactor)
//
// v29 Фаза 8, Функция 8 «Занятие вместе».
//
// Бизнес-логика совместной игры: ведёт чередующиеся ходы взрослого и
// ребёнка, продвигает сценарий по подтверждению хода.

@MainActor
final class CoPlayInteractor: CoPlayBusinessLogic, CoPlayDataStore {

    // MARK: - DataStore

    var childId: String
    var activity: CoPlayActivity?
    var currentIndex: Int = 0

    // MARK: - VIP

    var presenter: (any CoPlayPresentationLogic)?

    // MARK: - Deps

    private let worker: any CoPlayWorkerProtocol
    private let hapticService: any HapticService

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "CoPlay.Interactor"
    )

    // MARK: - Init

    init(
        childId: String,
        worker: any CoPlayWorkerProtocol,
        hapticService: any HapticService
    ) {
        self.childId = childId
        self.worker = worker
        self.hapticService = hapticService
    }

    // MARK: - Start

    func start(request: CoPlayModels.Start.Request) async {
        childId = request.childId
        let response = await worker.pickActivity(childId: request.childId)
        activity = response.activity
        currentIndex = 0
        Self.logger.debug("Started co-play: \(response.activity.id, privacy: .public)")
        await presenter?.presentStart(response: response)
    }

    // MARK: - NextTurn

    func nextTurn(request: CoPlayModels.NextTurn.Request) async {
        guard let activity else {
            Self.logger.warning("NextTurn before activity loaded")
            return
        }
        guard currentIndex < activity.turns.count else {
            Self.logger.warning("NextTurn after activity finished")
            return
        }
        _ = request.voiceConfirmed
        hapticService.notification(.success)

        currentIndex += 1
        let isFinished = currentIndex >= activity.turns.count
        let nextTurn = isFinished ? nil : activity.turns[currentIndex]

        let response = CoPlayModels.NextTurn.Response(
            isFinished: isFinished,
            nextTurn: nextTurn,
            nextTurnIndex: isFinished ? nil : currentIndex,
            totalTurns: activity.turns.count
        )
        await presenter?.presentNextTurn(response: response)
    }
}
