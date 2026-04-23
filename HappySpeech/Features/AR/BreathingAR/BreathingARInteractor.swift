import Foundation
import OSLog

@MainActor
protocol BreathingARBusinessLogic: AnyObject {
    func startGame(_ request: BreathingARModels.StartGame.Request)
    func updateFrame(_ request: BreathingARModels.UpdateFrame.Request)
    func scoreAttempt(_ request: BreathingARModels.ScoreAttempt.Request)
}

@MainActor
final class BreathingARInteractor: BreathingARBusinessLogic {

    var presenter: (any BreathingARPresentationLogic)?
    private let detector = AirStreamDetector()
    private var totalDandelions = 5
    private var blownCount = 0
    private var sustainedFrames = 0

    func startGame(_ request: BreathingARModels.StartGame.Request) {
        totalDandelions = request.dandelionCount
        blownCount = 0
        sustainedFrames = 0
        detector.reset()
        presenter?.presentStartGame(.init(dandelionCount: totalDandelions))
    }

    func updateFrame(_ request: BreathingARModels.UpdateFrame.Request) {
        let blowing = detector.update(
            blendshapes: request.blendshapes,
            micAmplitude: request.micAmplitude
        )
        if blowing {
            sustainedFrames += 1
            // Каждые ~30 устойчивых кадров (~2 сек) сдуваем один одуванчик.
            if sustainedFrames >= 30, blownCount < totalDandelions {
                blownCount += 1
                sustainedFrames = 0
                HSLogger.ar.info("BreathingAR dandelion blown (\(self.blownCount)/\(self.totalDandelions))")
            }
        } else {
            sustainedFrames = max(0, sustainedFrames - 1)
        }
        presenter?.presentUpdateFrame(.init(isBlowing: blowing, strength: detector.strength))
        if blownCount >= totalDandelions {
            scoreAttempt(.init(blownCount: blownCount, totalCount: totalDandelions))
        }
    }

    func scoreAttempt(_ request: BreathingARModels.ScoreAttempt.Request) {
        let ratio = Double(request.blownCount) / Double(max(request.totalCount, 1))
        let stars = ratio >= 0.9 ? 3 : ratio >= 0.6 ? 2 : 1
        presenter?.presentScoreAttempt(.init(stars: stars, percent: Int(ratio * 100)))
    }
}
