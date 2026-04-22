import Foundation
import OSLog

// MARK: - ARMirrorBusinessLogic

@MainActor
protocol ARMirrorBusinessLogic: AnyObject {
    func startGame(_ request: ARMirrorModels.StartGame.Request)
    func updateFrame(_ request: ARMirrorModels.UpdateFrame.Request)
    func scoreAttempt(_ request: ARMirrorModels.ScoreAttempt.Request)
    func advanceToNextExercise()
}

// MARK: - ARMirrorInteractor

@MainActor
final class ARMirrorInteractor: ARMirrorBusinessLogic {

    var presenter: (any ARMirrorPresentationLogic)?

    private let classifier: TonguePostureClassifier
    private var exercises: [ARMirrorModels.Exercise] = ARMirrorModels.Exercise.allCases
    private var currentIndex: Int = 0
    private var sustainedStart: Date?
    private var confidenceSum: Float = 0
    private var confidenceCount: Int = 0

    /// Порог confidence, при котором считаем, что ребёнок держит позу.
    private let confidenceThreshold: Float = 0.6
    /// Сколько секунд нужно удерживать, чтобы засчитать упражнение.
    private let sustainDuration: TimeInterval = 3.0

    init(classifier: TonguePostureClassifier = TonguePostureClassifier()) {
        self.classifier = classifier
    }

    // MARK: - Business

    func startGame(_ request: ARMirrorModels.StartGame.Request) {
        exercises = ARMirrorModels.Exercise.allCases
        currentIndex = 0
        resetExerciseState()
        presenter?.presentStartGame(.init(exercises: exercises, currentIndex: 0))
    }

    func updateFrame(_ request: ARMirrorModels.UpdateFrame.Request) {
        guard let exercise = currentExercise else { return }
        let confidence = classifier.confidence(request.blendshapes, for: exercise.targetPosture)

        confidenceSum += confidence
        confidenceCount += 1

        if confidence >= confidenceThreshold {
            if sustainedStart == nil { sustainedStart = Date() }
        } else {
            sustainedStart = nil
        }

        let sustainedSeconds = sustainedStart.map { Date().timeIntervalSince($0) } ?? 0
        let didComplete = sustainedSeconds >= sustainDuration

        presenter?.presentUpdateFrame(.init(
            currentExercise: exercise,
            confidence: confidence,
            sustainedSeconds: sustainedSeconds,
            didCompleteExercise: didComplete
        ))

        if didComplete {
            let avg = confidenceCount > 0 ? confidenceSum / Float(confidenceCount) : 0
            scoreAttempt(.init(exercise: exercise, averageConfidence: avg))
        }
    }

    func scoreAttempt(_ request: ARMirrorModels.ScoreAttempt.Request) {
        let stars: Int
        switch request.averageConfidence {
        case 0.85...:  stars = 3
        case 0.7..<0.85: stars = 2
        case 0.5..<0.7: stars = 1
        default:       stars = 0
        }
        HSLogger.ar.info("ARMirror scored \(stars) stars for \(request.exercise.rawValue, privacy: .public) avg=\(request.averageConfidence)")
        presenter?.presentScoreAttempt(.init(stars: stars))
    }

    func advanceToNextExercise() {
        guard currentIndex < exercises.count - 1 else {
            HSLogger.ar.info("ARMirror — all exercises complete")
            return
        }
        currentIndex += 1
        resetExerciseState()
        presenter?.presentStartGame(.init(exercises: exercises, currentIndex: currentIndex))
    }

    // MARK: - Helpers

    private var currentExercise: ARMirrorModels.Exercise? {
        guard exercises.indices.contains(currentIndex) else { return nil }
        return exercises[currentIndex]
    }

    private func resetExerciseState() {
        sustainedStart = nil
        confidenceSum = 0
        confidenceCount = 0
    }
}
