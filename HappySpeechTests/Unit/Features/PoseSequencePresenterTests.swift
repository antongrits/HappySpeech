import XCTest
@testable import HappySpeech

// MARK: - PoseSequencePresenterTests
//
// Phase 2.6 batch 3 — покрытие PoseSequencePresenter (0% → цель ≥90%).

@MainActor
final class PoseSequencePresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: PoseSequenceDisplayLogic {
        var startGameVM: PoseSequenceModels.StartGame.ViewModel?
        var updateFrameVM: PoseSequenceModels.UpdateFrame.ViewModel?
        var updateBodyPoseVM: PoseSequenceModels.UpdateBodyPose.ViewModel?
        var scoreVM: PoseSequenceModels.ScoreAttempt.ViewModel?

        func displayStartGame(_ viewModel: PoseSequenceModels.StartGame.ViewModel) { startGameVM = viewModel }
        func displayUpdateFrame(_ viewModel: PoseSequenceModels.UpdateFrame.ViewModel) { updateFrameVM = viewModel }
        func displayUpdateBodyPose(_ viewModel: PoseSequenceModels.UpdateBodyPose.ViewModel) { updateBodyPoseVM = viewModel }
        func displayScoreAttempt(_ viewModel: PoseSequenceModels.ScoreAttempt.ViewModel) { scoreVM = viewModel }
    }

    private func makeSUT() -> (PoseSequencePresenter, DisplaySpy) {
        let sut = PoseSequencePresenter()
        let spy = DisplaySpy()
        sut.display = spy
        return (sut, spy)
    }

    private func makeTargetPose(id: String = "p1", name: String = "Руки вверх", hint: String = "Подними руки") -> TargetPose {
        TargetPose(id: id, name: name, hint: hint, jointTargets: [:])
    }

    // MARK: - presentStartGame (face mode)

    func test_presentStartGame_faceMode_postureNamesNotEmpty() {
        let (sut, spy) = makeSUT()
        let postures: [ArticulationPosture] = [.smile, .pucker, .cupShape]
        sut.presentStartGame(.init(postures: postures, currentIndex: 0, mode: .face, targetPoses: []))
        XCTAssertNotNil(spy.startGameVM)
        XCTAssertEqual(spy.startGameVM?.postureNames.count, 3)
        XCTAssertFalse(spy.startGameVM?.currentName.isEmpty ?? true)
        XCTAssertEqual(spy.startGameVM?.mode, .face)
    }

    func test_presentStartGame_faceMode_secondIndex_currentNameCorrect() {
        let (sut, spy) = makeSUT()
        let postures: [ArticulationPosture] = [.smile, .pucker, .shoveling]
        sut.presentStartGame(.init(postures: postures, currentIndex: 1, mode: .face, targetPoses: []))
        XCTAssertEqual(spy.startGameVM?.currentIndex, 1)
        // pucker.displayName — не пустое
        XCTAssertFalse(spy.startGameVM?.currentName.isEmpty ?? true)
    }

    func test_presentStartGame_faceMode_outOfBoundsIndex_currentNameEmpty() {
        let (sut, spy) = makeSUT()
        let postures: [ArticulationPosture] = [.smile]
        sut.presentStartGame(.init(postures: postures, currentIndex: 5, mode: .face, targetPoses: []))
        XCTAssertEqual(spy.startGameVM?.currentName, "")
    }

    func test_presentStartGame_faceMode_storesTotal_forProgressCalculation() {
        let (sut, _) = makeSUT()
        let postures: [ArticulationPosture] = [.smile, .pucker, .cupShape, .tongueDown]
        sut.presentStartGame(.init(postures: postures, currentIndex: 0, mode: .face, targetPoses: []))

        // Теперь проверяем что total=4 используется при updateFrame
        let spy2 = DisplaySpy()
        sut.display = spy2
        sut.presentUpdateFrame(.init(currentIndex: 2, confidence: 0.7, advanced: false))
        // progress = 2/4 = 0.5
        XCTAssertEqual(spy2.updateFrameVM?.progress ?? 0, 0.5, accuracy: 0.01)
    }

    // MARK: - presentStartGame (body mode)

    func test_presentStartGame_bodyMode_targetPoseNamesUsed() {
        let (sut, spy) = makeSUT()
        let poses = [
            makeTargetPose(id: "p1", name: "Руки вверх", hint: "Подними руки"),
            makeTargetPose(id: "p2", name: "Руки в стороны", hint: "Разведи руки")
        ]
        sut.presentStartGame(.init(postures: [], currentIndex: 0, mode: .body, targetPoses: poses))
        XCTAssertEqual(spy.startGameVM?.postureNames.count, 2)
        XCTAssertEqual(spy.startGameVM?.currentName, "Руки вверх")
        XCTAssertEqual(spy.startGameVM?.currentHint, "Подними руки")
        XCTAssertEqual(spy.startGameVM?.mode, .body)
    }

    func test_presentStartGame_bodyMode_outOfBoundsIndex_emptyNameAndHint() {
        let (sut, spy) = makeSUT()
        let poses = [makeTargetPose(id: "p1")]
        sut.presentStartGame(.init(postures: [], currentIndex: 3, mode: .body, targetPoses: poses))
        XCTAssertEqual(spy.startGameVM?.currentName, "")
        XCTAssertEqual(spy.startGameVM?.currentHint, "")
    }

    func test_presentStartGame_bodyMode_storesTotal_forBodyPoseProgress() {
        let (sut, _) = makeSUT()
        let poses = [makeTargetPose(id: "p1"), makeTargetPose(id: "p2"), makeTargetPose(id: "p3")]
        sut.presentStartGame(.init(postures: [], currentIndex: 0, mode: .body, targetPoses: poses))

        let spy2 = DisplaySpy()
        sut.display = spy2
        sut.presentUpdateBodyPose(.init(currentIndex: 1, score: 2, advanced: false, currentHint: "Подсказка"))
        // progress = 1/3 ≈ 0.333
        XCTAssertEqual(spy2.updateBodyPoseVM?.progress ?? 0, 1.0 / 3.0, accuracy: 0.01)
    }

    // MARK: - presentUpdateFrame

    func test_presentUpdateFrame_advanced_advancedTrue() {
        let (sut, spy) = makeSUT()
        // Устанавливаем total через startGame
        sut.presentStartGame(.init(postures: [.smile, .pucker], currentIndex: 0, mode: .face, targetPoses: []))
        let spy2 = DisplaySpy()
        sut.display = spy2
        sut.presentUpdateFrame(.init(currentIndex: 1, confidence: 0.8, advanced: true))
        XCTAssertTrue(spy2.updateFrameVM?.advanced == true)
    }

    func test_presentUpdateFrame_notAdvanced_advancedFalse() {
        let (sut, spy) = makeSUT()
        sut.presentStartGame(.init(postures: [.smile, .pucker], currentIndex: 0, mode: .face, targetPoses: []))
        let spy2 = DisplaySpy()
        sut.display = spy2
        sut.presentUpdateFrame(.init(currentIndex: 0, confidence: 0.3, advanced: false))
        XCTAssertFalse(spy2.updateFrameVM?.advanced ?? true)
        // progress = 0/2 = 0.0
        XCTAssertEqual(spy2.updateFrameVM?.progress ?? -1, 0.0, accuracy: 0.01)
    }

    func test_presentUpdateFrame_defaultTotal1_progressCalculated() {
        let (sut, spy) = makeSUT()
        // Без предварительного startGame total=1
        sut.presentUpdateFrame(.init(currentIndex: 0, confidence: 0.5, advanced: false))
        // progress = 0/max(1,1) = 0.0
        XCTAssertEqual(spy.updateFrameVM?.progress ?? -1, 0.0, accuracy: 0.01)
    }

    // MARK: - presentUpdateBodyPose

    func test_presentUpdateBodyPose_propagatesFields() {
        let (sut, spy) = makeSUT()
        sut.presentStartGame(.init(postures: [], currentIndex: 0, mode: .body, targetPoses: [
            makeTargetPose(id: "p1"), makeTargetPose(id: "p2")
        ]))
        let spy2 = DisplaySpy()
        sut.display = spy2
        sut.presentUpdateBodyPose(.init(currentIndex: 1, score: 3, advanced: true, currentHint: "Держи позу"))
        XCTAssertEqual(spy2.updateBodyPoseVM?.score, 3)
        XCTAssertTrue(spy2.updateBodyPoseVM?.advanced == true)
        XCTAssertEqual(spy2.updateBodyPoseVM?.hintText, "Держи позу")
    }

    // MARK: - presentScoreAttempt

    func test_presentScoreAttempt_starsPassedThrough() {
        let (sut, spy) = makeSUT()
        sut.presentScoreAttempt(.init(stars: 3))
        XCTAssertEqual(spy.scoreVM?.stars, 3)
        XCTAssertFalse(spy.scoreVM?.summary.isEmpty ?? true)
    }

    func test_presentScoreAttempt_zeroStars_summaryNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentScoreAttempt(.init(stars: 0))
        XCTAssertEqual(spy.scoreVM?.stars, 0)
        XCTAssertFalse(spy.scoreVM?.summary.isEmpty ?? true)
    }
}
