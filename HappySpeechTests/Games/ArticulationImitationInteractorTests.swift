@testable import HappySpeech
import XCTest

// MARK: - Spy Presenter

@MainActor
private final class SpyArticulationPresenter: ArticulationImitationPresentationLogic {

    var loadSessionCount = 0
    var startPoseCount = 0
    var beginMirroringCount = 0
    var blendshapeUpdateCount = 0
    var confirmPoseCount = 0
    var hintCount = 0
    var parentConfirmCount = 0
    var sessionCompleteCount = 0
    var startExerciseCount = 0
    var holdProgressCount = 0
    var completeExerciseCount = 0

    var lastLoadSession: ArticulationImitationModels.LoadSession.Response?
    var lastStartPose: ArticulationImitationModels.StartPose.Response?
    var lastBeginMirroringMode: MirroringMode?
    var lastBlendshapeUpdate: ArticulationImitationModels.BlendshapeUpdate.Response?
    var lastConfirmPose: ArticulationImitationModels.ConfirmPose.Response?
    var lastHint: ArticulationImitationModels.RequestHint.Response?
    var lastParentConfirmPose: ArticulationPose?
    var lastSessionComplete: ArticulationImitationModels.SessionComplete.Response?
    var lastHoldProgress: ArticulationImitationModels.HoldProgress.Response?
    var lastCompleteExercise: ArticulationImitationModels.CompleteExercise.Response?

    func presentLoadSession(_ response: ArticulationImitationModels.LoadSession.Response) {
        loadSessionCount += 1
        lastLoadSession = response
    }
    func presentStartPose(_ response: ArticulationImitationModels.StartPose.Response) {
        startPoseCount += 1
        lastStartPose = response
    }
    func presentBeginMirroring(_ mode: MirroringMode) {
        beginMirroringCount += 1
        lastBeginMirroringMode = mode
    }
    func presentBlendshapeUpdate(_ response: ArticulationImitationModels.BlendshapeUpdate.Response) {
        blendshapeUpdateCount += 1
        lastBlendshapeUpdate = response
    }
    func presentConfirmPose(_ response: ArticulationImitationModels.ConfirmPose.Response) {
        confirmPoseCount += 1
        lastConfirmPose = response
    }
    func presentHint(_ response: ArticulationImitationModels.RequestHint.Response) {
        hintCount += 1
        lastHint = response
    }
    func presentParentConfirmRequest(_ pose: ArticulationPose) {
        parentConfirmCount += 1
        lastParentConfirmPose = pose
    }
    func presentSessionComplete(_ response: ArticulationImitationModels.SessionComplete.Response) {
        sessionCompleteCount += 1
        lastSessionComplete = response
    }
    func presentStartExercise(_ response: ArticulationImitationModels.StartExercise.Response) {
        startExerciseCount += 1
    }
    func presentHoldProgress(_ response: ArticulationImitationModels.HoldProgress.Response) {
        holdProgressCount += 1
        lastHoldProgress = response
    }
    func presentCompleteExercise(_ response: ArticulationImitationModels.CompleteExercise.Response) {
        completeExerciseCount += 1
        lastCompleteExercise = response
    }
}

// MARK: - Tests

@MainActor
final class ArticulationImitationInteractorTests: XCTestCase {

    private func makeSUT() -> (ArticulationImitationInteractor, SpyArticulationPresenter) {
        let sut = ArticulationImitationInteractor()
        let spy = SpyArticulationPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    /// Blendshape Request с полным открытием рта (jawOpen) — подходит для позы "А".
    private func wideOpenFrame() -> ArticulationImitationModels.BlendshapeUpdate.Request {
        ArticulationImitationModels.BlendshapeUpdate.Request(
            jawOpen: 0.9, jawForward: 0, mouthFunnel: 0, mouthPucker: 0,
            mouthSmileLeft: 0, mouthSmileRight: 0, mouthFrownLeft: 0, mouthFrownRight: 0,
            mouthRollLower: 0, mouthRollUpper: 0, mouthStretchLeft: 0, mouthStretchRight: 0,
            mouthLowerDownLeft: 0, mouthLowerDownRight: 0, mouthUpperUpLeft: 0, mouthUpperUpRight: 0,
            mouthClose: 0, tongueOut: 0
        )
    }

    private func zeroFrame() -> ArticulationImitationModels.BlendshapeUpdate.Request {
        ArticulationImitationModels.BlendshapeUpdate.Request(
            jawOpen: 0, jawForward: 0, mouthFunnel: 0, mouthPucker: 0,
            mouthSmileLeft: 0, mouthSmileRight: 0, mouthFrownLeft: 0, mouthFrownRight: 0,
            mouthRollLower: 0, mouthRollUpper: 0, mouthStretchLeft: 0, mouthStretchRight: 0,
            mouthLowerDownLeft: 0, mouthLowerDownRight: 0, mouthUpperUpLeft: 0, mouthUpperUpRight: 0,
            mouthClose: 0, tongueOut: 0
        )
    }

    /// На симуляторе ARFaceTracking недоступен → каталог отсортирован по id, "pose_a" первый.
    private func indexOfPoseA(in poses: [ArticulationPose]) -> Int? {
        poses.firstIndex(where: { $0.id == "pose_a" })
    }

    // MARK: - loadSession

    func test_loadSession_loadsTwelvePoses() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "any", childName: "Маша"))
        XCTAssertEqual(spy.loadSessionCount, 1)
        XCTAssertEqual(spy.lastLoadSession?.poses.count, 12)
        XCTAssertEqual(spy.lastLoadSession?.childName, "Маша")
    }

    func test_loadSession_simulatorUsesFallback2D() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "any", childName: "Ваня"))
        // На симуляторе ARFaceTracking недоступен.
        XCTAssertEqual(spy.lastLoadSession?.mirroringMode, .fallback2D)
        XCTAssertEqual(sut.mirroringMode, .fallback2D)
    }

    func test_loadSession_resetsState() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "any", childName: "Маша"))
        sut.completeExercise(.init(exerciseId: "x", held: true))
        sut.loadSession(.init(soundGroup: "any", childName: "Маша"))
        XCTAssertEqual(sut.starsEarned, 0)
        XCTAssertEqual(sut.currentPoseIndex, 0)
        XCTAssertTrue(sut.perPoseRecords.isEmpty)
        _ = spy
    }

    func test_loadSession_filtersBySoundGroup() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: SoundFamily.whistling.rawValue, childName: "Маша"))
        let poses = spy.lastLoadSession?.poses ?? []
        XCTAssertFalse(poses.isEmpty)
        // Все позы из пула свистящих звуков.
        let allowed: Set<String> = ["С", "З", "Ц", "И", "Э", "Ы"]
        XCTAssertTrue(poses.allSatisfy { allowed.contains($0.targetSound) })
    }

    // MARK: - startPose

    func test_startPose_presentsPose() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "any", childName: "Маша"))
        sut.startPose(.init(poseIndex: 0))
        XCTAssertEqual(spy.startPoseCount, 1)
        XCTAssertEqual(spy.lastStartPose?.poseNumber, 1)
        XCTAssertEqual(spy.lastStartPose?.total, 12)
        XCTAssertEqual(spy.lastStartPose?.attemptNumber, 1)
    }

    func test_startPose_clampsOutOfBoundsIndex() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "any", childName: "Маша"))
        sut.startPose(.init(poseIndex: 999))
        // Индекс зажимается до последней позы.
        XCTAssertEqual(sut.currentPoseIndex, 11)
        XCTAssertEqual(spy.lastStartPose?.poseNumber, 12)
    }

    func test_startPose_negativeIndexClampedToZero() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "any", childName: "Маша"))
        sut.startPose(.init(poseIndex: -5))
        XCTAssertEqual(sut.currentPoseIndex, 0)
        XCTAssertEqual(spy.lastStartPose?.poseNumber, 1)
    }

    func test_startPose_withoutLoadDoesNotCrash() {
        let (sut, spy) = makeSUT()
        sut.startPose(.init(poseIndex: 0))
        XCTAssertEqual(spy.startPoseCount, 0)
    }

    // MARK: - beginMirroring

    func test_beginMirroring_incrementsAttempt() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "any", childName: "Маша"))
        sut.startPose(.init(poseIndex: 0))
        sut.beginMirroring()
        XCTAssertEqual(spy.beginMirroringCount, 1)
        XCTAssertEqual(spy.lastBeginMirroringMode, .fallback2D)
    }

    func test_beginMirroring_withoutPosesIsSafe() {
        let (sut, spy) = makeSUT()
        sut.beginMirroring()
        XCTAssertEqual(spy.beginMirroringCount, 0)
    }

    // MARK: - processBlendshapeFrame

    func test_processBlendshapeFrame_emitsUpdate() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "any", childName: "Маша"))
        guard let aIndex = indexOfPoseA(in: spy.lastLoadSession?.poses ?? []) else {
            return XCTFail("pose_a not found")
        }
        sut.startPose(.init(poseIndex: aIndex))
        sut.beginMirroring()
        sut.processBlendshapeFrame(wideOpenFrame())
        XCTAssertEqual(spy.blendshapeUpdateCount, 1)
        XCTAssertNotNil(spy.lastBlendshapeUpdate)
    }

    func test_processBlendshapeFrame_throttlesRapidFrames() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "any", childName: "Маша"))
        sut.startPose(.init(poseIndex: 0))
        sut.beginMirroring()
        // Два кадра подряд: второй отсекается throttle 50ms.
        sut.processBlendshapeFrame(zeroFrame())
        sut.processBlendshapeFrame(zeroFrame())
        XCTAssertEqual(spy.blendshapeUpdateCount, 1)
    }

    func test_processBlendshapeFrame_highScoreTriggersAutoConfirm() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "any", childName: "Маша"))
        guard let aIndex = indexOfPoseA(in: spy.lastLoadSession?.poses ?? []) else {
            return XCTFail("pose_a not found")
        }
        sut.startPose(.init(poseIndex: aIndex))
        sut.beginMirroring()
        sut.processBlendshapeFrame(wideOpenFrame())
        // Высокий score для позы "А" → автоподтверждение.
        XCTAssertEqual(spy.confirmPoseCount, 1)
        XCTAssertEqual(spy.lastConfirmPose?.passed, true)
        XCTAssertEqual(sut.starsEarned, 1)
    }

    func test_processBlendshapeFrame_withoutPosesIsSafe() {
        let (sut, spy) = makeSUT()
        sut.processBlendshapeFrame(zeroFrame())
        XCTAssertEqual(spy.blendshapeUpdateCount, 0)
    }

    func test_processBlendshapeFrame_lowScoreNoAutoConfirm() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "any", childName: "Маша"))
        guard let aIndex = indexOfPoseA(in: spy.lastLoadSession?.poses ?? []) else {
            return XCTFail("pose_a not found")
        }
        sut.startPose(.init(poseIndex: aIndex))
        sut.beginMirroring()
        sut.processBlendshapeFrame(zeroFrame())
        // Закрытый рот — низкий score для позы "А", автоподтверждение не срабатывает.
        XCTAssertEqual(spy.confirmPoseCount, 0)
    }

    // MARK: - confirmPose

    func test_confirmPose_byParentPassesPose() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "any", childName: "Маша"))
        sut.startPose(.init(poseIndex: 0))
        sut.beginMirroring()
        let poseId = spy.lastStartPose?.pose.id ?? ""
        sut.confirmPose(.init(poseId: poseId, confirmedByParent: true))
        XCTAssertEqual(spy.lastConfirmPose?.passed, true)
        XCTAssertEqual(sut.starsEarned, 1)
        XCTAssertEqual(sut.perPoseRecords.count, 1)
    }

    func test_confirmPose_lowScoreNotConfirmedByParentFails() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "any", childName: "Маша"))
        sut.startPose(.init(poseIndex: 0))
        sut.beginMirroring()
        let poseId = spy.lastStartPose?.pose.id ?? ""
        sut.confirmPose(.init(poseId: poseId, confirmedByParent: false))
        XCTAssertEqual(spy.lastConfirmPose?.passed, false)
        XCTAssertEqual(sut.starsEarned, 0)
    }

    func test_confirmPose_nextIndexNilOnLastPose() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "any", childName: "Маша"))
        sut.startPose(.init(poseIndex: 11))
        sut.beginMirroring()
        let poseId = spy.lastStartPose?.pose.id ?? ""
        sut.confirmPose(.init(poseId: poseId, confirmedByParent: true))
        XCTAssertNil(spy.lastConfirmPose?.nextPoseIndex)
        XCTAssertEqual(spy.lastConfirmPose?.allDone, true)
    }

    func test_confirmPose_nextIndexAdvancesMidSession() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "any", childName: "Маша"))
        sut.startPose(.init(poseIndex: 3))
        sut.beginMirroring()
        let poseId = spy.lastStartPose?.pose.id ?? ""
        sut.confirmPose(.init(poseId: poseId, confirmedByParent: true))
        XCTAssertEqual(spy.lastConfirmPose?.nextPoseIndex, 4)
        XCTAssertEqual(spy.lastConfirmPose?.allDone, false)
    }

    // MARK: - requestHint

    func test_requestHint_firstLevel() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "any", childName: "Маша"))
        sut.startPose(.init(poseIndex: 0))
        let poseId = spy.lastStartPose?.pose.id ?? ""
        sut.requestHint(.init(poseId: poseId))
        XCTAssertEqual(spy.hintCount, 1)
        XCTAssertEqual(spy.lastHint?.hintLevel, 0)
        XCTAssertEqual(spy.lastHint?.attemptsLeft, 3)
    }

    func test_requestHint_secondLevelAfterAttempts() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "any", childName: "Маша"))
        sut.startPose(.init(poseIndex: 0))
        sut.beginMirroring()
        let poseId = spy.lastStartPose?.pose.id ?? ""
        sut.requestHint(.init(poseId: poseId))
        XCTAssertEqual(spy.lastHint?.hintLevel, 1)
        XCTAssertEqual(spy.lastHint?.attemptsLeft, 2)
    }

    func test_requestHint_exhaustedAttemptsForcesAdvance() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "any", childName: "Маша"))
        sut.startPose(.init(poseIndex: 0))
        let poseId = spy.lastStartPose?.pose.id ?? ""
        // 3 попытки.
        sut.beginMirroring()
        sut.beginMirroring()
        sut.beginMirroring()
        sut.requestHint(.init(poseId: poseId))
        XCTAssertEqual(spy.lastHint?.attemptsLeft, 0)
        // Принудительное продвижение → confirmPose response с passed=false.
        XCTAssertGreaterThanOrEqual(spy.confirmPoseCount, 1)
        XCTAssertEqual(spy.lastConfirmPose?.passed, false)
        XCTAssertEqual(sut.perPoseRecords.count, 1)
    }

    func test_requestHint_withoutPosesIsSafe() {
        let (sut, spy) = makeSUT()
        sut.requestHint(.init(poseId: "x"))
        XCTAssertEqual(spy.hintCount, 0)
    }

    // MARK: - completeSession

    func test_completeSession_emitsSummary() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "any", childName: "Маша"))
        sut.startPose(.init(poseIndex: 0))
        sut.beginMirroring()
        let poseId = spy.lastStartPose?.pose.id ?? ""
        sut.confirmPose(.init(poseId: poseId, confirmedByParent: true))
        sut.completeSession()
        XCTAssertEqual(spy.sessionCompleteCount, 1)
        XCTAssertEqual(spy.lastSessionComplete?.starsTotal, 1)
        XCTAssertEqual(spy.lastSessionComplete?.outOf, 12)
        XCTAssertEqual(spy.lastSessionComplete?.perPoseRecords.count, 1)
    }

    func test_completeSession_emptySessionOutOfIsAtLeastOne() {
        let (sut, spy) = makeSUT()
        sut.completeSession()
        XCTAssertEqual(spy.lastSessionComplete?.outOf, 1)
        XCTAssertEqual(spy.lastSessionComplete?.starsTotal, 0)
    }

    // MARK: - cancel

    func test_cancel_isSafe() {
        let (sut, _) = makeSUT()
        sut.loadSession(.init(soundGroup: "any", childName: "Маша"))
        sut.startPose(.init(poseIndex: 0))
        sut.cancel()
        XCTAssertEqual(sut.currentPoseIndex, 0)
    }

    // MARK: - Legacy API

    func test_startExercise_delegatesToStartPose() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "any", childName: "Маша"))
        sut.startExercise(.init(exerciseIndex: 2))
        XCTAssertEqual(spy.startPoseCount, 1)
        XCTAssertEqual(sut.currentPoseIndex, 2)
    }

    func test_completeExercise_heldEarnsStar() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "any", childName: "Маша"))
        sut.startPose(.init(poseIndex: 0))
        sut.completeExercise(.init(exerciseId: "pose_a", held: true))
        XCTAssertEqual(spy.completeExerciseCount, 1)
        XCTAssertEqual(spy.lastCompleteExercise?.earnedStar, true)
        XCTAssertEqual(sut.starsEarned, 1)
    }

    func test_completeExercise_notHeldNoStar() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "any", childName: "Маша"))
        sut.startPose(.init(poseIndex: 0))
        sut.completeExercise(.init(exerciseId: "pose_a", held: false))
        XCTAssertEqual(spy.lastCompleteExercise?.earnedStar, false)
        XCTAssertEqual(sut.starsEarned, 0)
    }

    func test_beginHold_completesAndAwardsStar() async {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "any", childName: "Маша"))
        sut.startPose(.init(poseIndex: 0))
        sut.beginHold()
        // Hold-таск идёт ~3 сек (30 тиков по 0.1 с + накладные расходы планировщика).
        // Опрашиваем результат вместо фиксированного sleep — устраняет флейки
        // при медленном симуляторе, не ослабляя проверку.
        for _ in 0..<60 where spy.completeExerciseCount == 0 {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        XCTAssertGreaterThanOrEqual(spy.holdProgressCount, 1)
        XCTAssertEqual(spy.completeExerciseCount, 1)
        XCTAssertEqual(spy.lastCompleteExercise?.earnedStar, true)
    }

    func test_beginHold_withoutPosesIsSafe() {
        let (sut, spy) = makeSUT()
        sut.beginHold()
        XCTAssertEqual(spy.beginMirroringCount, 0)
    }

    // MARK: - ArticulationPose catalog

    func test_posesCatalog_hasTwelveEntries() {
        XCTAssertEqual(ArticulationPose.catalog.count, 12)
    }

    func test_poses_forUnknownGroupReturnsFullCatalog() {
        let poses = ArticulationPose.poses(for: "unknown_group")
        XCTAssertEqual(poses.count, 12)
    }

    func test_poses_respectsCountLimit() {
        let poses = ArticulationPose.poses(for: "any", count: 5)
        XCTAssertEqual(poses.count, 5)
    }

    func test_poses_sonorantGroupFiltered() {
        let poses = ArticulationPose.poses(for: SoundFamily.sonorant.rawValue)
        let allowed: Set<String> = ["Р", "Л", "А", "М"]
        XCTAssertTrue(poses.allSatisfy { allowed.contains($0.targetSound) })
    }

    // MARK: - ARCapabilityChecker

    func test_arCapabilityChecker_simulatorReturnsFalse() {
        XCTAssertFalse(ARCapabilityChecker.isFaceTrackingSupported)
    }
}
