import Foundation
import OSLog

// MARK: - SoundTrafficLightBusinessLogic

@MainActor
protocol SoundTrafficLightBusinessLogic: AnyObject {
    func start(request: SoundTrafficLightModels.Start.Request) async
    func sort(request: SoundTrafficLightModels.Sort.Request) async
}

// MARK: - SoundTrafficLightDataStore

@MainActor
protocol SoundTrafficLightDataStore: AnyObject {
    var childId: String { get set }
    var pair: DifferentiationPair? { get set }
    var rounds: [TrafficLightRound] { get set }
    var currentIndex: Int { get set }
    var correctCount: Int { get set }
}

// MARK: - SoundTrafficLightInteractor (Clean Swift: Interactor)
//
// v29 Фаза 8, Функция 5 «Звуковой светофор».
//
// Бизнес-логика игры дифференциации: ведёт прогресс по раундам, проверяет
// слуховой выбор «гаража», считает точность. Без таймеров-соревнований
// (антифатиговое правило).

@MainActor
final class SoundTrafficLightInteractor: SoundTrafficLightBusinessLogic, SoundTrafficLightDataStore {

    // MARK: - DataStore

    var childId: String
    var pair: DifferentiationPair?
    var rounds: [TrafficLightRound] = []
    var currentIndex: Int = 0
    var correctCount: Int = 0

    // MARK: - VIP

    var presenter: (any SoundTrafficLightPresentationLogic)?

    // MARK: - Deps

    private let worker: any SoundTrafficLightWorkerProtocol
    private let hapticService: any HapticService

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SoundTrafficLight.Interactor"
    )

    // MARK: - Init

    init(
        childId: String,
        worker: any SoundTrafficLightWorkerProtocol,
        hapticService: any HapticService
    ) {
        self.childId = childId
        self.worker = worker
        self.hapticService = hapticService
    }

    // MARK: - Start

    func start(request: SoundTrafficLightModels.Start.Request) async {
        childId = request.childId
        let response = await worker.buildSession(childId: request.childId)
        pair = response.pair
        rounds = response.rounds
        currentIndex = 0
        correctCount = 0
        Self.logger.debug("Started traffic-light: \(response.rounds.count) rounds")
        await presenter?.presentStart(response: response)
    }

    // MARK: - Sort

    func sort(request: SoundTrafficLightModels.Sort.Request) async {
        guard currentIndex < rounds.count else {
            Self.logger.warning("Sort called after session finished")
            return
        }
        let round = rounds[currentIndex]
        let wasCorrect = (round.belongsToA == request.pickedGarageA)
        if wasCorrect {
            correctCount += 1
            hapticService.notification(.success)
        } else {
            hapticService.notification(.warning)
        }

        currentIndex += 1
        let isFinished = currentIndex >= rounds.count
        let nextRound = isFinished ? nil : rounds[currentIndex]

        let response = SoundTrafficLightModels.Sort.Response(
            wasCorrect: wasCorrect,
            isFinished: isFinished,
            nextRound: nextRound,
            nextRoundIndex: isFinished ? nil : currentIndex,
            correctCount: correctCount,
            totalRounds: rounds.count
        )
        await presenter?.presentSort(response: response)
    }
}
