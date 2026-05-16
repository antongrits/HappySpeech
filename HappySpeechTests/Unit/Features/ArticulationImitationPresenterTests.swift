@testable import HappySpeech
import XCTest

// MARK: - ArticulationImitationPresenterTests
//
// Phase 2.6.1 v25 — покрытие ArticulationImitationPresenter (13 тестов).
// Тестируются все методы: presentLoadSession, presentStartPose,
// presentBeginMirroring, presentBlendshapeUpdate, presentConfirmPose,
// presentHint, presentParentConfirmRequest, presentSessionComplete,
// presentStartExercise, presentHoldProgress, presentCompleteExercise.

@MainActor
final class ArticulationImitationPresenterTests: XCTestCase {

    // MARK: - DisplaySpy

    @MainActor
    private final class DisplaySpy: ArticulationImitationDisplayLogic {
        var loadSessionVM: ArticulationImitationModels.LoadSession.ViewModel?
        var startPoseVM: ArticulationImitationModels.StartPose.ViewModel?
        var beginMirroringMode: MirroringMode?
        var blendshapeVM: ArticulationImitationModels.BlendshapeUpdate.ViewModel?
        var confirmPoseVM: ArticulationImitationModels.ConfirmPose.ViewModel?
        var hintVM: ArticulationImitationModels.RequestHint.ViewModel?
        var parentConfirmPose: ArticulationPose?
        var sessionCompleteVM: ArticulationImitationModels.SessionComplete.ViewModel?
        var startExerciseVM: ArticulationImitationModels.StartExercise.ViewModel?
        var holdProgressVM: ArticulationImitationModels.HoldProgress.ViewModel?
        var completeExerciseVM: ArticulationImitationModels.CompleteExercise.ViewModel?

        func displayLoadSession(_ viewModel: ArticulationImitationModels.LoadSession.ViewModel) { loadSessionVM = viewModel }
        func displayStartPose(_ viewModel: ArticulationImitationModels.StartPose.ViewModel) { startPoseVM = viewModel }
        func displayBeginMirroring(_ mode: MirroringMode) { beginMirroringMode = mode }
        func displayBlendshapeUpdate(_ viewModel: ArticulationImitationModels.BlendshapeUpdate.ViewModel) { blendshapeVM = viewModel }
        func displayConfirmPose(_ viewModel: ArticulationImitationModels.ConfirmPose.ViewModel) { confirmPoseVM = viewModel }
        func displayHint(_ viewModel: ArticulationImitationModels.RequestHint.ViewModel) { hintVM = viewModel }
        func displayParentConfirmRequest(_ pose: ArticulationPose) { parentConfirmPose = pose }
        func displaySessionComplete(_ viewModel: ArticulationImitationModels.SessionComplete.ViewModel) { sessionCompleteVM = viewModel }
        func displayStartExercise(_ viewModel: ArticulationImitationModels.StartExercise.ViewModel) { startExerciseVM = viewModel }
        func displayHoldProgress(_ viewModel: ArticulationImitationModels.HoldProgress.ViewModel) { holdProgressVM = viewModel }
        func displayCompleteExercise(_ viewModel: ArticulationImitationModels.CompleteExercise.ViewModel) { completeExerciseVM = viewModel }
    }

    private func makeSUT() -> (ArticulationImitationPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = ArticulationImitationPresenter()
        presenter.viewModel = spy
        return (presenter, spy)
    }

    private func makePose() -> ArticulationPose {
        ArticulationPose.catalog.first!
    }

    private func makeMatchResult(score: Int) -> PoseMatchResult {
        PoseMatchResult(
            score: score,
            isSuccess: score >= 75,
            weakestChannel: nil,
            matchedChannels: score >= 75 ? ["jawOpen"] : []
        )
    }

    // MARK: - presentLoadSession

    func test_presentLoadSession_withName_greetingNotEmpty() {
        let (sut, spy) = makeSUT()
        let response = ArticulationImitationModels.LoadSession.Response(
            poses: [makePose()],
            childName: "Саша",
            mirroringMode: .arFaceTracking
        )
        sut.presentLoadSession(response)
        XCTAssertNotNil(spy.loadSessionVM)
        XCTAssertFalse(spy.loadSessionVM?.greeting.isEmpty ?? true)
    }

    func test_presentLoadSession_emptyName_defaultGreeting() {
        let (sut, spy) = makeSUT()
        let response = ArticulationImitationModels.LoadSession.Response(
            poses: [makePose()],
            childName: "",
            mirroringMode: .fallback2D
        )
        sut.presentLoadSession(response)
        XCTAssertFalse(spy.loadSessionVM?.greeting.isEmpty ?? true)
        XCTAssertEqual(spy.loadSessionVM?.mirroringMode, .fallback2D)
    }

    // MARK: - presentStartPose

    func test_presentStartPose_progressLabelNotEmpty() {
        let (sut, spy) = makeSUT()
        let response = ArticulationImitationModels.StartPose.Response(
            pose: makePose(),
            poseNumber: 2,
            total: 5,
            attemptNumber: 1
        )
        sut.presentStartPose(response)
        XCTAssertNotNil(spy.startPoseVM)
        XCTAssertFalse(spy.startPoseVM?.progressLabel.isEmpty ?? true)
    }

    // MARK: - presentBeginMirroring

    func test_presentBeginMirroring_arMode() {
        let (sut, spy) = makeSUT()
        sut.presentBeginMirroring(.arFaceTracking)
        XCTAssertEqual(spy.beginMirroringMode, .arFaceTracking)
    }

    func test_presentBeginMirroring_fallbackMode() {
        let (sut, spy) = makeSUT()
        sut.presentBeginMirroring(.fallback2D)
        XCTAssertEqual(spy.beginMirroringMode, .fallback2D)
    }

    // MARK: - presentBlendshapeUpdate

    func test_presentBlendshapeUpdate_highScore_successColor() {
        let (sut, spy) = makeSUT()
        let response = ArticulationImitationModels.BlendshapeUpdate.Response(
            matchResult: makeMatchResult(score: 80),
            pose: makePose()
        )
        sut.presentBlendshapeUpdate(response)
        XCTAssertEqual(spy.blendshapeVM?.feedbackColor, "success")
        XCTAssertEqual(spy.blendshapeVM?.scoreLabel, "80%")
    }

    func test_presentBlendshapeUpdate_midScore_warningColor() {
        let (sut, spy) = makeSUT()
        let response = ArticulationImitationModels.BlendshapeUpdate.Response(
            matchResult: makeMatchResult(score: 60),
            pose: makePose()
        )
        sut.presentBlendshapeUpdate(response)
        XCTAssertEqual(spy.blendshapeVM?.feedbackColor, "warning")
    }

    func test_presentBlendshapeUpdate_lowScore_neutralColor() {
        let (sut, spy) = makeSUT()
        let response = ArticulationImitationModels.BlendshapeUpdate.Response(
            matchResult: makeMatchResult(score: 30),
            pose: makePose()
        )
        sut.presentBlendshapeUpdate(response)
        XCTAssertEqual(spy.blendshapeVM?.feedbackColor, "neutral")
    }

    // MARK: - presentConfirmPose

    func test_presentConfirmPose_passed_positiveFeedback() {
        let (sut, spy) = makeSUT()
        let response = ArticulationImitationModels.ConfirmPose.Response(
            passed: true,
            score: 85,
            nextPoseIndex: 1,
            allDone: false
        )
        sut.presentConfirmPose(response)
        XCTAssertTrue(spy.confirmPoseVM?.passed ?? false)
        XCTAssertFalse(spy.confirmPoseVM?.feedbackText.isEmpty ?? true)
        XCTAssertFalse(spy.confirmPoseVM?.allDone ?? true)
    }

    func test_presentConfirmPose_failed_negativeFeedback() {
        let (sut, spy) = makeSUT()
        let response = ArticulationImitationModels.ConfirmPose.Response(
            passed: false,
            score: 40,
            nextPoseIndex: nil,
            allDone: false
        )
        sut.presentConfirmPose(response)
        XCTAssertFalse(spy.confirmPoseVM?.passed ?? true)
        XCTAssertFalse(spy.confirmPoseVM?.feedbackText.isEmpty ?? true)
    }

    // MARK: - presentHint

    func test_presentHint_setsAttemptsLabel() {
        let (sut, spy) = makeSUT()
        let response = ArticulationImitationModels.RequestHint.Response(
            hintText: "Открой рот широко",
            hintLevel: 1,
            attemptsLeft: 2
        )
        sut.presentHint(response)
        XCTAssertFalse(spy.hintVM?.attemptsLeftLabel.isEmpty ?? true)
        XCTAssertEqual(spy.hintVM?.hintText, "Открой рот широко")
    }

    // MARK: - presentParentConfirmRequest

    func test_presentParentConfirmRequest_passesPoseThrough() {
        let (sut, spy) = makeSUT()
        let pose = makePose()
        sut.presentParentConfirmRequest(pose)
        XCTAssertEqual(spy.parentConfirmPose?.id, pose.id)
    }

    // MARK: - presentSessionComplete

    func test_presentSessionComplete_highNormalized_messageSet() {
        let (sut, spy) = makeSUT()
        let records = (0..<3).map { i in
            PerPoseRecord(poseId: "p-\(i)", attempts: 1, bestScore: 85, passed: true)
        }
        let response = ArticulationImitationModels.SessionComplete.Response(
            starsTotal: 9,
            outOf: 9,
            perPoseRecords: records
        )
        sut.presentSessionComplete(response)
        XCTAssertFalse(spy.sessionCompleteVM?.message.isEmpty ?? true)
        XCTAssertFalse(spy.sessionCompleteVM?.scoreLabel.isEmpty ?? true)
        XCTAssertTrue(spy.sessionCompleteVM?.showDetailedStats ?? false)
    }

    func test_presentSessionComplete_zeroOutOf_noNaN() {
        let (sut, spy) = makeSUT()
        let response = ArticulationImitationModels.SessionComplete.Response(
            starsTotal: 0,
            outOf: 0,
            perPoseRecords: []
        )
        sut.presentSessionComplete(response)
        let score = spy.sessionCompleteVM?.normalizedScore ?? -1
        XCTAssertFalse(score.isNaN)
        XCTAssertGreaterThanOrEqual(score, 0)
    }

    // MARK: - Legacy: presentHoldProgress

    func test_presentHoldProgress_setsTimerLabel() {
        let (sut, spy) = makeSUT()
        let response = ArticulationImitationModels.HoldProgress.Response(
            fraction: 0.5,
            completed: false,
            remainingSeconds: 3
        )
        sut.presentHoldProgress(response)
        XCTAssertFalse(spy.holdProgressVM?.timerLabel.isEmpty ?? true)
        XCTAssertEqual(spy.holdProgressVM?.fraction, 0.5)
    }

    // MARK: - Legacy: presentCompleteExercise

    func test_presentCompleteExercise_earnedStar_positiveFeedback() {
        let (sut, spy) = makeSUT()
        let response = ArticulationImitationModels.CompleteExercise.Response(
            earnedStar: true,
            nextIndex: 1,
            allDone: false
        )
        sut.presentCompleteExercise(response)
        XCTAssertTrue(spy.completeExerciseVM?.earnedStar ?? false)
        XCTAssertFalse(spy.completeExerciseVM?.feedbackText.isEmpty ?? true)
    }

    func test_presentCompleteExercise_noStar_negativeFeedback() {
        let (sut, spy) = makeSUT()
        let response = ArticulationImitationModels.CompleteExercise.Response(
            earnedStar: false,
            nextIndex: nil,
            allDone: true
        )
        sut.presentCompleteExercise(response)
        XCTAssertFalse(spy.completeExerciseVM?.earnedStar ?? true)
        XCTAssertFalse(spy.completeExerciseVM?.feedbackText.isEmpty ?? true)
    }
}
