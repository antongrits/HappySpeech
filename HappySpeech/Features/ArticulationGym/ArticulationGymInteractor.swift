import Foundation
import OSLog

// MARK: - ArticulationGymBusinessLogic

@MainActor
protocol ArticulationGymBusinessLogic: AnyObject {
    func loadGym(request: ArticulationGymModels.Load.Request) async
    func timerTick(request: ArticulationGymModels.TimerTick.Request) async
    func nextExercise(request: ArticulationGymModels.Next.Request) async
    func completeGym(request: ArticulationGymModels.Complete.Request) async
}

// MARK: - ArticulationGymDataStore

@MainActor
protocol ArticulationGymDataStore: AnyObject {
    var soundGroup: ArticulationSoundGroup { get set }
    var exercises: [ArticulationItem] { get set }
}

// MARK: - ArticulationGymInteractor (Clean Swift: Interactor)
//
// F-302 v25 — «Зарядка для язычка».
//
// Ответственность:
//   • Загрузить набор упражнений по звуковой группе (через Worker).
//   • Вести обратный счётчик: при secondsRemaining == 0 — авто-переход.
//   • Переход к следующему упражнению; на последнем — завершающий экран.
//   • Зафиксировать событие `articulation_gym_completed` в аналитике.

@MainActor
final class ArticulationGymInteractor: ArticulationGymBusinessLogic, ArticulationGymDataStore {

    // MARK: - DataStore

    var soundGroup: ArticulationSoundGroup
    var exercises: [ArticulationItem] = []

    // MARK: - VIP

    var presenter: (any ArticulationGymPresentationLogic)?

    // MARK: - Dependencies

    private let worker: any ArticulationGymWorkerProtocol
    private let analyticsService: any AnalyticsService
    private let hapticService: any HapticService

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ArticulationGym.Interactor"
    )

    // MARK: - Init

    init(
        soundGroup: ArticulationSoundGroup,
        worker: any ArticulationGymWorkerProtocol,
        analyticsService: any AnalyticsService,
        hapticService: any HapticService
    ) {
        self.soundGroup = soundGroup
        self.worker = worker
        self.analyticsService = analyticsService
        self.hapticService = hapticService
    }

    // MARK: - Load

    func loadGym(request: ArticulationGymModels.Load.Request) async {
        soundGroup = request.soundGroup
        exercises = worker.loadExercises(soundGroup: request.soundGroup)
        let response = ArticulationGymModels.Load.Response(
            soundGroup: request.soundGroup,
            exercises: exercises
        )
        Self.logger.debug("Gym loaded: \(self.exercises.count) exercises")
        await presenter?.presentLoad(response: response)
    }

    // MARK: - TimerTick

    func timerTick(request: ArticulationGymModels.TimerTick.Request) async {
        guard request.exerciseIndex >= 0, request.exerciseIndex < exercises.count else { return }
        let duration = exercises[request.exerciseIndex].durationSeconds
        let shouldAdvance = request.secondsRemaining <= 0

        let response = ArticulationGymModels.TimerTick.Response(
            exerciseIndex: request.exerciseIndex,
            secondsRemaining: max(0, request.secondsRemaining),
            shouldAdvance: shouldAdvance
        )
        await presenter?.presentTimerTick(response: response, duration: duration)
    }

    // MARK: - Next

    func nextExercise(request: ArticulationGymModels.Next.Request) async {
        let nextIndex = request.currentIndex + 1
        let isLast = nextIndex >= exercises.count

        if !isLast {
            hapticService.impact(.light)
        }
        let response = ArticulationGymModels.Next.Response(
            nextIndex: nextIndex,
            isLast: isLast
        )
        await presenter?.presentNext(response: response, totalCount: exercises.count)
    }

    // MARK: - Complete

    func completeGym(request: ArticulationGymModels.Complete.Request) async {
        _ = request
        hapticService.notification(.success)
        analyticsService.track(
            event: AnalyticsEvent(
                name: "articulation_gym_completed",
                parameters: [
                    "soundGroup": soundGroup.rawValue,
                    "exerciseCount": String(exercises.count)
                ]
            )
        )
        let response = ArticulationGymModels.Complete.Response(
            exerciseCount: exercises.count,
            soundGroup: soundGroup
        )
        await presenter?.presentComplete(response: response)
    }
}
