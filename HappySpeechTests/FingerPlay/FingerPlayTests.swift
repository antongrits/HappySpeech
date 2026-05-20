@testable import HappySpeech
import XCTest

// MARK: - Spy

@MainActor
private final class SpyFingerPlayDisplay: FingerPlayDisplayLogic, @unchecked Sendable {

    var startVM: FingerPlayModels.Start.ViewModel?
    var liveVM: FingerPlayModels.HandPoseUpdate.ViewModel?
    var advanceVM: FingerPlayModels.Advance.ViewModel?

    func displayStart(viewModel: FingerPlayModels.Start.ViewModel) async {
        startVM = viewModel
    }
    func displayHandPoseUpdate(viewModel: FingerPlayModels.HandPoseUpdate.ViewModel) async {
        liveVM = viewModel
    }
    func displayAdvance(viewModel: FingerPlayModels.Advance.ViewModel) async {
        advanceVM = viewModel
    }
}

// MARK: - Helpers

private func makeStage(_ target: String, reps: Int = 1) -> FingerStage {
    FingerStage(targetPose: target, symbol: "hand.raised",
                description: "тест", repetitions: reps)
}

private func makeExercise(_ id: String,
                          _ stages: [FingerStage] = [
                            makeStage("fist"),
                            makeStage("open_palm")
                          ]) -> FingerExercise {
    FingerExercise(id: id, title: "Упр-\(id)",
                   rhymeText: "стих", stages: stages)
}

// MARK: - GestureClassifier tests

final class GestureClassifierTests: XCTestCase {

    func test_matches_exactPoseAndConfidence() {
        let cls = GestureClassifier(minimumConfidence: 0.5)
        XCTAssertTrue(cls.matches(detected: "fist", confidence: 0.8, target: "fist"))
    }

    func test_matches_failsWhenConfidenceBelowThreshold() {
        let cls = GestureClassifier(minimumConfidence: 0.5)
        XCTAssertFalse(cls.matches(detected: "fist", confidence: 0.3, target: "fist"))
    }

    func test_matches_differentPose() {
        let cls = GestureClassifier()
        XCTAssertFalse(cls.matches(detected: "fist", confidence: 0.9, target: "open_palm"))
    }

    func test_matches_equivalentSet_pointPinch() {
        let cls = GestureClassifier()
        XCTAssertTrue(cls.matches(detected: "pinch", confidence: 0.9, target: "point"))
        XCTAssertTrue(cls.matches(detected: "point", confidence: 0.9, target: "pinch"))
    }

    func test_requiredRepetitions_neverBelowOne() {
        let cls = GestureClassifier()
        let stage = makeStage("fist", reps: 0)
        XCTAssertEqual(cls.requiredRepetitions(for: stage), 1)
    }

    func test_didReachTarget_below() {
        let cls = GestureClassifier()
        let stage = makeStage("fist", reps: 3)
        XCTAssertFalse(cls.didReachTarget(successesInARow: 2, stage: stage))
        XCTAssertTrue(cls.didReachTarget(successesInARow: 3, stage: stage))
    }
}

// MARK: - FingerPlayInteractor tests

@MainActor
final class FingerPlayInteractorTests: XCTestCase {

    private func makeSUT(_ session: [FingerExercise]?) -> (FingerPlayInteractor, SpyFingerPlayDisplay) {
        let display = SpyFingerPlayDisplay()
        let presenter = FingerPlayPresenter(displayLogic: display)
        let interactor = FingerPlayInteractor(presenter: presenter, session: session)
        return (interactor, display)
    }

    func test_start_presentsFirstExercise() async {
        let (sut, display) = makeSUT([makeExercise("e1")])
        await sut.start(permissionGranted: true)
        XCTAssertEqual(display.startVM?.exerciseTitle, "Упр-e1")
        XCTAssertEqual(display.startVM?.stageIndex, 0)
        XCTAssertEqual(display.startVM?.totalExercises, 1)
        XCTAssertFalse(display.startVM?.isPermissionDenied ?? true)
    }

    func test_start_permissionDeniedFlag() async {
        let (sut, display) = makeSUT([makeExercise("e1")])
        await sut.start(permissionGranted: false)
        XCTAssertTrue(display.startVM?.isPermissionDenied ?? false)
    }

    func test_handleObservation_matchAdvancesStage() async {
        let exercise = makeExercise("e1", [
            makeStage("fist", reps: 1),
            makeStage("open_palm", reps: 1)
        ])
        let (sut, display) = makeSUT([exercise])
        await sut.start(permissionGranted: true)
        await sut.handleHandPoseObservation(detectedPose: "fist", confidence: 0.9)
        XCTAssertEqual(sut.currentStageIndex(), 1, "Should advance to second stage")
        XCTAssertNotNil(display.liveVM)
        XCTAssertTrue(display.liveVM?.matchesTarget ?? false)
    }

    func test_handleObservation_mismatchDoesNotAdvance() async {
        let exercise = makeExercise("e1", [makeStage("fist", reps: 1)])
        let (sut, _) = makeSUT([exercise])
        await sut.start(permissionGranted: true)
        await sut.handleHandPoseObservation(detectedPose: "open_palm", confidence: 0.9)
        XCTAssertEqual(sut.currentStageIndex(), 0)
    }

    func test_completeExerciseAdvancesToNext() async {
        let e1 = makeExercise("e1", [makeStage("fist", reps: 1)])
        let e2 = makeExercise("e2", [makeStage("open_palm", reps: 1)])
        let (sut, display) = makeSUT([e1, e2])
        await sut.start(permissionGranted: true)
        await sut.handleHandPoseObservation(detectedPose: "fist", confidence: 0.9)
        XCTAssertEqual(display.advanceVM?.completedCount, 1)
        XCTAssertEqual(display.advanceVM?.nextStartVM?.exerciseTitle, "Упр-e2")
        XCTAssertFalse(display.advanceVM?.isSessionFinished ?? true)
    }

    func test_completeSession_finishedFlag() async {
        let onlyOne = makeExercise("e1", [makeStage("fist", reps: 1)])
        let (sut, display) = makeSUT([onlyOne])
        await sut.start(permissionGranted: true)
        await sut.handleHandPoseObservation(detectedPose: "fist", confidence: 0.9)
        XCTAssertTrue(display.advanceVM?.isSessionFinished ?? false)
        XCTAssertTrue(sut.sessionFinished)
    }

    func test_corpus_isNotEmpty_afterBundleLoad() {
        // Базовый sanity check корпуса (fallback гарантирует ≥ 3).
        XCTAssertGreaterThanOrEqual(FingerPlayCorpus.exercises.count, 3)
    }

    func test_session_capsAtRequestedSize() {
        let sample = FingerPlayCorpus.sessionExercises(count: 3)
        XCTAssertLessThanOrEqual(sample.count, 3)
    }

    func test_skipToNext_skipsExercise() async {
        let e1 = makeExercise("e1")
        let e2 = makeExercise("e2")
        let (sut, _) = makeSUT([e1, e2])
        await sut.start(permissionGranted: true)
        await sut.skipToNext() // stage 0 -> stage 1
        XCTAssertEqual(sut.currentStageIndex(), 1)
    }

    func test_gestureSymbols_areNotEmpty() {
        for gesture in FingerPlayGesture.allCases {
            XCTAssertFalse(gesture.symbol.isEmpty)
            XCTAssertFalse(gesture.handPoseRawValue.isEmpty)
        }
    }
}
