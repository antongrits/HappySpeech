import Foundation
import OSLog

// MARK: - ArticulationImitationBusinessLogic

@MainActor
protocol ArticulationImitationBusinessLogic: AnyObject {
    func loadSession(_ request: ArticulationImitationModels.LoadSession.Request)
    func startExercise(_ request: ArticulationImitationModels.StartExercise.Request)
    func beginHold()
    func completeExercise(_ request: ArticulationImitationModels.CompleteExercise.Request)
    func completeSession()
    func cancel()
}

// MARK: - ArticulationImitationInteractor
//
// Состояние игры:
//   loading → [exercisePreview → holding → feedback] × 5 → completed
//
// beginHold запускает `Task` с шагом 0.1с, шлющий HoldProgress до
// достижения `holdSeconds`. При 100% автоматически вызывает
// completeExercise(..., held: true). Если View вызывает cancel
// (например, onDisappear) — Task отменяется.
//
// Скоринг сессии:
//   normalizedScore = starsTotal / outOf
// Каждое удержанное упражнение = 1 звезда. Скор 0…1 передаётся
// наверх через SessionShell.onComplete.

@MainActor
final class ArticulationImitationInteractor: ArticulationImitationBusinessLogic {

    // MARK: - Dependencies

    var presenter: (any ArticulationImitationPresentationLogic)?

    private let logger = HSLogger.app

    // MARK: - Tunables

    /// Частота тиков таймера удержания (100 мс).
    private let tickIntervalSec: Double = 0.1

    /// Стандартное количество упражнений в сессии.
    private let defaultExerciseCount: Int = 5

    // MARK: - Session state

    private(set) var exercises: [ArticulationExercise] = []
    private(set) var currentIndex: Int = 0
    private(set) var starsEarned: Int = 0
    private(set) var childName: String = ""

    /// Таска таймера удержания. Отменяется при `completeExercise` и `cancel`.
    private var holdTask: Task<Void, Never>?

    // MARK: - loadSession

    func loadSession(_ request: ArticulationImitationModels.LoadSession.Request) {
        childName = request.childName
        exercises = ArticulationExercise.exercises(
            for: request.soundGroup,
            count: defaultExerciseCount
        )
        currentIndex = 0
        starsEarned = 0

        logger.info("articulation loadSession soundGroup=\(request.soundGroup, privacy: .public) count=\(self.exercises.count)")

        let response = ArticulationImitationModels.LoadSession.Response(
            exercises: exercises,
            childName: childName
        )
        presenter?.presentLoadSession(response)
    }

    // MARK: - startExercise

    func startExercise(_ request: ArticulationImitationModels.StartExercise.Request) {
        // Отменяем таймер предыдущего упражнения, если он ещё жив.
        holdTask?.cancel()
        holdTask = nil

        currentIndex = max(0, min(request.exerciseIndex, exercises.count - 1))
        guard !exercises.isEmpty, currentIndex < exercises.count else {
            logger.error("articulation startExercise out of bounds index=\(request.exerciseIndex)")
            return
        }

        let exercise = exercises[currentIndex]
        let response = ArticulationImitationModels.StartExercise.Response(
            exercise: exercise,
            exerciseNumber: currentIndex + 1,
            total: exercises.count
        )
        presenter?.presentStartExercise(response)
    }

    // MARK: - beginHold

    func beginHold() {
        guard currentIndex < exercises.count else { return }
        let exercise = exercises[currentIndex]
        let total = Double(exercise.holdSeconds)
        guard total > 0 else {
            completeExercise(.init(exerciseId: exercise.id, held: true))
            return
        }

        holdTask?.cancel()
        let tick = tickIntervalSec
        let targetId = exercise.id
        holdTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let startDate = Date()
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startDate)
                let fraction = min(elapsed / total, 1.0)
                let remaining = max(0, Int(ceil(total - elapsed)))

                let response = ArticulationImitationModels.HoldProgress.Response(
                    fraction: fraction,
                    completed: fraction >= 1.0,
                    remainingSeconds: remaining
                )
                self.presenter?.presentHoldProgress(response)

                if fraction >= 1.0 {
                    // Верифицируем, что таргетное упражнение не сменилось
                    // (защита от race condition между таймером и cancel).
                    if self.currentIndex < self.exercises.count,
                       self.exercises[self.currentIndex].id == targetId {
                        self.completeExercise(.init(exerciseId: targetId, held: true))
                    }
                    return
                }

                let nanos = UInt64(tick * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanos)
            }
        }
    }

    // MARK: - completeExercise

    func completeExercise(_ request: ArticulationImitationModels.CompleteExercise.Request) {
        holdTask?.cancel()
        holdTask = nil

        if request.held {
            starsEarned += 1
        }

        let nextIndex: Int? = (currentIndex + 1 < exercises.count) ? currentIndex + 1 : nil
        let allDone = nextIndex == nil

        logger.info("articulation completeExercise held=\(request.held) stars=\(self.starsEarned) allDone=\(allDone)")

        let response = ArticulationImitationModels.CompleteExercise.Response(
            earnedStar: request.held,
            nextIndex: nextIndex,
            allDone: allDone
        )
        presenter?.presentCompleteExercise(response)
    }

    // MARK: - completeSession

    func completeSession() {
        holdTask?.cancel()
        holdTask = nil

        let outOf = max(exercises.count, 1)
        let response = ArticulationImitationModels.SessionComplete.Response(
            starsTotal: starsEarned,
            outOf: outOf
        )
        logger.info("articulation completeSession stars=\(self.starsEarned)/\(outOf)")
        presenter?.presentSessionComplete(response)
    }

    // MARK: - cancel

    func cancel() {
        holdTask?.cancel()
        holdTask = nil
    }
}
