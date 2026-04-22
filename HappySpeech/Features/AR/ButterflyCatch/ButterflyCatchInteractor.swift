import Foundation
import OSLog

@MainActor
protocol ButterflyCatchBusinessLogic: AnyObject {
    func startGame(_ request: ButterflyCatchModels.StartGame.Request)
    func spawnButterfly(_ request: ButterflyCatchModels.SpawnButterfly.Request)
    func scoreAttempt(_ request: ButterflyCatchModels.ScoreAttempt.Request)
}

@MainActor
final class ButterflyCatchInteractor: ButterflyCatchBusinessLogic {

    var presenter: (any ButterflyCatchPresentationLogic)?

    private let classifier = TonguePostureClassifier()
    private var totalCaught = 0
    private var activeButterflies: [UUID: ButterflyCatchModels.Butterfly] = [:]

    func startGame(_ request: ButterflyCatchModels.StartGame.Request) {
        totalCaught = 0
        activeButterflies.removeAll()
        presenter?.presentStartGame(.init(totalButterflies: 0, durationSec: request.durationSec))
    }

    func spawnButterfly(_ request: ButterflyCatchModels.SpawnButterfly.Request) {
        let postures: [ArticulationPosture] = [.smile, .pucker, .cupShape]
        let posture = postures.randomElement() ?? .smile
        let butterfly = ButterflyCatchModels.Butterfly(
            id: UUID(),
            position: CGPoint(x: .random(in: 0.1...0.9), y: .random(in: 0.15...0.45)),
            direction: ButterflyCatchModels.Direction.allCases.randomElement() ?? .left,
            targetPosture: posture
        )
        activeButterflies[butterfly.id] = butterfly
        presenter?.presentSpawnButterfly(.init(butterfly: butterfly))
    }

    func scoreAttempt(_ request: ButterflyCatchModels.ScoreAttempt.Request) {
        guard let butterfly = activeButterflies[request.butterflyId] else { return }
        let confidence = classifier.confidence(request.blendshapes, for: butterfly.targetPosture)
        let caught = confidence >= 0.6
        if caught {
            totalCaught += 1
            activeButterflies.removeValue(forKey: request.butterflyId)
            HSLogger.ar.info("Butterfly caught! total=\(self.totalCaught)")
        }
        presenter?.presentScoreAttempt(.init(caught: caught, totalCaught: totalCaught))
    }
}
