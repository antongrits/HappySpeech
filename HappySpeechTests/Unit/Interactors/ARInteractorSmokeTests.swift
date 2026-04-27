@testable import HappySpeech
import XCTest

// MARK: - ARInteractorSmokeTests
//
// M10.1 Tier 2 — Smoke-тесты для AR-зависимых Interactor'ов.
// Стратегия: тестируем только не-ARKit методы (init, loadGames, selectGame,
// startGame, loadSession, advanceToNextExercise).
//
// Explained gaps:
//   - ARMirrorInteractor.updateFrame(_:) — требует CVPixelBuffer + ARKit face tracking
//   - ARStoryQuestInteractor.processFrame(_:) — аналогично
//   - BreathingARInteractor.*AR* методы — требуют ARFaceAnchor
//   - ButterflyCatchInteractor, HoldThePoseInteractor, MimicLyalyaInteractor,
//     PoseSequenceInteractor, SoundAndFaceInteractor — ARKit-dependent updateFrame
//   - Все эти классы не имеют тестируемой бизнес-логики без ARKit сессии.

// MARK: - ARZoneInteractor Smoke Tests

@MainActor
final class ARZoneInteractorSmokeTests: XCTestCase {

    @MainActor
    private final class SpyPresenter: ARZonePresentationLogic {
        var loadGamesCalled = false
        var selectGameCalled = false
        var dismissTutorialCalled = false
        var selectFallbackCalled = false
        var refreshPlannerAdviceCalled = false

        func presentLoadGames(_ response: ARZoneModels.LoadGames.Response) {
            loadGamesCalled = true
        }
        func presentSelectGame(_ response: ARZoneModels.SelectGame.Response) {
            selectGameCalled = true
        }
        func presentSelectFallback(_ response: ARZoneModels.SelectFallback.Response) {
            selectFallbackCalled = true
        }
        func presentDismissTutorial(_ response: ARZoneModels.DismissTutorial.Response) {
            dismissTutorialCalled = true
        }
        func presentRefreshPlannerAdvice(_ response: ARZoneModels.RefreshPlannerAdvice.Response) {
            refreshPlannerAdviceCalled = true
        }
    }

    private func makeSUT() -> (ARZoneInteractor, SpyPresenter) {
        let sut = ARZoneInteractor()
        let spy = SpyPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - 1. loadGames заполняет каталог игр

    func test_loadGames_populatesGames() {
        let (sut, spy) = makeSUT()
        sut.loadGames(.init(childId: "child-1"))
        XCTAssertTrue(spy.loadGamesCalled)
    }

    // MARK: - 2. selectGame с корректным gameId → presenter вызван

    func test_selectGame_validId_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.loadGames(.init(childId: "child-1"))
        // Используем первую игру из каталога.
        let firstGameId = ARGameCatalog.all.first?.id ?? "ar-mirror"
        sut.selectGame(.init(gameId: firstGameId, skipTutorial: true))
        XCTAssertTrue(spy.selectGameCalled)
    }

    // MARK: - 3. dismissTutorial вызывает presenter

    func test_dismissTutorial_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.dismissTutorial(.init(destination: .arMirror, action: .start))
        XCTAssertTrue(spy.dismissTutorialCalled)
    }
}

// MARK: - ARMirrorInteractor Smoke Tests

@MainActor
final class ARMirrorInteractorSmokeTests: XCTestCase {

    @MainActor
    private final class SpyPresenter: ARMirrorPresentationLogic {
        var startGameCalled = false
        var updateFrameCalled = false
        var scoreAttemptCalled = false

        var lastStartGameResponse: ARMirrorModels.StartGame.Response?

        func presentStartGame(_ response: ARMirrorModels.StartGame.Response) {
            startGameCalled = true; lastStartGameResponse = response
        }
        func presentUpdateFrame(_ response: ARMirrorModels.UpdateFrame.Response) {
            updateFrameCalled = true
        }
        func presentScoreAttempt(_ response: ARMirrorModels.ScoreAttempt.Response) {
            scoreAttemptCalled = true
        }
    }

    private func makeSUT() -> (ARMirrorInteractor, SpyPresenter) {
        let sut = ARMirrorInteractor()
        let spy = SpyPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - 4. startGame → presenter вызван с упражнениями

    func test_startGame_populatesExercises() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init())
        XCTAssertTrue(spy.startGameCalled)
        XCTAssertEqual(spy.lastStartGameResponse?.currentIndex, 0)
        XCTAssertFalse(spy.lastStartGameResponse?.exercises.isEmpty ?? true)
    }

    // MARK: - 5. advanceToNextExercise после startGame — не крашится

    func test_advanceToNextExercise_afterStart_doesNotCrash() {
        let (sut, _) = makeSUT()
        sut.startGame(.init())
        XCTAssertNoThrow(sut.advanceToNextExercise())
    }

    // MARK: - 6. startGame дважды подряд — сбрасывает на первое упражнение

    func test_startGame_calledTwice_resetsToFirstExercise() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init())
        sut.advanceToNextExercise()
        sut.startGame(.init())
        XCTAssertEqual(spy.lastStartGameResponse?.currentIndex, 0)
    }
}

// MARK: - ArticulationImitationInteractor Smoke Tests

@MainActor
final class ArticulationImitationInteractorSmokeTests: XCTestCase {

    @MainActor
    private final class SpyPresenter: ArticulationImitationPresentationLogic {
        var loadSessionCalled = false
        var startExerciseCalled = false
        var holdProgressCalled = false
        var completeExerciseCalled = false
        var sessionCompleteCalled = false

        var lastLoadSession: ArticulationImitationModels.LoadSession.Response?

        func presentLoadSession(_ response: ArticulationImitationModels.LoadSession.Response) {
            loadSessionCalled = true; lastLoadSession = response
        }
        func presentStartExercise(_ response: ArticulationImitationModels.StartExercise.Response) {
            startExerciseCalled = true
        }
        func presentHoldProgress(_ response: ArticulationImitationModels.HoldProgress.Response) {
            holdProgressCalled = true
        }
        func presentCompleteExercise(_ response: ArticulationImitationModels.CompleteExercise.Response) {
            completeExerciseCalled = true
        }
        func presentSessionComplete(_ response: ArticulationImitationModels.SessionComplete.Response) {
            sessionCompleteCalled = true
        }
    }

    private func makeSUT() -> (ArticulationImitationInteractor, SpyPresenter) {
        let sut = ArticulationImitationInteractor()
        let spy = SpyPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - 7. loadSession → presenter вызван с упражнениями

    func test_loadSession_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "С", childName: "Маша"))
        XCTAssertTrue(spy.loadSessionCalled)
        XCTAssertFalse(spy.lastLoadSession?.exercises.isEmpty ?? true)
    }

    // MARK: - 8. cancel после loadSession не крашится

    func test_cancel_afterLoadSession_doesNotCrash() {
        let (sut, _) = makeSUT()
        sut.loadSession(.init(soundGroup: "Р", childName: "Ваня"))
        XCTAssertNoThrow(sut.cancel())
    }

    // MARK: - 9. completeSession без loadSession — не крашится

    func test_completeSession_withoutLoad_doesNotCrash() {
        let (sut, _) = makeSUT()
        XCTAssertNoThrow(sut.completeSession())
    }
}
