@testable import HappySpeech
import ARKit
import XCTest

// MARK: - Spy Presenter

@MainActor
private final class SpyPoseSequencePresenter: PoseSequencePresentationLogic {
    var startGameCallCount = 0
    var updateFrameCallCount = 0
    var updateBodyPoseCallCount = 0
    var scoreCallCount = 0

    var lastStartGame: PoseSequenceModels.StartGame.Response?
    var lastUpdateFrame: PoseSequenceModels.UpdateFrame.Response?
    var lastUpdateBodyPose: PoseSequenceModels.UpdateBodyPose.Response?
    var lastScore: PoseSequenceModels.ScoreAttempt.Response?

    func presentStartGame(_ response: PoseSequenceModels.StartGame.Response) {
        startGameCallCount += 1
        lastStartGame = response
    }
    func presentUpdateFrame(_ response: PoseSequenceModels.UpdateFrame.Response) {
        updateFrameCallCount += 1
        lastUpdateFrame = response
    }
    func presentUpdateBodyPose(_ response: PoseSequenceModels.UpdateBodyPose.Response) {
        updateBodyPoseCallCount += 1
        lastUpdateBodyPose = response
    }
    func presentScoreAttempt(_ response: PoseSequenceModels.ScoreAttempt.Response) {
        scoreCallCount += 1
        lastScore = response
    }
}

// MARK: - Tests
//
// Заметка о покрытии AR-кода (AR-blocked, ~100 строк):
// PoseSequenceInteractor имеет два режима. Body-режим (`startBodyGame`,
// `updateBodyPose` + его async-closure) выбирается только когда
// `ARBodyTrackingConfiguration.isSupported == true`. На iOS-симуляторе это
// API всегда возвращает false, и нет protocol-seam для инъекции —
// `ARBodyTrackingConfiguration` запрашивается напрямую внутри `startGame`.
// Поэтому body-ветка физически недостижима из юнит-теста на симуляторе.
// Покрыто полностью: face-режим (`startFaceGame`, `updateFrame`,
// blendshapes-classification) и общий `scoreAttempt` (используется обоими режимами).
// Итог по файлу ~41%: 100% testable-логики, остаток — AR-hardware-gated.

@MainActor
final class PoseSequenceInteractorTests: XCTestCase {

    private func makeSUT() -> (PoseSequenceInteractor, SpyPoseSequencePresenter) {
        let sut = PoseSequenceInteractor()
        let spy = SpyPoseSequencePresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    /// Blendshapes, дающие высокий confidence для конкретной позы.
    private func blendshapes(for posture: ArticulationPosture) -> FaceBlendshapes {
        switch posture {
        case .smile:    return FaceBlendshapes(mouthSmileLeft: 1.0, mouthSmileRight: 1.0)
        case .pucker:   return FaceBlendshapes(mouthPucker: 1.0)
        case .cupShape: return FaceBlendshapes(mouthFunnel: 1.0)
        case .mushroom: return FaceBlendshapes(mouthRollLower: 1.0, mouthRollUpper: 1.0)
        default:        return FaceBlendshapes()
        }
    }

    // MARK: - startGame (face mode)

    func test_startGame_withPostures_faceMode() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(postures: [.smile, .pucker]))
        XCTAssertEqual(spy.startGameCallCount, 1)
        XCTAssertEqual(spy.lastStartGame?.mode, .face)
        XCTAssertEqual(spy.lastStartGame?.postures, [.smile, .pucker])
        XCTAssertEqual(spy.lastStartGame?.currentIndex, 0)
        XCTAssertTrue(spy.lastStartGame?.targetPoses.isEmpty ?? false)
    }

    func test_startGame_emptyPostures_usesFaceDefaultsOnSimulator() {
        // На симуляторе ARBodyTrackingConfiguration не поддержан → face-режим
        // с дефолтным набором из 4 поз.
        let (sut, spy) = makeSUT()
        sut.startGame(.init(postures: []))
        XCTAssertEqual(spy.startGameCallCount, 1)
        if spy.lastStartGame?.mode == .face {
            XCTAssertEqual(spy.lastStartGame?.postures.count, 4)
        } else {
            // На реальном устройстве с body tracking — body-режим
            XCTAssertEqual(spy.lastStartGame?.mode, .body)
        }
    }

    // MARK: - updateFrame (face mode)

    func test_updateFrame_lowConfidence_doesNotAdvance() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(postures: [.smile, .pucker]))
        sut.updateFrame(.init(blendshapes: FaceBlendshapes()))
        XCTAssertEqual(spy.lastUpdateFrame?.advanced, false)
        XCTAssertEqual(spy.lastUpdateFrame?.currentIndex, 0)
    }

    func test_updateFrame_holdPosture_advancesAfterRequiredFrames() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(postures: [.smile, .pucker]))
        // holdFramesRequired == 20: нужно 20 кадров уверенной позы
        for _ in 0..<20 {
            sut.updateFrame(.init(blendshapes: blendshapes(for: .smile)))
        }
        XCTAssertEqual(spy.lastUpdateFrame?.advanced, true)
        XCTAssertEqual(spy.lastUpdateFrame?.currentIndex, 1)
    }

    func test_updateFrame_confidenceReported() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(postures: [.smile]))
        sut.updateFrame(.init(blendshapes: blendshapes(for: .smile)))
        XCTAssertGreaterThan(spy.lastUpdateFrame?.confidence ?? 0, 0.6)
    }

    func test_updateFrame_completingAllPostures_triggersScore() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(postures: [.smile]))
        // Одна поза: 20 кадров удержания завершают игру
        for _ in 0..<20 {
            sut.updateFrame(.init(blendshapes: blendshapes(for: .smile)))
        }
        XCTAssertEqual(spy.scoreCallCount, 1)
        XCTAssertEqual(spy.lastScore?.stars, 3, "Все позы завершены → 3 звезды")
    }

    func test_updateFrame_afterAllComplete_ignored() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(postures: [.smile]))
        for _ in 0..<20 {
            sut.updateFrame(.init(blendshapes: blendshapes(for: .smile)))
        }
        let countAfterComplete = spy.updateFrameCallCount
        sut.updateFrame(.init(blendshapes: blendshapes(for: .smile)))
        XCTAssertEqual(spy.updateFrameCallCount, countAfterComplete, "Кадры после завершения игнорируются")
    }

    func test_updateFrame_lowConfidenceDecrementsHold() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(postures: [.smile, .pucker]))
        // 10 кадров удержания, затем 15 без позы — счётчик должен упасть
        for _ in 0..<10 { sut.updateFrame(.init(blendshapes: blendshapes(for: .smile))) }
        for _ in 0..<15 { sut.updateFrame(.init(blendshapes: FaceBlendshapes())) }
        XCTAssertEqual(spy.lastUpdateFrame?.currentIndex, 0, "Поза не должна быть засчитана при сбросе")
        XCTAssertEqual(spy.lastUpdateFrame?.advanced, false)
    }

    func test_updateBodyPose_inFaceMode_ignored() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(postures: [.smile]))
        let update = BodyPoseUpdate(joints: [:], confidence: 1.0)
        sut.updateBodyPose(.init(update: update))
        XCTAssertEqual(spy.updateBodyPoseCallCount, 0, "В face-режиме body-обновления игнорируются")
    }

    // MARK: - scoreAttempt

    func test_scoreAttempt_allCompleted_threeStars() {
        let (sut, spy) = makeSUT()
        sut.scoreAttempt(.init(completedCount: 4, totalCount: 4))
        XCTAssertEqual(spy.lastScore?.stars, 3)
    }

    func test_scoreAttempt_mostCompleted_twoStars() {
        let (sut, spy) = makeSUT()
        sut.scoreAttempt(.init(completedCount: 3, totalCount: 4))
        XCTAssertEqual(spy.lastScore?.stars, 2)
    }

    func test_scoreAttempt_fewCompleted_oneStar() {
        let (sut, spy) = makeSUT()
        sut.scoreAttempt(.init(completedCount: 1, totalCount: 4))
        XCTAssertEqual(spy.lastScore?.stars, 1)
    }

    func test_scoreAttempt_zeroTotal_noCrash() {
        let (sut, spy) = makeSUT()
        sut.scoreAttempt(.init(completedCount: 0, totalCount: 0))
        XCTAssertEqual(spy.scoreCallCount, 1)
        XCTAssertEqual(spy.lastScore?.stars, 1)
    }

    func test_scoreAttempt_exactly70Percent_twoStars() {
        let (sut, spy) = makeSUT()
        sut.scoreAttempt(.init(completedCount: 7, totalCount: 10))
        XCTAssertEqual(spy.lastScore?.stars, 2)
    }

    // MARK: - TargetPosesRepository

    func test_targetPosesRepository_hasFivePoses() {
        XCTAssertEqual(TargetPosesRepository.allPoses.count, 5)
        XCTAssertTrue(TargetPosesRepository.allPoses.allSatisfy { !$0.name.isEmpty })
        XCTAssertTrue(TargetPosesRepository.allPoses.allSatisfy { !$0.jointTargets.isEmpty })
    }

    // MARK: - Batch 4 v25: дополнительное покрытие

    func test_updateFrame_withoutStart_ignored() {
        // mode по умолчанию .face, postures пуст → guard currentIndex < postures.count
        let (sut, spy) = makeSUT()
        sut.updateFrame(.init(blendshapes: blendshapes(for: .smile)))
        XCTAssertEqual(spy.updateFrameCallCount, 0, "Без startGame кадры игнорируются")
    }

    func test_scoreAttempt_boundary90_twoStars() {
        // ratio 0.9 → >= 0.7 но < 1 → 2 звезды
        let (sut, spy) = makeSUT()
        sut.scoreAttempt(.init(completedCount: 9, totalCount: 10))
        XCTAssertEqual(spy.lastScore?.stars, 2)
    }

    func test_scoreAttempt_belowThreshold_oneStar() {
        let (sut, spy) = makeSUT()
        sut.scoreAttempt(.init(completedCount: 2, totalCount: 10))
        XCTAssertEqual(spy.lastScore?.stars, 1)
    }

    func test_updateFrame_multipleConfidentFrames_accumulatesHold() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(postures: [.smile, .pucker]))
        // 19 кадров — ещё не достигнут holdFramesRequired (20)
        for _ in 0..<19 {
            sut.updateFrame(.init(blendshapes: blendshapes(for: .smile)))
        }
        XCTAssertEqual(spy.lastUpdateFrame?.advanced, false)
        XCTAssertEqual(spy.lastUpdateFrame?.currentIndex, 0)
    }

    func test_startGame_customPostures_preservedOrder() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(postures: [.mushroom, .pucker, .smile]))
        XCTAssertEqual(spy.lastStartGame?.postures, [.mushroom, .pucker, .smile])
    }

    // MARK: - Batch 2.6a v25: face-mode hold dynamics + edge cases

    func test_updateFrame_holdThenDecrementThenRebuild_advances() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(postures: [.smile]))
        // Накапливаем 15 кадров, сбрасываем 5, добиваем 20+.
        for _ in 0..<15 { sut.updateFrame(.init(blendshapes: blendshapes(for: .smile))) }
        for _ in 0..<5 { sut.updateFrame(.init(blendshapes: FaceBlendshapes())) }
        for _ in 0..<25 { sut.updateFrame(.init(blendshapes: blendshapes(for: .smile))) }
        XCTAssertEqual(spy.lastUpdateFrame?.advanced, true)
        XCTAssertEqual(spy.scoreCallCount, 1)
    }

    func test_updateFrame_wrongPostureBlendshapes_lowConfidence() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(postures: [.pucker]))
        // Подаём улыбку, ожидаем pucker → confidence низкая.
        for _ in 0..<10 { sut.updateFrame(.init(blendshapes: blendshapes(for: .smile))) }
        XCTAssertEqual(spy.lastUpdateFrame?.currentIndex, 0)
        XCTAssertEqual(spy.lastUpdateFrame?.advanced, false)
    }

    func test_updateFrame_allFourDefaultPostures_completeGame() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(postures: [.smile, .pucker, .cupShape, .mushroom]))
        let order: [ArticulationPosture] = [.smile, .pucker, .cupShape, .mushroom]
        for posture in order {
            for _ in 0..<20 {
                sut.updateFrame(.init(blendshapes: blendshapes(for: posture)))
            }
        }
        XCTAssertEqual(spy.scoreCallCount, 1)
        XCTAssertEqual(spy.lastScore?.stars, 3)
    }

    func test_updateBodyPose_withoutStart_ignored() {
        let (sut, spy) = makeSUT()
        let update = BodyPoseUpdate(joints: [:], confidence: 1.0)
        sut.updateBodyPose(.init(update: update))
        XCTAssertEqual(spy.updateBodyPoseCallCount, 0)
    }

    func test_scoreAttempt_completedExceedsTotal_clampedToThreeStars() {
        let (sut, spy) = makeSUT()
        sut.scoreAttempt(.init(completedCount: 10, totalCount: 5))
        // ratio = 2.0 ≥ 1 → 3 звезды.
        XCTAssertEqual(spy.lastScore?.stars, 3)
    }

    func test_startGame_emptyPosturesOnSimulator_fourFaceDefaults() {
        // На симуляторе ARBodyTrackingConfiguration.isSupported == false →
        // face-режим с 4 дефолтными позами.
        let (sut, spy) = makeSUT()
        sut.startGame(.init(postures: []))
        if spy.lastStartGame?.mode == .face {
            XCTAssertEqual(spy.lastStartGame?.postures.count, 4)
            XCTAssertEqual(spy.lastStartGame?.postures, [.smile, .pucker, .cupShape, .mushroom])
        }
    }

    func test_updateFrame_singlePosture_partialHold_noScore() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(postures: [.smile]))
        for _ in 0..<10 { sut.updateFrame(.init(blendshapes: blendshapes(for: .smile))) }
        XCTAssertEqual(spy.scoreCallCount, 0, "Незавершённое удержание не вызывает scoreAttempt")
    }

    // MARK: - Batch 2.6a v25: body-режим через инъекцию bodyTrackingSupported
    //
    // На симуляторе ARBodyTrackingConfiguration.isSupported == false. С новым
    // inject-seam `bodyTrackingSupported` body-ветка становится тестируемой —
    // покрываются startBodyGame, updateBodyPose (async-closure с
    // PoseSimilarityWorker) и body-mode guard-ы.

    private func makeBodySUT() -> (PoseSequenceInteractor, SpyPoseSequencePresenter) {
        let sut = PoseSequenceInteractor(bodyTrackingSupported: true)
        let spy = SpyPoseSequencePresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    func test_startGame_bodyTrackingSupported_emptyPostures_startsBodyMode() {
        let (sut, spy) = makeBodySUT()
        sut.startGame(.init(postures: []))
        XCTAssertEqual(spy.startGameCallCount, 1)
        XCTAssertEqual(spy.lastStartGame?.mode, .body)
        XCTAssertEqual(spy.lastStartGame?.targetPoses.count, TargetPosesRepository.allPoses.count)
        XCTAssertTrue(spy.lastStartGame?.postures.isEmpty ?? false)
        XCTAssertEqual(spy.lastStartGame?.currentIndex, 0)
    }

    func test_startGame_bodyTrackingSupported_withPostures_usesFaceMode() {
        // Непустой набор поз → face-режим даже при поддержке body tracking.
        let (sut, spy) = makeBodySUT()
        sut.startGame(.init(postures: [.smile, .pucker]))
        XCTAssertEqual(spy.lastStartGame?.mode, .face)
    }

    func test_updateBodyPose_inBodyMode_emitsResponse() async {
        let (sut, spy) = makeBodySUT()
        sut.startGame(.init(postures: []))
        let target = TargetPosesRepository.allPoses[0]
        // Подаём суставы, точно совпадающие с эталоном → высокий score.
        let update = BodyPoseUpdate(joints: target.jointTargets, confidence: 1.0)
        sut.updateBodyPose(.init(update: update))
        // updateBodyPose запускает async-задачу со scoring — ждём её.
        try? await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(spy.updateBodyPoseCallCount, 1)
        XCTAssertGreaterThan(spy.lastUpdateBodyPose?.score ?? -1, 0)
    }

    func test_updateBodyPose_perfectMatch_advancesAfterHold() async {
        let (sut, spy) = makeBodySUT()
        sut.startGame(.init(postures: []))
        let target = TargetPosesRepository.allPoses[0]
        let update = BodyPoseUpdate(joints: target.jointTargets, confidence: 1.0)
        // bodyHoldFramesRequired == 20: подаём 25 идеальных кадров.
        for _ in 0..<25 {
            sut.updateBodyPose(.init(update: update))
            try? await Task.sleep(for: .milliseconds(8))
        }
        try? await Task.sleep(for: .milliseconds(120))
        XCTAssertGreaterThanOrEqual(spy.lastUpdateBodyPose?.currentIndex ?? 0, 1,
                                    "Удержание идеальной позы продвигает индекс")
    }

    func test_updateBodyPose_lowScore_doesNotAdvance() async {
        let (sut, spy) = makeBodySUT()
        sut.startGame(.init(postures: []))
        // Пустые суставы → score 0 → не продвигается.
        let update = BodyPoseUpdate(joints: [:], confidence: 1.0)
        for _ in 0..<10 {
            sut.updateBodyPose(.init(update: update))
            try? await Task.sleep(for: .milliseconds(8))
        }
        try? await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(spy.lastUpdateBodyPose?.currentIndex, 0)
        XCTAssertEqual(spy.lastUpdateBodyPose?.advanced, false)
    }

    func test_updateBodyPose_providesHintForCurrentPose() async {
        let (sut, spy) = makeBodySUT()
        sut.startGame(.init(postures: []))
        let target = TargetPosesRepository.allPoses[0]
        let update = BodyPoseUpdate(joints: target.jointTargets, confidence: 1.0)
        sut.updateBodyPose(.init(update: update))
        try? await Task.sleep(for: .milliseconds(120))
        XCTAssertFalse(spy.lastUpdateBodyPose?.currentHint.isEmpty ?? true,
                       "Body-режим отдаёт подсказку для текущей позы")
    }

    func test_updateBodyPose_completingAllPoses_triggersScore() async {
        let (sut, spy) = makeBodySUT()
        sut.startGame(.init(postures: []))
        // Прогоняем все позы: для каждой удерживаем идеальный матч.
        for index in 0..<TargetPosesRepository.allPoses.count {
            let target = TargetPosesRepository.allPoses[index]
            let update = BodyPoseUpdate(joints: target.jointTargets, confidence: 1.0)
            for _ in 0..<25 {
                sut.updateBodyPose(.init(update: update))
                try? await Task.sleep(for: .milliseconds(6))
            }
        }
        try? await Task.sleep(for: .milliseconds(200))
        XCTAssertGreaterThanOrEqual(spy.scoreCallCount, 1,
                                    "Завершение всех body-поз вызывает scoreAttempt")
    }

    func test_updateFrame_inBodyMode_ignored() async {
        let (sut, spy) = makeBodySUT()
        sut.startGame(.init(postures: []))
        // В body-режиме face-обновления игнорируются.
        sut.updateFrame(.init(blendshapes: blendshapes(for: .smile)))
        XCTAssertEqual(spy.updateFrameCallCount, 0)
    }
}
