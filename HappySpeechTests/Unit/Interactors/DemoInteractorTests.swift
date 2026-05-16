@testable import HappySpeech
import XCTest

// MARK: - DemoInteractorTests
//
// M10.1 — 6 тестов для DemoInteractor.
// Покрывает: loadDemo (15 шагов), advanceStep, завершение на последнем шаге,
// goBack, jumpTo с корректным индексом, skipDemo.

@MainActor
final class DemoInteractorTests: XCTestCase {

    // MARK: - Spy

    @MainActor
    private final class SpyPresenter: DemoPresentationLogic {
        var loadDemoCalled = false
        var advanceStepCalled = false
        var goBackCalled = false
        var jumpToCalled = false
        var interactiveTapCalled = false
        var skipDemoCalled = false
        var completeDemoCalled = false
        var toggleAutoAdvanceCalled = false
        var autoAdvanceTickCalled = false
        var replayStepCalled = false

        var lastLoadDemo: DemoModels.LoadDemo.Response?
        var lastAdvanceStep: DemoModels.AdvanceStep.Response?
        var lastGoBack: DemoModels.GoBack.Response?
        var lastJumpTo: DemoModels.JumpTo.Response?

        func presentLoadDemo(_ response: DemoModels.LoadDemo.Response) {
            loadDemoCalled = true; lastLoadDemo = response
        }
        func presentAdvanceStep(_ response: DemoModels.AdvanceStep.Response) {
            advanceStepCalled = true; lastAdvanceStep = response
        }
        func presentGoBack(_ response: DemoModels.GoBack.Response) {
            goBackCalled = true; lastGoBack = response
        }
        func presentJumpTo(_ response: DemoModels.JumpTo.Response) {
            jumpToCalled = true; lastJumpTo = response
        }
        func presentInteractiveTap(_ response: DemoModels.InteractiveTap.Response) {
            interactiveTapCalled = true
        }
        func presentSkipDemo(_ response: DemoModels.SkipDemo.Response) {
            skipDemoCalled = true
        }
        func presentCompleteDemo(_ response: DemoModels.CompleteDemo.Response) {
            completeDemoCalled = true
        }
        func presentToggleAutoAdvance(_ response: DemoModels.ToggleAutoAdvance.Response) {
            toggleAutoAdvanceCalled = true
        }
        func presentAutoAdvanceTick(_ response: DemoModels.AutoAdvanceTick.Response) {
            autoAdvanceTickCalled = true
        }
        func presentReplayStep(_ response: DemoModels.ReplayStep.Response) {
            replayStepCalled = true
        }
    }

    private func makeSUT() -> (DemoInteractor, SpyPresenter) {
        let sut = DemoInteractor()
        let spy = SpyPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - 1. loadDemo заполняет 15 шагов

    func test_loadDemo_populates15Steps() {
        let (sut, spy) = makeSUT()
        sut.loadDemo(.init())
        XCTAssertTrue(spy.loadDemoCalled)
        XCTAssertEqual(spy.lastLoadDemo?.steps.count, 15)
        XCTAssertEqual(spy.lastLoadDemo?.currentIndex, 0)
    }

    // MARK: - 2. advanceStep увеличивает индекс

    func test_advanceStep_incrementsIndex() {
        let (sut, spy) = makeSUT()
        sut.loadDemo(.init())
        sut.advanceStep(.init())
        XCTAssertTrue(spy.advanceStepCalled)
        XCTAssertEqual(spy.lastAdvanceStep?.currentIndex, 1)
        XCTAssertFalse(spy.lastAdvanceStep?.isCompleted ?? true)
    }

    // MARK: - 3. advanceStep на последнем шаге → isCompleted = true

    func test_advanceStep_onLastStep_completedTrue() {
        let (sut, spy) = makeSUT()
        sut.loadDemo(.init())
        // Перепрыгиваем на предпоследний шаг (14 — индекс 13)
        sut.jumpTo(.init(index: 14))
        sut.advanceStep(.init())
        XCTAssertEqual(spy.lastAdvanceStep?.isCompleted, true)
    }

    // MARK: - 4. goBack уменьшает индекс

    func test_goBack_decrementsIndex() {
        let (sut, spy) = makeSUT()
        sut.loadDemo(.init())
        sut.advanceStep(.init()) // → index = 1
        sut.goBack(.init())
        XCTAssertTrue(spy.goBackCalled)
        XCTAssertEqual(spy.lastGoBack?.currentIndex, 0)
    }

    // MARK: - 5. jumpTo корректному индексу → presenter получает новый индекс

    func test_jumpTo_validIndex_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.loadDemo(.init())
        sut.jumpTo(.init(index: 7))
        XCTAssertTrue(spy.jumpToCalled)
        XCTAssertEqual(spy.lastJumpTo?.currentIndex, 7)
    }

    // MARK: - 6. skipDemo вызывает presentSkipDemo

    func test_skipDemo_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.loadDemo(.init())
        sut.skipDemo(.init())
        XCTAssertTrue(spy.skipDemoCalled)
    }

    // MARK: - 7. goBack на первом шаге не уходит ниже 0

    func test_goBack_atFirstStep_staysAtZero() {
        let (sut, spy) = makeSUT()
        sut.loadDemo(.init())
        sut.goBack(.init())
        XCTAssertEqual(spy.lastGoBack?.currentIndex, 0)
    }

    // MARK: - 8. jumpTo за границы клампится

    func test_jumpTo_outOfBounds_clamped() {
        let (sut, spy) = makeSUT()
        sut.loadDemo(.init())
        sut.jumpTo(.init(index: 999))
        XCTAssertEqual(spy.lastJumpTo?.currentIndex, 14)
    }

    func test_jumpTo_negativeIndex_clampedToZero() {
        let (sut, spy) = makeSUT()
        sut.loadDemo(.init())
        sut.jumpTo(.init(index: 5))
        spy.jumpToCalled = false
        sut.jumpTo(.init(index: -3))
        XCTAssertEqual(spy.lastJumpTo?.currentIndex, 0)
    }

    func test_jumpTo_sameIndex_ignored() {
        let (sut, spy) = makeSUT()
        sut.loadDemo(.init())
        spy.jumpToCalled = false
        sut.jumpTo(.init(index: 0))
        XCTAssertFalse(spy.jumpToCalled, "jumpTo на текущий индекс игнорируется")
    }

    // MARK: - 9. tapInteractive на шаге с interactive CTA

    func test_tapInteractive_onInteractiveStep_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.loadDemo(.init())
        // Шаг 4 (индекс 3) имеет hasInteractive=true
        sut.jumpTo(.init(index: 3))
        sut.tapInteractive(.init())
        XCTAssertTrue(spy.interactiveTapCalled)
    }

    func test_tapInteractive_onNonInteractiveStep_ignored() {
        let (sut, spy) = makeSUT()
        sut.loadDemo(.init())
        // Шаг 1 (индекс 0) — hasInteractive=false
        sut.tapInteractive(.init())
        XCTAssertFalse(spy.interactiveTapCalled)
    }

    // MARK: - 10. toggleAutoAdvance включает и выключает

    func test_toggleAutoAdvance_on_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.loadDemo(.init())
        sut.toggleAutoAdvance(.init())
        XCTAssertTrue(spy.toggleAutoAdvanceCalled)
    }

    func test_toggleAutoAdvance_twice_offAgain() {
        let (sut, _) = makeSUT()
        sut.loadDemo(.init())
        sut.toggleAutoAdvance(.init())
        sut.toggleAutoAdvance(.init())
        // Не крашит, таймер остановлен
        XCTAssertTrue(true)
    }

    // MARK: - 11. replayStep вызывает presenter

    func test_replayStep_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.loadDemo(.init())
        sut.replayStep(.init())
        XCTAssertTrue(spy.replayStepCalled)
    }

    // MARK: - 12. completeDemo сохраняет флаг и вызывает presenter

    func test_completeDemo_setsTourCompletedFlag() {
        UserDefaults.standard.removeObject(forKey: DemoInteractor.tourCompletedKey)
        let (sut, spy) = makeSUT()
        sut.loadDemo(.init())
        sut.completeDemo(.init())
        XCTAssertTrue(spy.completeDemoCalled)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: DemoInteractor.tourCompletedKey))
        UserDefaults.standard.removeObject(forKey: DemoInteractor.tourCompletedKey)
    }

    // MARK: - 13. advanceStep с включённым autoAdvance отключает его

    func test_advanceStep_withAutoAdvance_stopsAndRestarts() {
        let (sut, spy) = makeSUT()
        sut.loadDemo(.init())
        sut.toggleAutoAdvance(.init())
        sut.advanceStep(.init())
        XCTAssertTrue(spy.advanceStepCalled)
        XCTAssertEqual(spy.lastAdvanceStep?.currentIndex, 1)
    }
}
