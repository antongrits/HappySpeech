import Foundation
import OSLog

@MainActor
protocol PoseSequenceBusinessLogic: AnyObject {
    func startGame(_ request: PoseSequenceModels.StartGame.Request)
    func updateFrame(_ request: PoseSequenceModels.UpdateFrame.Request)
    func scoreAttempt(_ request: PoseSequenceModels.ScoreAttempt.Request)
}

@MainActor
final class PoseSequenceInteractor: PoseSequenceBusinessLogic {

    var presenter: (any PoseSequencePresentationLogic)?
    private let classifier = TonguePostureClassifier()
    private var postures: [ArticulationPosture] = []
    private var currentIndex: Int = 0
    private var holdFrames: Int = 0
    private let holdFramesRequired = 20

    func startGame(_ request: PoseSequenceModels.StartGame.Request) {
        postures = request.postures.isEmpty
            ? [.smile, .pucker, .cupShape, .mushroom]
            : request.postures
        currentIndex = 0
        holdFrames = 0
        presenter?.presentStartGame(.init(postures: postures, currentIndex: currentIndex))
    }

    func updateFrame(_ request: PoseSequenceModels.UpdateFrame.Request) {
        guard currentIndex < postures.count else { return }
        let current = postures[currentIndex]
        let confidence = classifier.confidence(request.blendshapes, for: current)
        if confidence > 0.6 {
            holdFrames += 1
        } else {
            holdFrames = max(0, holdFrames - 1)
        }
        let advanced = holdFrames >= holdFramesRequired
        if advanced {
            currentIndex += 1
            holdFrames = 0
        }
        presenter?.presentUpdateFrame(.init(
            currentIndex: currentIndex,
            confidence: confidence,
            advanced: advanced
        ))
        if currentIndex >= postures.count {
            scoreAttempt(.init(completedCount: postures.count, totalCount: postures.count))
        }
    }

    func scoreAttempt(_ request: PoseSequenceModels.ScoreAttempt.Request) {
        let ratio = Double(request.completedCount) / Double(max(request.totalCount, 1))
        let stars = ratio >= 1 ? 3 : ratio >= 0.7 ? 2 : 1
        HSLogger.ar.info("PoseSequence stars=\(stars) completed=\(request.completedCount)/\(request.totalCount)")
        presenter?.presentScoreAttempt(.init(stars: stars))
    }
}
