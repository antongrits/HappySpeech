import Foundation
import OSLog

// MARK: - SoundAndFaceInteractor
//
// VIP-thin Interactor (D.2 v15) — AR упражнение «Звук + Артикуляция».
//
// Clean Swift поток:
//   ARView (blendshapes) + ASRService (transcript) → scoreAttempt() → Presenter → View
//
// AR зависимости:
//   - TonguePostureClassifier: Core ML inference на ARFaceAnchor.blendShapes
//   - WhisperKit ASR: транскрипт из AudioService (16kHz, 1-3 сек записи)
//
// Бизнес-правила:
//   - Целевая артикуляция определяется звуком через posture(forSound:)
//   - avgPostureConfidence: среднее по кадрам updateFrame()
//   - Оценка: совпадение ASR + поза ≥ 0.6 = 3 звезды; одно из двух = 2; иначе = 1
//   - Маппинг звук → поза: С/З = smile, Ш/Ж/Ч = cupShape, Р = mushroom, Л = tongueUp
//
// COPPA: ASR работает on-device (WhisperKit). Нет PII в транскриптах (только звуки/слоги).

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
        let newTarget = SoundAndFaceModels.Target(sound: request.targetSound, posture: posture)
        target = newTarget
        sum = 0
        count = 0
        presenter?.presentStartGame(.init(target: newTarget))
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
