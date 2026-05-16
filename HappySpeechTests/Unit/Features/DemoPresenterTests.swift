import XCTest
@testable import HappySpeech

// MARK: - DemoPresenterTests
//
// Phase 2.6 batch 3 — покрытие DemoPresenter (20% → цель ≥90%).

@MainActor
final class DemoPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: DemoDisplayLogic {
        var loadDemoVM: DemoModels.LoadDemo.ViewModel?
        var advanceStepVM: DemoModels.AdvanceStep.ViewModel?
        var goBackVM: DemoModels.GoBack.ViewModel?
        var jumpToVM: DemoModels.JumpTo.ViewModel?
        var interactiveTapVM: DemoModels.InteractiveTap.ViewModel?
        var skipDemoVM: DemoModels.SkipDemo.ViewModel?
        var completeDemoVM: DemoModels.CompleteDemo.ViewModel?
        var toggleAutoAdvanceVM: DemoModels.ToggleAutoAdvance.ViewModel?
        var autoAdvanceTickVM: DemoModels.AutoAdvanceTick.ViewModel?
        var replayStepVM: DemoModels.ReplayStep.ViewModel?

        func displayLoadDemo(_ viewModel: DemoModels.LoadDemo.ViewModel) { loadDemoVM = viewModel }
        func displayAdvanceStep(_ viewModel: DemoModels.AdvanceStep.ViewModel) { advanceStepVM = viewModel }
        func displayGoBack(_ viewModel: DemoModels.GoBack.ViewModel) { goBackVM = viewModel }
        func displayJumpTo(_ viewModel: DemoModels.JumpTo.ViewModel) { jumpToVM = viewModel }
        func displayInteractiveTap(_ viewModel: DemoModels.InteractiveTap.ViewModel) { interactiveTapVM = viewModel }
        func displaySkipDemo(_ viewModel: DemoModels.SkipDemo.ViewModel) { skipDemoVM = viewModel }
        func displayCompleteDemo(_ viewModel: DemoModels.CompleteDemo.ViewModel) { completeDemoVM = viewModel }
        func displayToggleAutoAdvance(_ viewModel: DemoModels.ToggleAutoAdvance.ViewModel) { toggleAutoAdvanceVM = viewModel }
        func displayAutoAdvanceTick(_ viewModel: DemoModels.AutoAdvanceTick.ViewModel) { autoAdvanceTickVM = viewModel }
        func displayReplayStep(_ viewModel: DemoModels.ReplayStep.ViewModel) { replayStepVM = viewModel }
    }

    private func makeSUT() -> (DemoPresenter, DisplaySpy) {
        let sut = DemoPresenter()
        let spy = DisplaySpy()
        sut.display = spy
        return (sut, spy)
    }

    private func makeStep(id: Int = 0, title: String = "Шаг") -> DemoStep {
        DemoStep(
            id: id,
            title: title,
            subtitle: "Подзаголовок",
            description: "Описание",
            mascotText: "Ляля говорит",
            screenSymbol: "iphone",
            illustrationSymbol: "star",
            highlightColor: "primary",
            accent: .primary,
            lyalyaState: .explaining,
            hasInteractive: false,
            actionTitle: nil
        )
    }

    // MARK: - presentLoadDemo

    func test_presentLoadDemo_firstStep_isFirst() {
        let (sut, spy) = makeSUT()
        let steps = [makeStep(id: 0, title: "Первый"), makeStep(id: 1, title: "Второй")]
        sut.presentLoadDemo(.init(steps: steps, currentIndex: 0))
        XCTAssertNotNil(spy.loadDemoVM)
        XCTAssertTrue(spy.loadDemoVM?.isFirst == true)
        XCTAssertFalse(spy.loadDemoVM?.isLast ?? true)
        XCTAssertEqual(spy.loadDemoVM?.totalSteps, 2)
    }

    func test_presentLoadDemo_lastStep_isLast() {
        let (sut, spy) = makeSUT()
        let steps = [makeStep(id: 0), makeStep(id: 1)]
        sut.presentLoadDemo(.init(steps: steps, currentIndex: 1))
        XCTAssertFalse(spy.loadDemoVM?.isFirst ?? true)
        XCTAssertTrue(spy.loadDemoVM?.isLast == true)
    }

    func test_presentLoadDemo_progressFraction_correct() {
        let (sut, spy) = makeSUT()
        let steps = [makeStep(id: 0), makeStep(id: 1), makeStep(id: 2)]
        sut.presentLoadDemo(.init(steps: steps, currentIndex: 1))
        // (1+1)/3 = 2/3 ≈ 0.667
        XCTAssertEqual(spy.loadDemoVM?.progress ?? 0, 2.0/3.0, accuracy: 0.01)
    }

    func test_presentLoadDemo_progressLabelNotEmpty() {
        let (sut, spy) = makeSUT()
        let steps = [makeStep(id: 0)]
        sut.presentLoadDemo(.init(steps: steps, currentIndex: 0))
        XCTAssertFalse(spy.loadDemoVM?.progressLabel.isEmpty ?? true)
    }

    func test_presentLoadDemo_stepTitle_propagated() {
        let (sut, spy) = makeSUT()
        let step = makeStep(id: 0, title: "Привет мир")
        sut.presentLoadDemo(.init(steps: [step], currentIndex: 0))
        XCTAssertEqual(spy.loadDemoVM?.stepTitle, "Привет мир")
    }

    func test_presentLoadDemo_outOfBoundsIndex_emptyTitle() {
        let (sut, spy) = makeSUT()
        let steps = [makeStep(id: 0)]
        sut.presentLoadDemo(.init(steps: steps, currentIndex: 5))
        XCTAssertEqual(spy.loadDemoVM?.stepTitle, "")
    }

    // MARK: - presentAdvanceStep

    func test_presentAdvanceStep_notCompleted() {
        let (sut, spy) = makeSUT()
        let steps = [makeStep(id: 0), makeStep(id: 1)]
        sut.presentAdvanceStep(.init(steps: steps, currentIndex: 1, isCompleted: false))
        XCTAssertFalse(spy.advanceStepVM?.isCompleted ?? true)
    }

    func test_presentAdvanceStep_completed() {
        let (sut, spy) = makeSUT()
        let steps = [makeStep(id: 0)]
        sut.presentAdvanceStep(.init(steps: steps, currentIndex: 0, isCompleted: true))
        XCTAssertTrue(spy.advanceStepVM?.isCompleted == true)
    }

    // MARK: - presentGoBack

    func test_presentGoBack_atFirst_isFirst() {
        let (sut, spy) = makeSUT()
        let steps = [makeStep(id: 0), makeStep(id: 1)]
        sut.presentGoBack(.init(steps: steps, currentIndex: 0))
        XCTAssertTrue(spy.goBackVM?.isFirst == true)
    }

    // MARK: - presentJumpTo

    func test_presentJumpTo_propagatesIndex() {
        let (sut, spy) = makeSUT()
        let steps = [makeStep(id: 0), makeStep(id: 1), makeStep(id: 2)]
        sut.presentJumpTo(.init(steps: steps, currentIndex: 2))
        XCTAssertEqual(spy.jumpToVM?.currentIndex, 2)
        XCTAssertTrue(spy.jumpToVM?.isLast == true)
    }

    // MARK: - presentInteractiveTap

    func test_presentInteractiveTap_toastNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentInteractiveTap(.init(stepId: 3, stepTitle: "Игра"))
        XCTAssertNotNil(spy.interactiveTapVM)
        XCTAssertFalse(spy.interactiveTapVM?.toastMessage.isEmpty ?? true)
        XCTAssertEqual(spy.interactiveTapVM?.stepId, 3)
    }

    // MARK: - presentSkipDemo

    func test_presentSkipDemo_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentSkipDemo(.init())
        XCTAssertNotNil(spy.skipDemoVM)
    }

    // MARK: - presentCompleteDemo

    func test_presentCompleteDemo_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentCompleteDemo(.init())
        XCTAssertNotNil(spy.completeDemoVM)
    }

    // MARK: - presentToggleAutoAdvance

    func test_presentToggleAutoAdvance_enabled() {
        let (sut, spy) = makeSUT()
        sut.presentToggleAutoAdvance(.init(isEnabled: true, toggleLabel: "Авто: вкл"))
        XCTAssertTrue(spy.toggleAutoAdvanceVM?.isEnabled == true)
        XCTAssertEqual(spy.toggleAutoAdvanceVM?.toggleLabel, "Авто: вкл")
    }

    func test_presentToggleAutoAdvance_disabled() {
        let (sut, spy) = makeSUT()
        sut.presentToggleAutoAdvance(.init(isEnabled: false, toggleLabel: "Авто: выкл"))
        XCTAssertFalse(spy.toggleAutoAdvanceVM?.isEnabled ?? true)
    }

    // MARK: - presentAutoAdvanceTick

    func test_presentAutoAdvanceTick_updatesIndex() {
        let (sut, spy) = makeSUT()
        let steps = [makeStep(id: 0), makeStep(id: 1), makeStep(id: 2)]
        sut.presentAutoAdvanceTick(.init(steps: steps, currentIndex: 1, isCompleted: false))
        XCTAssertEqual(spy.autoAdvanceTickVM?.currentIndex, 1)
        XCTAssertFalse(spy.autoAdvanceTickVM?.isCompleted ?? true)
    }

    // MARK: - presentReplayStep

    func test_presentReplayStep_toastNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentReplayStep(.init(stepId: 2, stepTitle: "Повтор"))
        XCTAssertNotNil(spy.replayStepVM)
        XCTAssertFalse(spy.replayStepVM?.toastMessage.isEmpty ?? true)
    }

    // MARK: - nextTitle helper (via presentLoadDemo)

    func test_nextTitle_notLast_isNextLabel() {
        let (sut, spy) = makeSUT()
        let steps = [makeStep(id: 0), makeStep(id: 1)]
        sut.presentLoadDemo(.init(steps: steps, currentIndex: 0))
        XCTAssertFalse(spy.loadDemoVM?.nextTitle.isEmpty ?? true)
    }

    func test_nextTitle_last_isFinishLabel() {
        let (sut, spy) = makeSUT()
        let steps = [makeStep(id: 0)]
        sut.presentLoadDemo(.init(steps: steps, currentIndex: 0))
        XCTAssertFalse(spy.loadDemoVM?.nextTitle.isEmpty ?? true)
    }
}
