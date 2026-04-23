import Foundation
import OSLog

@MainActor
protocol SoundAndFaceBusinessLogic: AnyObject {
    func startGame(_ request: SoundAndFaceModels.StartGame.Request)
    func updateFrame(_ request: SoundAndFaceModels.UpdateFrame.Request)
    func scoreAttempt(_ request: SoundAndFaceModels.ScoreAttempt.Request)
}

@MainActor
final class SoundAndFaceInteractor: SoundAndFaceBusinessLogic {

    var presenter: (any SoundAndFacePresentationLogic)?
    private let classifier = TonguePostureClassifier()
    private var target: SoundAndFaceModels.Target?
    private var sum: Float = 0
    private var count: Int = 0

    func startGame(_ request: SoundAndFaceModels.StartGame.Request) {
        let posture = Self.posture(forSound: request.targetSound)
        let t = SoundAndFaceModels.Target(sound: request.targetSound, posture: posture)
        target = t
        sum = 0
        count = 0
        presenter?.presentStartGame(.init(target: t))
    }

    func updateFrame(_ request: SoundAndFaceModels.UpdateFrame.Request) {
        guard let target else { return }
        let confidence = classifier.confidence(request.blendshapes, for: target.posture)
        sum += confidence
        count += 1
        presenter?.presentUpdateFrame(.init(postureConfidence: confidence))
    }

    func scoreAttempt(_ request: SoundAndFaceModels.ScoreAttempt.Request) {
        guard let target else { return }
        let matched = request.asrTranscript.lowercased().contains(target.sound.lowercased())
        let postureOK = request.avgPostureConfidence >= 0.6
        let stars = (matched && postureOK) ? 3 : (matched || postureOK) ? 2 : 1
        HSLogger.ar.info("SoundAndFace stars=\(stars) matched=\(matched) postureOK=\(postureOK)")
        presenter?.presentScoreAttempt(.init(stars: stars, transcriptMatched: matched))
    }

    private static func posture(forSound sound: String) -> ArticulationPosture {
        switch sound.uppercased() {
        case "С", "З":       return .smile
        case "Ш", "Ж", "Ч":  return .cupShape
        case "Р":            return .mushroom
        case "Л":            return .tongueUp
        case "К", "Г", "Х":  return .shoveling
        default:             return .neutral
        }
    }
}
