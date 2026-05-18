@testable import HappySpeech
import XCTest

// MARK: - Spy DisplayLogic

@MainActor
private final class SpyBreatheDisplay: BreatheAndSpeakDisplayLogic, @unchecked Sendable {
    var startVM: BreatheAndSpeakModels.Start.ViewModel?
    var advanceVM: BreatheAndSpeakModels.Advance.ViewModel?

    func displayStart(viewModel: BreatheAndSpeakModels.Start.ViewModel) async {
        startVM = viewModel
    }
    func displayAdvance(viewModel: BreatheAndSpeakModels.Advance.ViewModel) async {
        advanceVM = viewModel
    }
}

// MARK: - Helpers

private func makeExercise(
    _ id: String,
    _ kind: ExerciseKind = .articulation
) -> ComplexExercise {
    .init(id: id, kind: kind, name: "Поза \(id)",
          instruction: "Сделай позу \(id)", symbolName: "tongue", holdSeconds: 4)
}

private func makeComplex() -> ArticulationComplex {
    .init(id: "cx", soundGroup: "Р", title: "Комплекс для Р",
          exercises: [
            makeExercise("e0"),
            makeExercise("e1"),
            makeExercise("e2", .breathing)
          ])
}

// MARK: - Presenter Tests

@MainActor
final class BreatheAndSpeakPresenterTests: XCTestCase {

    private func makeSUT() -> (BreatheAndSpeakPresenter, SpyBreatheDisplay) {
        let display = SpyBreatheDisplay()
        let sut = BreatheAndSpeakPresenter(displayLogic: display)
        return (sut, display)
    }

    func test_presentStart_buildsViewModelWithFirstStep() async {
        let (sut, display) = makeSUT()
        await sut.presentStart(response: .init(complex: makeComplex()))
        XCTAssertNotNil(display.startVM)
        XCTAssertEqual(display.startVM?.totalSteps, 3)
        XCTAssertEqual(display.startVM?.firstStep.id, "e0")
        XCTAssertEqual(display.startVM?.complexTitle, "Комплекс для Р")
        XCTAssertEqual(display.startVM?.firstStep.holdSeconds, 4)
    }

    func test_presentStart_firstStep_hasNonEmptyA11yLabel() async {
        let (sut, display) = makeSUT()
        await sut.presentStart(response: .init(complex: makeComplex()))
        XCTAssertFalse(display.startVM?.firstStep.accessibilityLabel.isEmpty ?? true)
    }

    func test_presentAdvance_notFinished_providesNextStep() async {
        let (sut, display) = makeSUT()
        await sut.presentAdvance(response: .init(
            isFinished: false,
            nextStep: makeExercise("e1"),
            nextStepIndex: 1,
            completedSteps: 1,
            totalSteps: 3
        ))
        XCTAssertEqual(display.advanceVM?.isFinished, false)
        XCTAssertNotNil(display.advanceVM?.nextStep)
        XCTAssertEqual(display.advanceVM?.nextStep?.id, "e1")
        XCTAssertNil(display.advanceVM?.summary)
    }

    func test_presentAdvance_finished_buildsSummary() async {
        let (sut, display) = makeSUT()
        await sut.presentAdvance(response: .init(
            isFinished: true,
            nextStep: nil,
            nextStepIndex: nil,
            completedSteps: 3,
            totalSteps: 3
        ))
        XCTAssertEqual(display.advanceVM?.isFinished, true)
        XCTAssertNotNil(display.advanceVM?.summary)
        XCTAssertEqual(display.advanceVM?.summary?.completedSteps, 3)
        XCTAssertFalse(display.advanceVM?.summary?.encouragement.isEmpty ?? true)
    }

    func test_makeStepVM_progressFractionReflectsIndex() {
        let vm = BreatheAndSpeakPresenter.makeStepVM(
            makeExercise("e1"), index: 1, total: 4
        )
        XCTAssertEqual(vm.progressFraction, 0.5, accuracy: 0.001)
        XCTAssertFalse(vm.stepLabel.isEmpty)
    }

    func test_makeStepVM_breathingKind_isPreserved() {
        let vm = BreatheAndSpeakPresenter.makeStepVM(
            makeExercise("e2", .breathing), index: 2, total: 3
        )
        XCTAssertEqual(vm.kind, .breathing)
    }
}
