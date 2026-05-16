@testable import HappySpeech
import XCTest

// MARK: - Spy Presenter

@MainActor
private final class SpyARMirrorPresenter: ARMirrorPresentationLogic {
    var startGameCallCount = 0
    var updateFrameCallCount = 0
    var scoreCallCount = 0

    var lastStartGame: ARMirrorModels.StartGame.Response?
    var lastUpdateFrame: ARMirrorModels.UpdateFrame.Response?
    var lastScore: ARMirrorModels.ScoreAttempt.Response?

    func presentStartGame(_ response: ARMirrorModels.StartGame.Response) {
        startGameCallCount += 1
        lastStartGame = response
    }
    func presentUpdateFrame(_ response: ARMirrorModels.UpdateFrame.Response) {
        updateFrameCallCount += 1
        lastUpdateFrame = response
    }
    func presentScoreAttempt(_ response: ARMirrorModels.ScoreAttempt.Response) {
        scoreCallCount += 1
        lastScore = response
    }
}

// MARK: - Tests
//
// Заметка о покрытии AR-кода:
// ARMirrorInteractor — VIP-thin orchestration. Реальный ARSession / ARSCNView
// live face mesh живут в View и недоступны юнит-тесту. Покрыта вся
// VIP-логика: startGame, updateFrame (confidence → sustain timer), scoreAttempt
// (звёздная шкала), advanceToNextExercise (цикл упражнений). Frame stream
// эмулируется через FaceBlendshapes-фикстуры — TonguePostureClassifier
// rule-based, поэтому полностью детерминирован.

@MainActor
final class ARMirrorInteractorTests: XCTestCase {

    private func makeSUT() -> (ARMirrorInteractor, SpyARMirrorPresenter) {
        let sut = ARMirrorInteractor()
        let spy = SpyARMirrorPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    /// Blendshapes с высоким confidence для конкретного упражнения.
    private func blendshapes(for exercise: ARMirrorModels.Exercise) -> FaceBlendshapes {
        switch exercise {
        case .smile:     return FaceBlendshapes(mouthSmileLeft: 1.0, mouthSmileRight: 1.0)
        case .pucker:    return FaceBlendshapes(mouthPucker: 1.0)
        case .funnel:    return FaceBlendshapes(mouthFunnel: 1.0)
        case .jawOpen:   return FaceBlendshapes(jawOpen: 1.0)
        case .tongueOut: return FaceBlendshapes(tongueOut: 1.0)
        }
    }

    // MARK: - startGame

    func test_startGame_emitsAllExercises() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init())
        XCTAssertEqual(spy.startGameCallCount, 1)
        XCTAssertEqual(spy.lastStartGame?.exercises, ARMirrorModels.Exercise.allCases)
        XCTAssertEqual(spy.lastStartGame?.currentIndex, 0)
    }

    func test_startGame_resetsToFirstExercise() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init())
        sut.advanceToNextExercise()
        sut.startGame(.init())
        XCTAssertEqual(spy.lastStartGame?.currentIndex, 0)
    }

    // MARK: - updateFrame

    func test_updateFrame_withoutStart_neutralExerciseStillEmits() {
        // currentIndex 0 валиден сразу — exercises инициализированы дефолтом
        let (sut, spy) = makeSUT()
        sut.updateFrame(.init(blendshapes: FaceBlendshapes()))
        XCTAssertEqual(spy.updateFrameCallCount, 1)
    }

    func test_updateFrame_lowConfidence_doesNotComplete() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init())
        sut.updateFrame(.init(blendshapes: FaceBlendshapes()))
        XCTAssertEqual(spy.lastUpdateFrame?.didCompleteExercise, false)
        XCTAssertEqual(spy.lastUpdateFrame?.sustainedSeconds, 0)
    }

    func test_updateFrame_highConfidence_startsSustainTimer() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init())
        sut.updateFrame(.init(blendshapes: blendshapes(for: .smile)))
        XCTAssertGreaterThan(spy.lastUpdateFrame?.confidence ?? 0, 0.6)
        // Первый кадр запускает таймер, но 3с ещё не прошло
        XCTAssertEqual(spy.lastUpdateFrame?.didCompleteExercise, false)
    }

    func test_updateFrame_lowConfidenceResetsSustain() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init())
        sut.updateFrame(.init(blendshapes: blendshapes(for: .smile)))
        sut.updateFrame(.init(blendshapes: FaceBlendshapes()))
        XCTAssertEqual(spy.lastUpdateFrame?.sustainedSeconds, 0, "Падение confidence сбрасывает таймер")
    }

    func test_updateFrame_reportsConfidenceForCurrentExercise() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init())
        // Первое упражнение — smile
        sut.updateFrame(.init(blendshapes: blendshapes(for: .smile)))
        XCTAssertEqual(spy.lastUpdateFrame?.currentExercise, .smile)
    }

    // MARK: - scoreAttempt

    func test_scoreAttempt_highConfidence_threeStars() {
        let (sut, spy) = makeSUT()
        sut.scoreAttempt(.init(exercise: .smile, averageConfidence: 0.9))
        XCTAssertEqual(spy.lastScore?.stars, 3)
    }

    func test_scoreAttempt_mediumConfidence_twoStars() {
        let (sut, spy) = makeSUT()
        sut.scoreAttempt(.init(exercise: .smile, averageConfidence: 0.75))
        XCTAssertEqual(spy.lastScore?.stars, 2)
    }

    func test_scoreAttempt_lowConfidence_oneStar() {
        let (sut, spy) = makeSUT()
        sut.scoreAttempt(.init(exercise: .smile, averageConfidence: 0.6))
        XCTAssertEqual(spy.lastScore?.stars, 1)
    }

    func test_scoreAttempt_veryLowConfidence_zeroStars() {
        let (sut, spy) = makeSUT()
        sut.scoreAttempt(.init(exercise: .smile, averageConfidence: 0.2))
        XCTAssertEqual(spy.lastScore?.stars, 0)
    }

    func test_scoreAttempt_boundary85_threeStars() {
        let (sut, spy) = makeSUT()
        sut.scoreAttempt(.init(exercise: .pucker, averageConfidence: 0.85))
        XCTAssertEqual(spy.lastScore?.stars, 3)
    }

    // MARK: - advanceToNextExercise

    func test_advance_movesToNextExercise() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init())
        sut.advanceToNextExercise()
        XCTAssertEqual(spy.lastStartGame?.currentIndex, 1)
    }

    func test_advance_atLastExercise_doesNotOverflow() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init())
        let total = ARMirrorModels.Exercise.allCases.count
        for _ in 0..<(total + 2) { sut.advanceToNextExercise() }
        // currentIndex не выходит за пределы
        XCTAssertLessThan(spy.lastStartGame?.currentIndex ?? Int.max, total)
    }

    func test_advance_resetsExerciseState() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init())
        sut.updateFrame(.init(blendshapes: blendshapes(for: .smile)))
        sut.advanceToNextExercise()
        // Новое упражнение начинается с нулевым sustain
        sut.updateFrame(.init(blendshapes: FaceBlendshapes()))
        XCTAssertEqual(spy.lastUpdateFrame?.sustainedSeconds, 0)
    }

    // MARK: - Exercise model

    func test_exercise_displayAndInstructionKeysNotEmpty() {
        for exercise in ARMirrorModels.Exercise.allCases {
            XCTAssertFalse(exercise.displayNameKey.isEmpty)
            XCTAssertFalse(exercise.instructionKey.isEmpty)
        }
    }

    func test_exercise_targetPostureMapping() {
        XCTAssertEqual(ARMirrorModels.Exercise.smile.targetPosture, .smile)
        XCTAssertEqual(ARMirrorModels.Exercise.pucker.targetPosture, .pucker)
        XCTAssertEqual(ARMirrorModels.Exercise.funnel.targetPosture, .cupShape)
        XCTAssertEqual(ARMirrorModels.Exercise.jawOpen.targetPosture, .tongueDown)
        XCTAssertEqual(ARMirrorModels.Exercise.tongueOut.targetPosture, .shoveling)
    }
}
