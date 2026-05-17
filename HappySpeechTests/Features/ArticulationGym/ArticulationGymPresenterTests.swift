@testable import HappySpeech
import XCTest

// MARK: - Display Spy

@MainActor
private final class AGDisplaySpy: ArticulationGymDisplayLogic {
    var loadVM: ArticulationGymModels.Load.ViewModel?
    var timerVM: ArticulationGymModels.TimerTick.ViewModel?
    var nextVM: ArticulationGymModels.Next.ViewModel?
    var completeVM: ArticulationGymModels.Complete.ViewModel?

    func displayLoad(viewModel: ArticulationGymModels.Load.ViewModel) async { loadVM = viewModel }
    func displayTimerTick(viewModel: ArticulationGymModels.TimerTick.ViewModel) async { timerVM = viewModel }
    func displayNext(viewModel: ArticulationGymModels.Next.ViewModel) async { nextVM = viewModel }
    func displayComplete(viewModel: ArticulationGymModels.Complete.ViewModel) async { completeVM = viewModel }
}

// MARK: - Tests

@MainActor
final class ArticulationGymPresenterTests: XCTestCase {

    private func makeSUT() -> (ArticulationGymPresenter, AGDisplaySpy) {
        let spy = AGDisplaySpy()
        let presenter = ArticulationGymPresenter(displayLogic: spy)
        return (presenter, spy)
    }

    private func sampleItem(id: String = "art-x", duration: Int = 6) -> ArticulationItem {
        ArticulationItem(
            id: id,
            titleKey: "articulationGym.exercise.smile.title",
            instructionKey: "articulationGym.exercise.smile.instruction",
            illustrationSymbol: "mouth",
            durationSeconds: duration
        )
    }

    // MARK: presentLoad

    func test_presentLoad_buildsExerciseViewModels() async {
        let (sut, spy) = makeSUT()
        let response = ArticulationGymModels.Load.Response(
            soundGroup: .hissing,
            exercises: [sampleItem(id: "a"), sampleItem(id: "b")]
        )
        await sut.presentLoad(response: response)
        XCTAssertEqual(spy.loadVM?.exercises.count, 2)
        XCTAssertEqual(spy.loadVM?.totalCount, 2)
    }

    func test_presentLoad_localizesTitleAndInstruction() async {
        let (sut, spy) = makeSUT()
        let response = ArticulationGymModels.Load.Response(
            soundGroup: .hissing,
            exercises: [sampleItem()]
        )
        await sut.presentLoad(response: response)
        let exercise = spy.loadVM?.exercises.first
        XCTAssertFalse(exercise?.title.isEmpty ?? true)
        XCTAssertFalse(exercise?.instruction.isEmpty ?? true)
        // ключ не должен утечь в UI
        XCTAssertNotEqual(exercise?.title, "articulationGym.exercise.smile.title")
    }

    func test_presentLoad_groupLabelNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(
            response: .init(soundGroup: .sibilant, exercises: [sampleItem()])
        )
        XCTAssertFalse(spy.loadVM?.soundGroupLabel.isEmpty ?? true)
    }

    // MARK: presentTimerTick

    func test_presentTimerTick_timerTextMatchesSeconds() async {
        let (sut, spy) = makeSUT()
        let response = ArticulationGymModels.TimerTick.Response(
            exerciseIndex: 0, secondsRemaining: 3, shouldAdvance: false
        )
        await sut.presentTimerTick(response: response, duration: 6)
        XCTAssertEqual(spy.timerVM?.timerText, "3")
    }

    func test_presentTimerTick_ringProgressComputed() async {
        let (sut, spy) = makeSUT()
        let response = ArticulationGymModels.TimerTick.Response(
            exerciseIndex: 0, secondsRemaining: 3, shouldAdvance: false
        )
        await sut.presentTimerTick(response: response, duration: 6)
        // прошло 3 из 6 → 0.5
        XCTAssertEqual(spy.timerVM?.ringProgress ?? 0, 0.5, accuracy: 0.001)
    }

    func test_presentTimerTick_zeroDuration_progressZero() async {
        let (sut, spy) = makeSUT()
        let response = ArticulationGymModels.TimerTick.Response(
            exerciseIndex: 0, secondsRemaining: 0, shouldAdvance: true
        )
        await sut.presentTimerTick(response: response, duration: 0)
        XCTAssertEqual(spy.timerVM?.ringProgress, 0)
    }

    func test_presentTimerTick_shouldAdvancePropagated() async {
        let (sut, spy) = makeSUT()
        let response = ArticulationGymModels.TimerTick.Response(
            exerciseIndex: 0, secondsRemaining: 0, shouldAdvance: true
        )
        await sut.presentTimerTick(response: response, duration: 5)
        XCTAssertEqual(spy.timerVM?.shouldAdvance, true)
    }

    func test_presentTimerTick_a11yLabelNotEmpty() async {
        let (sut, spy) = makeSUT()
        let response = ArticulationGymModels.TimerTick.Response(
            exerciseIndex: 0, secondsRemaining: 2, shouldAdvance: false
        )
        await sut.presentTimerTick(response: response, duration: 5)
        XCTAssertFalse(spy.timerVM?.timerAccessibilityLabel.isEmpty ?? true)
    }

    // MARK: presentNext

    func test_presentNext_notLast_progressBetweenZeroAndOne() async {
        let (sut, spy) = makeSUT()
        let response = ArticulationGymModels.Next.Response(nextIndex: 2, isLast: false)
        await sut.presentNext(response: response, totalCount: 7)
        XCTAssertEqual(spy.nextVM?.showCompletion, false)
        XCTAssertEqual(spy.nextVM?.nextIndex, 2)
        XCTAssertEqual(spy.nextVM?.progress ?? 0, 2.0 / 7.0, accuracy: 0.001)
    }

    func test_presentNext_last_showCompletionTrue() async {
        let (sut, spy) = makeSUT()
        let response = ArticulationGymModels.Next.Response(nextIndex: 7, isLast: true)
        await sut.presentNext(response: response, totalCount: 7)
        XCTAssertEqual(spy.nextVM?.showCompletion, true)
        XCTAssertEqual(spy.nextVM?.progress ?? 0, 1.0, accuracy: 0.001)
    }

    func test_presentNext_zeroTotal_progressZero() async {
        let (sut, spy) = makeSUT()
        let response = ArticulationGymModels.Next.Response(nextIndex: 0, isLast: true)
        await sut.presentNext(response: response, totalCount: 0)
        XCTAssertEqual(spy.nextVM?.progress, 0)
    }

    // MARK: presentComplete

    func test_presentComplete_celebrationTextNotEmpty() async {
        let (sut, spy) = makeSUT()
        let response = ArticulationGymModels.Complete.Response(
            exerciseCount: 7, soundGroup: .hissing
        )
        await sut.presentComplete(response: response)
        XCTAssertFalse(spy.completeVM?.celebrationText.isEmpty ?? true)
    }
}
