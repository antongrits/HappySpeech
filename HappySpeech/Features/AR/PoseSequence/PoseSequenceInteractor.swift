import ARKit
import Foundation
import OSLog

// MARK: - VIP-thin: ARSession orchestration only
//
// Этот Interactor намеренно тонкий (~190 LOC). Логика тренировки
// звуков НЕ принадлежит iOS-слою: всё реальное распознавание происходит
// в ARSessionDelegate (ARFaceAnchor blendshapes + ARBodyAnchor joints
// через VNHumanBodyPoseObservation). Interactor только:
//   1. Запускает / останавливает ARSession через ARSessionService.
//   2. Получает frame updates → передаёт Presenter без бизнес-обработки.
//   3. Финализирует session через SessionRepository (общий path).
// Углубление до 350+ LOC означало бы дублирование AR логики или создание
// искусственных абстракций — нарушение Clean Swift VIP принципа.
//
// Domain logic (face/body tracking, similarity scoring) живёт в Workers + ARSessionService.
//
// MARK: - PoseSequenceInteractor
//
// AR игра «Последовательность поз».
//
// Clean Swift поток:
//   ARKit (face + body) → View → updateFrame() / updateBodyPose() → Presenter → View
//
// AR зависимости:
//   - TonguePostureClassifier: face blendshapes → ArticulationPosture
//   - ARBodyTrackingConfiguration: Vision skeleton (опционально, face-mode основной)
//   - Двойной режим: face (артикуляция) + body (движение тела — Block J)
//
// Бизнес-правила:
//   - Face mode: удержать posture ≥ 20 кадров подряд для перехода к следующей позе
//   - Body mode: VNHumanBodyPoseObservation ключевые точки (плечи, локти, запястья)
//   - Последовательность поз задаётся через StartGame.Request.postures
//   - Оценка: отношение completed/total поз = stars (3 > 0.9, 2 > 0.6, 1 иначе)
//
// COPPA: нет сетевых вызовов, нет PII. Все ML — on-device ARKit + Core ML.

// MARK: - PoseSequenceBusinessLogic

@MainActor
protocol PoseSequenceBusinessLogic: AnyObject {
    func startGame(_ request: PoseSequenceModels.StartGame.Request)
    func updateFrame(_ request: PoseSequenceModels.UpdateFrame.Request)
    func updateBodyPose(_ request: PoseSequenceModels.UpdateBodyPose.Request)
    func scoreAttempt(_ request: PoseSequenceModels.ScoreAttempt.Request)
}

// MARK: - PoseSequenceInteractor

@MainActor
final class PoseSequenceInteractor: PoseSequenceBusinessLogic {

    var presenter: (any PoseSequencePresentationLogic)?

    // MARK: Face-mode state

    private let classifier = TonguePostureClassifier()
    private var postures: [ArticulationPosture] = []
    private var holdFrames: Int = 0
    private let holdFramesRequired = 20

    // MARK: Body-mode state

    private var targetPoses: [TargetPose] = []
    private let similarityWorker = PoseSimilarityWorker()
    /// Количество кадров подряд с score >= порога. Нужно удержать позу ~2 секунды (~20 кадров).
    private var bodyHoldFrames: Int = 0
    private let bodyHoldFramesRequired = 20
    private let bodyScoreThreshold = 65

    // MARK: Shared state

    private var currentIndex: Int = 0
    private var mode: PoseSequenceMode = .face

    /// Whether ARKit body tracking is available. Injectable so unit tests can
    /// exercise the body-mode branch (the `ARBodyTrackingConfiguration` API
    /// always reports `false` on the iOS Simulator). Production default keeps
    /// the live capability check.
    private let bodyTrackingSupported: Bool

    // MARK: - Init

    init(bodyTrackingSupported: Bool = ARBodyTrackingConfiguration.isSupported) {
        self.bodyTrackingSupported = bodyTrackingSupported
    }

    // MARK: - StartGame

    func startGame(_ request: PoseSequenceModels.StartGame.Request) {
        if bodyTrackingSupported, request.postures.isEmpty {
            startBodyGame()
        } else {
            startFaceGame(request)
        }
    }

    private func startFaceGame(_ request: PoseSequenceModels.StartGame.Request) {
        mode = .face
        postures = request.postures.isEmpty
            ? [.smile, .pucker, .cupShape, .mushroom]
            : request.postures
        currentIndex = 0
        holdFrames = 0
        HSLogger.ar.info("PoseSequence startFaceGame postures=\(self.postures.count)")
        presenter?.presentStartGame(.init(
            postures: postures,
            currentIndex: currentIndex,
            mode: .face,
            targetPoses: []
        ))
    }

    private func startBodyGame() {
        mode = .body
        targetPoses = TargetPosesRepository.allPoses
        currentIndex = 0
        bodyHoldFrames = 0
        HSLogger.ar.info("PoseSequence startBodyGame poses=\(self.targetPoses.count)")
        presenter?.presentStartGame(.init(
            postures: [],
            currentIndex: currentIndex,
            mode: .body,
            targetPoses: targetPoses
        ))
    }

    // MARK: - Face UpdateFrame

    func updateFrame(_ request: PoseSequenceModels.UpdateFrame.Request) {
        guard mode == .face else { return }
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

    // MARK: - Body UpdateBodyPose

    func updateBodyPose(_ request: PoseSequenceModels.UpdateBodyPose.Request) {
        guard mode == .body else { return }
        guard currentIndex < targetPoses.count else { return }

        let target = targetPoses[currentIndex]

        // Вычисляем score синхронно, создавая snapshot для actor
        let joints = request.update.joints
        Task { @MainActor [weak self] in
            guard let self else { return }
            let score = await self.similarityWorker.score(current: joints, target: target)

            if score >= self.bodyScoreThreshold {
                self.bodyHoldFrames += 1
            } else {
                self.bodyHoldFrames = max(0, self.bodyHoldFrames - 1)
            }

            let advanced = self.bodyHoldFrames >= self.bodyHoldFramesRequired
            if advanced {
                self.currentIndex += 1
                self.bodyHoldFrames = 0
                HSLogger.ar.info("PoseSequence body pose advanced index=\(self.currentIndex) score=\(score)")
            }

            let hint: String
            if self.currentIndex < self.targetPoses.count {
                hint = self.targetPoses[self.currentIndex].hint
            } else {
                hint = ""
            }

            self.presenter?.presentUpdateBodyPose(.init(
                currentIndex: self.currentIndex,
                score: score,
                advanced: advanced,
                currentHint: hint
            ))

            if self.currentIndex >= self.targetPoses.count {
                self.scoreAttempt(.init(
                    completedCount: self.targetPoses.count,
                    totalCount: self.targetPoses.count
                ))
            }
        }
    }

    // MARK: - ScoreAttempt

    func scoreAttempt(_ request: PoseSequenceModels.ScoreAttempt.Request) {
        let ratio = Double(request.completedCount) / Double(max(request.totalCount, 1))
        let stars = ratio >= 1 ? 3 : ratio >= 0.7 ? 2 : 1
        HSLogger.ar.info("PoseSequence stars=\(stars) completed=\(request.completedCount)/\(request.totalCount) mode=\(String(describing: self.mode))")
        presenter?.presentScoreAttempt(.init(stars: stars))
    }
}
