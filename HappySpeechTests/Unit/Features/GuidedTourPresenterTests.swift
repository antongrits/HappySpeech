import XCTest
@testable import HappySpeech

// MARK: - GuidedTourPresenterTests
//
// Phase 2.6 batch 3 — покрытие GuidedTourPresenter (53% → цель ≥90%).

@MainActor
final class GuidedTourPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: GuidedTourDisplayLogic {
        var loadVM: GuidedTourModels.LoadTour.ViewModel?
        var nextVM: GuidedTourModels.NextStep.ViewModel?
        var previousVM: GuidedTourModels.PreviousStep.ViewModel?
        var skipVM: GuidedTourModels.SkipTour.ViewModel?
        var completeVM: GuidedTourModels.CompleteTour.ViewModel?
        var resetVM: GuidedTourModels.ResetTour.ViewModel?
        var autoAdvanceVM: GuidedTourModels.AutoAdvance.ViewModel?

        func displayLoadTour(_ vm: GuidedTourModels.LoadTour.ViewModel) { loadVM = vm }
        func displayNextStep(_ vm: GuidedTourModels.NextStep.ViewModel) { nextVM = vm }
        func displayPreviousStep(_ vm: GuidedTourModels.PreviousStep.ViewModel) { previousVM = vm }
        func displaySkipTour(_ vm: GuidedTourModels.SkipTour.ViewModel) { skipVM = vm }
        func displayCompleteTour(_ vm: GuidedTourModels.CompleteTour.ViewModel) { completeVM = vm }
        func displayResetTour(_ vm: GuidedTourModels.ResetTour.ViewModel) { resetVM = vm }
        func displayAutoAdvance(_ vm: GuidedTourModels.AutoAdvance.ViewModel) { autoAdvanceVM = vm }
    }

    private func makeSUT() -> (GuidedTourPresenter, DisplaySpy) {
        let sut = GuidedTourPresenter()
        let spy = DisplaySpy()
        sut.display = spy
        return (sut, spy)
    }

    private func makeStep(id: String = "step-1") -> TourStep {
        TourStep(
            id: id,
            title: "Заголовок",
            body: "Описание шага",
            highlightKey: "key-\(id)",
            lyalyaPhrase: nil,
            autoAdvanceAfter: nil,
            allowSkip: true
        )
    }

    // MARK: - presentLoadTour

    func test_presentLoadTour_started_isVisible() {
        let (sut, spy) = makeSUT()
        let steps = [makeStep(id: "s0"), makeStep(id: "s1"), makeStep(id: "s2")]
        sut.presentLoadTour(.init(kind: .started, steps: steps, initialIndex: 0))
        XCTAssertTrue(spy.loadVM?.isVisible == true)
        XCTAssertEqual(spy.loadVM?.stepNumber, 1)
        XCTAssertEqual(spy.loadVM?.totalSteps, 3)
        XCTAssertFalse(spy.loadVM?.isLastStep ?? true)
        XCTAssertEqual(spy.loadVM?.progressFraction ?? 0, 1.0/3.0, accuracy: 0.01)
    }

    func test_presentLoadTour_alreadyCompleted_notVisible() {
        let (sut, spy) = makeSUT()
        let steps = [makeStep()]
        sut.presentLoadTour(.init(kind: .alreadyCompleted, steps: steps, initialIndex: 0))
        XCTAssertFalse(spy.loadVM?.isVisible ?? true)
        XCTAssertNil(spy.loadVM?.currentStep)
    }

    func test_presentLoadTour_gatedBySessionCount_notVisible() {
        let (sut, spy) = makeSUT()
        let steps = [makeStep()]
        sut.presentLoadTour(.init(kind: .gatedBySessionCount(required: 3, current: 1), steps: steps, initialIndex: 0))
        XCTAssertFalse(spy.loadVM?.isVisible ?? true)
    }

    func test_presentLoadTour_singleStep_isLastStep() {
        let (sut, spy) = makeSUT()
        let steps = [makeStep()]
        sut.presentLoadTour(.init(kind: .started, steps: steps, initialIndex: 0))
        XCTAssertTrue(spy.loadVM?.isLastStep == true)
        XCTAssertEqual(spy.loadVM?.progressFraction ?? 0, 1.0, accuracy: 0.01)
    }

    // MARK: - presentNextStep

    func test_presentNextStep_advanced_isVisible() {
        let (sut, spy) = makeSUT()
        let steps = [makeStep(id: "s0"), makeStep(id: "s1"), makeStep(id: "s2")]
        sut.presentNextStep(.init(kind: .advanced, steps: steps, newIndex: 1))
        XCTAssertTrue(spy.nextVM?.isVisible == true)
        XCTAssertEqual(spy.nextVM?.stepNumber, 2)
        XCTAssertFalse(spy.nextVM?.isLastStep ?? true)
    }

    func test_presentNextStep_completed_notVisible() {
        let (sut, spy) = makeSUT()
        let steps = [makeStep(id: "s0"), makeStep(id: "s1")]
        sut.presentNextStep(.init(kind: .completed, steps: steps, newIndex: nil))
        XCTAssertFalse(spy.nextVM?.isVisible ?? true)
        XCTAssertEqual(spy.nextVM?.progressFraction ?? 0, 1.0, accuracy: 0.01)
    }

    func test_presentNextStep_noop_displayNotCalled() {
        let (sut, spy) = makeSUT()
        let steps = [makeStep()]
        sut.presentNextStep(.init(kind: .noop, steps: steps, newIndex: nil))
        XCTAssertNil(spy.nextVM)
    }

    // MARK: - presentPreviousStep

    func test_presentPreviousStep_retreated_isVisible() {
        let (sut, spy) = makeSUT()
        let steps = [makeStep(id: "s0"), makeStep(id: "s1")]
        sut.presentPreviousStep(.init(kind: .retreated, steps: steps, newIndex: 0))
        XCTAssertTrue(spy.previousVM?.isVisible == true)
        XCTAssertEqual(spy.previousVM?.stepNumber, 1)
    }

    func test_presentPreviousStep_atFirstStep_displayNotCalled() {
        let (sut, spy) = makeSUT()
        let steps = [makeStep()]
        sut.presentPreviousStep(.init(kind: .atFirstStep, steps: steps, newIndex: nil))
        XCTAssertNil(spy.previousVM)
    }

    func test_presentPreviousStep_noop_displayNotCalled() {
        let (sut, spy) = makeSUT()
        let steps = [makeStep()]
        sut.presentPreviousStep(.init(kind: .noop, steps: steps, newIndex: nil))
        XCTAssertNil(spy.previousVM)
    }

    // MARK: - presentSkipTour

    func test_presentSkipTour_notVisible() {
        let (sut, spy) = makeSUT()
        sut.presentSkipTour(.init(skippedAtIndex: 2, totalSteps: 5))
        XCTAssertFalse(spy.skipVM?.isVisible ?? true)
    }

    // MARK: - presentCompleteTour

    func test_presentCompleteTour_notVisible() {
        let (sut, spy) = makeSUT()
        sut.presentCompleteTour(.init(reachedFinalStep: true))
        XCTAssertFalse(spy.completeVM?.isVisible ?? true)
    }

    // MARK: - presentResetTour

    func test_presentResetTour_notVisible() {
        let (sut, spy) = makeSUT()
        sut.presentResetTour(.init())
        XCTAssertFalse(spy.resetVM?.isVisible ?? true)
    }

    // MARK: - presentAutoAdvance

    func test_presentAutoAdvance_advanced_isVisible() {
        let (sut, spy) = makeSUT()
        let steps = [makeStep(id: "s0"), makeStep(id: "s1"), makeStep(id: "s2")]
        sut.presentAutoAdvance(.init(kind: .advanced, steps: steps, newIndex: 2))
        XCTAssertTrue(spy.autoAdvanceVM?.isVisible == true)
        XCTAssertTrue(spy.autoAdvanceVM?.isLastStep == true)
    }

    func test_presentAutoAdvance_completed_notVisible() {
        let (sut, spy) = makeSUT()
        let steps = [makeStep(id: "s0"), makeStep(id: "s1")]
        sut.presentAutoAdvance(.init(kind: .completed, steps: steps, newIndex: nil))
        XCTAssertFalse(spy.autoAdvanceVM?.isVisible ?? true)
        XCTAssertEqual(spy.autoAdvanceVM?.progressFraction ?? 0, 1.0, accuracy: 0.01)
    }

    func test_presentAutoAdvance_stale_displayNotCalled() {
        let (sut, spy) = makeSUT()
        let steps = [makeStep()]
        sut.presentAutoAdvance(.init(kind: .stale, steps: steps, newIndex: nil))
        XCTAssertNil(spy.autoAdvanceVM)
    }

    // MARK: - progressFraction edge cases

    func test_progressFraction_midStep_correct() {
        let (sut, spy) = makeSUT()
        let steps = [makeStep(id: "s0"), makeStep(id: "s1"), makeStep(id: "s2"), makeStep(id: "s3")]
        sut.presentLoadTour(.init(kind: .started, steps: steps, initialIndex: 1))
        // (1+1)/4 = 0.5
        XCTAssertEqual(spy.loadVM?.progressFraction ?? 0, 0.5, accuracy: 0.01)
    }
}
