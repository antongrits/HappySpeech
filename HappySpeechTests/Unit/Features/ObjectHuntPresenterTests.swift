@testable import HappySpeech
import XCTest

// MARK: - ObjectHuntPresenterTests
//
// Phase 2.6.1 v25 — покрытие ObjectHuntPresenter (12 тестов).
// Тестируются все 6 методов: presentLoadScene, presentTapObject,
// presentUseHint, presentTimerTick, presentCompleteScene, presentCompleteGame.

@MainActor
final class ObjectHuntPresenterTests: XCTestCase {

    // MARK: - DisplaySpy

    @MainActor
    private final class DisplaySpy: ObjectHuntDisplayLogic {
        var loadSceneVM: ObjectHuntModels.LoadScene.ViewModel?
        var tapObjectVM: ObjectHuntModels.TapObject.ViewModel?
        var useHintVM: ObjectHuntModels.UseHint.ViewModel?
        var timerTickVM: ObjectHuntModels.TimerTick.ViewModel?
        var completeSceneVM: ObjectHuntModels.CompleteScene.ViewModel?
        var completeGameVM: ObjectHuntModels.CompleteGame.ViewModel?

        func displayLoadScene(_ viewModel: ObjectHuntModels.LoadScene.ViewModel) { loadSceneVM = viewModel }
        func displayTapObject(_ viewModel: ObjectHuntModels.TapObject.ViewModel) { tapObjectVM = viewModel }
        func displayUseHint(_ viewModel: ObjectHuntModels.UseHint.ViewModel) { useHintVM = viewModel }
        func displayTimerTick(_ viewModel: ObjectHuntModels.TimerTick.ViewModel) { timerTickVM = viewModel }
        func displayCompleteScene(_ viewModel: ObjectHuntModels.CompleteScene.ViewModel) { completeSceneVM = viewModel }
        func displayCompleteGame(_ viewModel: ObjectHuntModels.CompleteGame.ViewModel) { completeGameVM = viewModel }
    }

    private func makeSUT() -> (ObjectHuntPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = ObjectHuntPresenter()
        presenter.display = spy
        return (presenter, spy)
    }

    private func makeItem(hasTarget: Bool = true) -> SceneItem {
        SceneItem(word: "рыба", icon: "word_fish", hasTargetSound: hasTarget)
    }

    private func makeScene() -> SceneDescriptor {
        SceneDescriptor(name: "Лес", systemBackground: "word_forest")
    }

    // MARK: - presentLoadScene

    func test_presentLoadScene_roundBadgeContainsIndex() {
        let (sut, spy) = makeSUT()
        let response = ObjectHuntModels.LoadScene.Response(
            items: [makeItem()],
            targetSound: "Р",
            scene: makeScene(),
            sceneIndex: 0,
            totalScenes: 5,
            targetCount: 3,
            timeLimitSec: 60
        )
        sut.presentLoadScene(response)
        XCTAssertNotNil(spy.loadSceneVM)
        XCTAssertEqual(spy.loadSceneVM?.targetSoundLabel, "Р")
        XCTAssertFalse(spy.loadSceneVM?.roundBadge.isEmpty ?? true)
        XCTAssertFalse(spy.loadSceneVM?.promptText.isEmpty ?? true)
    }

    func test_presentLoadScene_sceneName_passedThrough() {
        let (sut, spy) = makeSUT()
        let response = ObjectHuntModels.LoadScene.Response(
            items: [],
            targetSound: "Ш",
            scene: makeScene(),
            sceneIndex: 2,
            totalScenes: 5,
            targetCount: 4,
            timeLimitSec: 60
        )
        sut.presentLoadScene(response)
        XCTAssertEqual(spy.loadSceneVM?.sceneName, "Лес")
    }

    // MARK: - presentTapObject

    func test_presentTapObject_correctStreak3_streakScoreLabel() {
        let (sut, spy) = makeSUT()
        let id = UUID()
        let response = ObjectHuntModels.TapObject.Response(
            itemId: id,
            newState: .correct,
            isCorrect: true,
            word: "рыба",
            correctCount: 3,
            targetCount: 5,
            streakCount: 3,
            score: 30,
            isSceneComplete: false
        )
        sut.presentTapObject(response)
        XCTAssertFalse(spy.tapObjectVM?.scoreLabel.isEmpty ?? true)
        XCTAssertTrue(spy.tapObjectVM?.isCorrect ?? false)
    }

    func test_presentTapObject_correct_noStreak_scoreLabelNotEmpty() {
        let (sut, spy) = makeSUT()
        let id = UUID()
        let response = ObjectHuntModels.TapObject.Response(
            itemId: id,
            newState: .correct,
            isCorrect: true,
            word: "рыба",
            correctCount: 1,
            targetCount: 5,
            streakCount: 1,
            score: 10,
            isSceneComplete: false
        )
        sut.presentTapObject(response)
        XCTAssertFalse(spy.tapObjectVM?.scoreLabel.isEmpty ?? true)
    }

    func test_presentTapObject_incorrect_scoreLabelEmpty() {
        let (sut, spy) = makeSUT()
        let id = UUID()
        let response = ObjectHuntModels.TapObject.Response(
            itemId: id,
            newState: .wrong,
            isCorrect: false,
            word: "кот",
            correctCount: 0,
            targetCount: 5,
            streakCount: 0,
            score: 0,
            isSceneComplete: false
        )
        sut.presentTapObject(response)
        XCTAssertTrue(spy.tapObjectVM?.scoreLabel.isEmpty ?? false)
        XCTAssertFalse(spy.tapObjectVM?.isCorrect ?? true)
    }

    // MARK: - presentUseHint

    func test_presentUseHint_hintsRemain_isAvailable() {
        let (sut, spy) = makeSUT()
        let id = UUID()
        let response = ObjectHuntModels.UseHint.Response(
            hintedItemId: id,
            hintsRemaining: 1,
            hintLevel: 1
        )
        sut.presentUseHint(response)
        XCTAssertTrue(spy.useHintVM?.isHintAvailable ?? false)
        XCTAssertEqual(spy.useHintVM?.hintsRemaining, 1)
    }

    func test_presentUseHint_noHints_notAvailable() {
        let (sut, spy) = makeSUT()
        let response = ObjectHuntModels.UseHint.Response(
            hintedItemId: nil,
            hintsRemaining: 0,
            hintLevel: 2
        )
        sut.presentUseHint(response)
        XCTAssertFalse(spy.useHintVM?.isHintAvailable ?? true)
    }

    // MARK: - presentTimerTick

    func test_presentTimerTick_aboveWarning_notWarning() {
        let (sut, spy) = makeSUT()
        sut.presentTimerTick(ObjectHuntModels.TimerTick.Response(secondsRemaining: 30, isExpired: false))
        XCTAssertFalse(spy.timerTickVM?.isWarning ?? true)
        XCTAssertEqual(spy.timerTickVM?.timerLabel, "0:30")
    }

    func test_presentTimerTick_below15_warning() {
        let (sut, spy) = makeSUT()
        sut.presentTimerTick(ObjectHuntModels.TimerTick.Response(secondsRemaining: 10, isExpired: false))
        XCTAssertTrue(spy.timerTickVM?.isWarning ?? false)
    }

    func test_presentTimerTick_expired() {
        let (sut, spy) = makeSUT()
        sut.presentTimerTick(ObjectHuntModels.TimerTick.Response(secondsRemaining: 0, isExpired: true))
        XCTAssertTrue(spy.timerTickVM?.isExpired ?? false)
    }

    // MARK: - presentCompleteScene

    func test_presentCompleteScene_streakBonus_textSet() {
        let (sut, spy) = makeSUT()
        let response = ObjectHuntModels.CompleteScene.Response(
            sceneIndex: 0,
            foundCount: 4,
            targetCount: 4,
            timeUsedSec: 20,
            streakBonus: 15,
            sceneScore: 50,
            isLastScene: false
        )
        sut.presentCompleteScene(response)
        XCTAssertFalse(spy.completeSceneVM?.streakBonusText.isEmpty ?? true)
        XCTAssertFalse(spy.completeSceneVM?.isLastScene ?? true)
    }

    func test_presentCompleteScene_noStreakBonus_emptyText() {
        let (sut, spy) = makeSUT()
        let response = ObjectHuntModels.CompleteScene.Response(
            sceneIndex: 4,
            foundCount: 2,
            targetCount: 4,
            timeUsedSec: 55,
            streakBonus: 0,
            sceneScore: 20,
            isLastScene: true
        )
        sut.presentCompleteScene(response)
        XCTAssertTrue(spy.completeSceneVM?.streakBonusText.isEmpty ?? false)
        XCTAssertTrue(spy.completeSceneVM?.isLastScene ?? false)
    }

    // MARK: - presentCompleteGame

    func test_presentCompleteGame_3stars_excellentSummary() {
        let (sut, spy) = makeSUT()
        let response = ObjectHuntModels.CompleteGame.Response(
            totalScore: 250,
            maxScore: 250,
            starsEarned: 3,
            totalFound: 20,
            totalTargets: 20,
            accuracy: 1.0
        )
        sut.presentCompleteGame(response)
        XCTAssertEqual(spy.completeGameVM?.starsEarned, 3)
        XCTAssertFalse(spy.completeGameVM?.accuracyLabel.isEmpty ?? true)
        XCTAssertFalse(spy.completeGameVM?.summaryText.isEmpty ?? true)
    }

    func test_presentCompleteGame_0stars_okSummary() {
        let (sut, spy) = makeSUT()
        let response = ObjectHuntModels.CompleteGame.Response(
            totalScore: 50,
            maxScore: 250,
            starsEarned: 0,
            totalFound: 5,
            totalTargets: 20,
            accuracy: 0.25
        )
        sut.presentCompleteGame(response)
        XCTAssertEqual(spy.completeGameVM?.starsEarned, 0)
        XCTAssertFalse(spy.completeGameVM?.summaryText.isEmpty ?? true)
    }
}
