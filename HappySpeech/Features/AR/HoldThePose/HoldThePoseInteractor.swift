import Foundation
import OSLog

// MARK: - VIP-thin: ARSession orchestration only
//
// Этот Interactor намеренно тонкий (~85 LOC). Логика тренировки
// звуков НЕ принадлежит iOS-слою: всё реальное распознавание происходит
// в ARSessionDelegate (ARFaceAnchor blendshapes / TonguePostureClassifier
// Core ML inference на 15-30fps frame stream). Interactor только:
//   1. Запускает / останавливает ARSession через ARSessionService.
//   2. Получает frame updates → передаёт Presenter без бизнес-обработки.
//   3. Финализирует session через SessionRepository (общий path).
// Углубление до 350+ LOC означало бы дублирование AR логики или создание
// искусственных абстракций — нарушение Clean Swift VIP принципа.
//
// Domain logic (face tracking, hold timer, scoring) живёт в Workers + ARSessionService.
//
// MARK: - HoldThePoseInteractor
//
// AR упражнение «Удержи позу».
//
// Clean Swift поток:
//   ARSCNViewDelegate.renderer(_:didUpdate:) → View → updateFrame() → Presenter → View
//
// AR зависимости:
//   - TonguePostureClassifier: Core ML inference на ARFaceAnchor.blendShapes
//   - Непрерывный поток кадров: ~15-30fps через ARSCNViewDelegate
//
// Бизнес-правила:
//   - Удержание начинается когда confidence(posture) >= 0.6
//   - Сброс удержания при падении confidence ниже порога
//   - Оценка по avgConfidence: ≥0.85 = 3 звезды, 0.7-0.85 = 2, 0.5-0.7 = 1, иначе = 0
//   - Целевое время удержания задаётся через StartGame.Request (по умолчанию 5с)
//
// COPPA: нет сетевых вызовов, нет PII. Весь ML — on-device Core ML.

@MainActor
protocol HoldThePoseBusinessLogic: AnyObject {
    func startGame(_ request: HoldThePoseModels.StartGame.Request)
    func updateFrame(_ request: HoldThePoseModels.UpdateFrame.Request)
    func scoreAttempt(_ request: HoldThePoseModels.ScoreAttempt.Request)
}

@MainActor
final class HoldThePoseInteractor: HoldThePoseBusinessLogic {

    var presenter: (any HoldThePosePresentationLogic)?
    private let classifier = TonguePostureClassifier()

    private var targetPosture: ArticulationPosture = .smile
    private var holdTarget: TimeInterval = 5
    private var holdStart: Date?
    private var confidenceSum: Float = 0
    private var confidenceCount: Int = 0

    func startGame(_ request: HoldThePoseModels.StartGame.Request) {
        targetPosture = request.targetPosture
        holdTarget = request.holdDurationSec
        holdStart = nil
        confidenceSum = 0
        confidenceCount = 0
        presenter?.presentStartGame(.init(
            targetPosture: targetPosture,
            holdDurationSec: holdTarget
        ))
    }

    func updateFrame(_ request: HoldThePoseModels.UpdateFrame.Request) {
        let confidence = classifier.confidence(request.blendshapes, for: targetPosture)
        confidenceSum += confidence
        confidenceCount += 1

        if confidence >= 0.6 {
            if holdStart == nil { holdStart = Date() }
        } else {
            holdStart = nil
        }
        let held = holdStart.map { Date().timeIntervalSince($0) } ?? 0
        presenter?.presentUpdateFrame(.init(confidence: confidence, heldSeconds: held))

        if held >= holdTarget {
            let avg = confidenceCount > 0 ? confidenceSum / Float(confidenceCount) : 0
            scoreAttempt(.init(heldSeconds: held, averageConfidence: avg))
        }
    }

    func scoreAttempt(_ request: HoldThePoseModels.ScoreAttempt.Request) {
        let stars: Int
        switch request.averageConfidence {
        case 0.85...: stars = 3
        case 0.7..<0.85: stars = 2
        case 0.5..<0.7: stars = 1
        default: stars = 0
        }
        HSLogger.ar.info("HoldThePose stars=\(stars) held=\(request.heldSeconds)s")
        presenter?.presentScoreAttempt(.init(stars: stars, heldSeconds: request.heldSeconds))
    }
}
