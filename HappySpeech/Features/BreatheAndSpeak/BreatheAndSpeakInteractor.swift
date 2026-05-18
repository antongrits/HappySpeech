import Foundation
import OSLog

// MARK: - BreatheAndSpeakBusinessLogic

@MainActor
protocol BreatheAndSpeakBusinessLogic: AnyObject {
    func start(request: BreatheAndSpeakModels.Start.Request) async
    func advance(request: BreatheAndSpeakModels.Advance.Request) async
}

// MARK: - BreatheAndSpeakDataStore

@MainActor
protocol BreatheAndSpeakDataStore: AnyObject {
    var childId: String { get set }
    var complex: ArticulationComplex? { get set }
    var currentIndex: Int { get set }
}

// MARK: - BreatheAndSpeakInteractor (Clean Swift: Interactor)
//
// v29 Фаза 8, Функция 10 «Дыши и говори».
//
// Бизнес-логика комплекса: ведёт ребёнка по упражнениям артикуляционно-
// дыхательного комплекса по порядку, без таймеров-соревнований — счётчик
// удержания носит вспомогательный характер.

@MainActor
final class BreatheAndSpeakInteractor: BreatheAndSpeakBusinessLogic, BreatheAndSpeakDataStore {

    // MARK: - DataStore

    var childId: String
    var complex: ArticulationComplex?
    var currentIndex: Int = 0

    // MARK: - VIP

    var presenter: (any BreatheAndSpeakPresentationLogic)?

    // MARK: - Deps

    private let worker: any BreatheAndSpeakWorkerProtocol
    private let hapticService: any HapticService

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "BreatheAndSpeak.Interactor"
    )

    // MARK: - Init

    init(
        childId: String,
        worker: any BreatheAndSpeakWorkerProtocol,
        hapticService: any HapticService
    ) {
        self.childId = childId
        self.worker = worker
        self.hapticService = hapticService
    }

    // MARK: - Start

    func start(request: BreatheAndSpeakModels.Start.Request) async {
        childId = request.childId
        let response = await worker.buildComplex(childId: request.childId)
        complex = response.complex
        currentIndex = 0
        Self.logger.debug("Started breathe-and-speak: \(response.complex.exercises.count) steps")
        await presenter?.presentStart(response: response)
    }

    // MARK: - Advance

    func advance(request: BreatheAndSpeakModels.Advance.Request) async {
        guard let complex else {
            Self.logger.warning("advance called before start")
            return
        }
        guard currentIndex < complex.exercises.count else {
            Self.logger.warning("advance called after complex finished")
            return
        }
        currentIndex += 1
        hapticService.notification(.success)

        let isFinished = currentIndex >= complex.exercises.count
        let nextStep = isFinished ? nil : complex.exercises[currentIndex]

        let response = BreatheAndSpeakModels.Advance.Response(
            isFinished: isFinished,
            nextStep: nextStep,
            nextStepIndex: isFinished ? nil : currentIndex,
            completedSteps: currentIndex,
            totalSteps: complex.exercises.count
        )
        await presenter?.presentAdvance(response: response)
    }
}
