import Foundation
import OSLog

// MARK: - MimicLyalyaInteractor
//
// VIP-thin Interactor (D.2 v15) — AR игра «Повтори за Лялей».
//
// Clean Swift поток:
//   ARKit (face blendshapes) + Vision (hand pose) → View → Interactor → Presenter → View
//
// AR зависимости:
//   - TonguePostureClassifier: Core ML на ARFaceAnchor.blendShapes (лицевые позы)
//   - HandPoseWorker: Vision VNDetectHumanHandPoseRequest (Block J — дополнительный жест)
//   - Цикл поз: smile → pucker → cupShape → tongueUp → mushroom (5 логопедических упражнений)
//
// Бизнес-правила:
//   - Чётные раунды = лицевые позы, нечётные = лицевые + жест руки
//   - Совпадение позы при confidence > 0.65; оценка ≥ 0.85 = 3 звезды
//   - HandPose: openPalm / point / fist / wave / thumbsUp — чередуются по раундам
//   - Маскот «Ляля» анимируется через Rive state machine (в View, не здесь)
//
// COPPA: нет сетевых вызовов, нет PII. Face tracking — только on-device ARKit.

@MainActor
protocol MimicLyalyaBusinessLogic: AnyObject {
    func startGame(_ request: MimicLyalyaModels.StartGame.Request)
    func updateFrame(_ request: MimicLyalyaModels.UpdateFrame.Request)
    func scoreAttempt(_ request: MimicLyalyaModels.ScoreAttempt.Request)
    func nextRound()
    // Block J: Hand Pose
    func updateHandPose(_ request: MimicLyalyaModels.UpdateHandPose.Request)
}

@MainActor
final class MimicLyalyaInteractor: MimicLyalyaBusinessLogic {

    var presenter: (any MimicLyalyaPresentationLogic)?
    private let classifier = TonguePostureClassifier()
    private let postureCycle: [ArticulationPosture] = [.smile, .pucker, .cupShape, .tongueUp, .mushroom]
    private var currentRound: Int = 0
    private var totalRounds: Int = 5

    // Block J: целевая поза руки для текущего раунда (опциональная — не все раунды требуют жест)
    private var currentHandTarget: HandPose? = nil
    // Порядок чередования: чётные раунды — лицевые, нечётные — жестовые
    private let handPoseCycle: [HandPose] = [.openPalm, .point, .fist, .wave, .thumbsUp]

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

    // MARK: - Block J: Hand Pose evaluation

    /// Обрабатывает наблюдение позы руки от `HandPoseWorker`.
    /// Вызывается из `MimicLyalyaView` каждый раз когда `HandPoseWorker` возвращает результат.
    func updateHandPose(_ request: MimicLyalyaModels.UpdateHandPose.Request) {
        let obs = request.observation
        guard obs.pose != .unknown, obs.confidence > 0.6 else {
            presenter?.presentHandPoseUpdate(.init(
                detectedPose: obs.pose,
                targetPose: currentHandTarget,
                isMatching: false,
                confidence: obs.confidence
            ))
            return
        }

        let isMatching = currentHandTarget.map { obs.pose == $0 } ?? false
        if isMatching {
            HSLogger.ar.info("HandPose matched: \(obs.pose.debugDescription) conf=\(obs.confidence, format: .fixed(precision: 2))")
        }

        presenter?.presentHandPoseUpdate(.init(
            detectedPose: obs.pose,
            targetPose: currentHandTarget,
            isMatching: isMatching,
            confidence: obs.confidence
        ))
    }

    // MARK: - Private

    private func emitCurrent() {
        let target = postureCycle[currentRound % postureCycle.count]
        // Каждый нечётный раунд добавляем жестовую цель (начиная с раунда 1)
        currentHandTarget = currentRound % 2 == 1
            ? handPoseCycle[currentRound % handPoseCycle.count]
            : nil
        presenter?.presentStartGame(.init(
            targetPosture: target,
            roundNumber: currentRound + 1,
            totalRounds: totalRounds
        ))
    }
}
