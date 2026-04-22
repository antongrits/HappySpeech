import Foundation
import OSLog

@MainActor
protocol MimicLyalyaBusinessLogic: AnyObject {
    func startGame(_ request: MimicLyalyaModels.StartGame.Request)
    func updateFrame(_ request: MimicLyalyaModels.UpdateFrame.Request)
    func scoreAttempt(_ request: MimicLyalyaModels.ScoreAttempt.Request)
    func nextRound()
}

@MainActor
final class MimicLyalyaInteractor: MimicLyalyaBusinessLogic {

    var presenter: (any MimicLyalyaPresentationLogic)?
    private let classifier = TonguePostureClassifier()
    private let postureCycle: [ArticulationPosture] = [.smile, .pucker, .cupShape, .tongueUp, .mushroom]
    private var currentRound: Int = 0
    private var totalRounds: Int = 5

    func startGame(_ request: MimicLyalyaModels.StartGame.Request) {
        totalRounds = request.rounds
        currentRound = 0
        emitCurrent()
    }

    func updateFrame(_ request: MimicLyalyaModels.UpdateFrame.Request) {
        let target = postureCycle[currentRound % postureCycle.count]
        let confidence = classifier.confidence(request.blendshapes, for: target)
        presenter?.presentUpdateFrame(.init(confidence: confidence, isMatching: confidence > 0.65))
    }

    func scoreAttempt(_ request: MimicLyalyaModels.ScoreAttempt.Request) {
        let stars = request.confidence >= 0.85 ? 3 : request.confidence >= 0.65 ? 2 : 1
        HSLogger.ar.info("MimicLyalya round \(self.currentRound) stars=\(stars)")
        presenter?.presentScoreAttempt(.init(stars: stars))
    }

    func nextRound() {
        currentRound += 1
        if currentRound >= totalRounds { return }
        emitCurrent()
    }

    private func emitCurrent() {
        let target = postureCycle[currentRound % postureCycle.count]
        presenter?.presentStartGame(.init(
            targetPosture: target,
            roundNumber: currentRound + 1,
            totalRounds: totalRounds
        ))
    }
}
