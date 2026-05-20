import AVFoundation
import Foundation
import OSLog

// MARK: - FingerPlayInteractor

@MainActor
final class FingerPlayInteractor {

    private let presenter: FingerPlayPresenter
    private let classifier: GestureClassifier
    private let logger = Logger(subsystem: "ru.happyspeech", category: "FingerPlay.Interactor")
    private var session: [FingerExercise] = []
    private var currentIndex: Int = 0
    private var stageIndex: Int = 0
    private var successesInARow: Int = 0
    private var permissionDenied: Bool = false

    var sessionFinished: Bool = false

    init(
        presenter: FingerPlayPresenter,
        classifier: GestureClassifier = GestureClassifier(),
        session: [FingerExercise]? = nil
    ) {
        self.presenter = presenter
        self.classifier = classifier
        self.session = session ?? FingerPlayCorpus.sessionExercises()
        if self.session.isEmpty {
            // Гарантируем непустую сессию.
            self.session = FingerPlayCorpus.exercises.prefix(5).map { $0 }
        }
    }

    // MARK: - Lifecycle

    /// Запускает сессию. Вызывается после получения / отказа в разрешении
    /// на камеру (PermissionFlowView).
    func start(permissionGranted: Bool) async {
        permissionDenied = !permissionGranted
        currentIndex = 0
        stageIndex = 0
        successesInARow = 0
        await presentCurrent()
    }

    /// Получено новое наблюдение от HandPoseWorker.
    /// `detectedPose` — HandPose.rawValue, `confidence` — [0…1].
    func handleHandPoseObservation(detectedPose: String, confidence: Float) async {
        guard !sessionFinished, currentIndex < session.count else { return }
        let stage = session[currentIndex].stages[stageIndex]
        let matches = classifier.matches(detected: detectedPose,
                                         confidence: confidence,
                                         target: stage.targetPose)
        if matches {
            successesInARow += 1
        } else {
            successesInARow = 0
        }
        await presenter.presentHandPoseUpdate(
            response: .init(detectedPose: detectedPose,
                            matchesTarget: matches,
                            confidence: confidence)
        )
        if classifier.didReachTarget(successesInARow: successesInARow, stage: stage) {
            await advance()
        }
    }

    /// Принудительный переход — кнопка «Готово».
    func skipToNext() async {
        await advance()
    }

    /// Текущее состояние для тестов / отладки.
    func currentExercise() -> FingerExercise? {
        guard currentIndex < session.count else { return nil }
        return session[currentIndex]
    }

    func currentStageIndex() -> Int { stageIndex }

    // MARK: - Private

    private func presentCurrent() async {
        guard currentIndex < session.count else { return }
        await presenter.presentStart(
            response: .init(exercise: session[currentIndex],
                            totalExercises: session.count),
            currentIndex: currentIndex,
            stageIndex: stageIndex,
            permissionDenied: permissionDenied
        )
    }

    private func advance() async {
        successesInARow = 0
        let exercise = session[currentIndex]
        if stageIndex + 1 < exercise.stages.count {
            stageIndex += 1
            await presentCurrent()
            return
        }
        // Стадии исчерпаны — переходим к следующему упражнению.
        let completed = currentIndex + 1
        if completed < session.count {
            currentIndex = completed
            stageIndex = 0
            await presenter.presentAdvance(
                response: .init(nextExercise: session[currentIndex],
                                nextStage: 0,
                                isSessionFinished: false,
                                completedCount: completed),
                permissionDenied: permissionDenied,
                currentIndex: currentIndex,
                stageIndex: 0
            )
        } else {
            sessionFinished = true
            await presenter.presentAdvance(
                response: .init(nextExercise: nil,
                                nextStage: 0,
                                isSessionFinished: true,
                                completedCount: completed),
                permissionDenied: permissionDenied,
                currentIndex: currentIndex,
                stageIndex: stageIndex
            )
        }
    }
}
