@testable import HappySpeech
import XCTest

// MARK: - SortingPresenterTests
//
// Phase 2.6.1 v25 — покрытие SortingPresenter (13 тестов).
// Тестируются все 7 методов: presentLoadSession, presentClassifyWord,
// presentHint, presentAutoPlace, presentStreakBonus, presentTimerTick,
// presentCompleteSession.

@MainActor
final class SortingPresenterTests: XCTestCase {

    // MARK: - DisplaySpy

    @MainActor
    private final class DisplaySpy: SortingDisplayLogic {
        var loadSessionVM: SortingModels.LoadSession.ViewModel?
        var classifyWordVM: SortingModels.ClassifyWord.ViewModel?
        var hintVM: SortingModels.RequestHint.ViewModel?
        var autoPlaceVM: SortingModels.AutoPlace.ViewModel?
        var streakBonusVM: SortingModels.StreakBonus.ViewModel?
        var timerTickVM: SortingModels.TimerTick.ViewModel?
        var completeSessionVM: SortingModels.CompleteSession.ViewModel?

        func displayLoadSession(_ viewModel: SortingModels.LoadSession.ViewModel) { loadSessionVM = viewModel }
        func displayClassifyWord(_ viewModel: SortingModels.ClassifyWord.ViewModel) { classifyWordVM = viewModel }
        func displayHint(_ viewModel: SortingModels.RequestHint.ViewModel) { hintVM = viewModel }
        func displayAutoPlace(_ viewModel: SortingModels.AutoPlace.ViewModel) { autoPlaceVM = viewModel }
        func displayStreakBonus(_ viewModel: SortingModels.StreakBonus.ViewModel) { streakBonusVM = viewModel }
        func displayTimerTick(_ viewModel: SortingModels.TimerTick.ViewModel) { timerTickVM = viewModel }
        func displayCompleteSession(_ viewModel: SortingModels.CompleteSession.ViewModel) { completeSessionVM = viewModel }
    }

    private func makeSUT() -> (SortingPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = SortingPresenter()
        presenter.viewModel = spy
        return (presenter, spy)
    }

    // MARK: - presentLoadSession

    func test_presentLoadSession_withName_greetingContainsName() {
        let (sut, spy) = makeSUT()
        let response = SortingModels.LoadSession.Response(
            setTitle: "Звук С",
            taskType: .firstSound,
            taskDescription: "Разложи слова",
            words: [],
            categories: [],
            childName: "Боря",
            timeLimit: 0
        )
        sut.presentLoadSession(response)
        XCTAssertTrue(spy.loadSessionVM?.greeting.contains("Боря") ?? false)
    }

    func test_presentLoadSession_emptyName_usesTaskDescription() {
        let (sut, spy) = makeSUT()
        let response = SortingModels.LoadSession.Response(
            setTitle: "Звуки",
            taskType: .firstSound,
            taskDescription: "Разложи по корзинам",
            words: [],
            categories: [],
            childName: "",
            timeLimit: 0
        )
        sut.presentLoadSession(response)
        XCTAssertFalse(spy.loadSessionVM?.greeting.isEmpty ?? true)
        XCTAssertTrue(spy.loadSessionVM?.greeting.contains("Разложи по корзинам") ?? false)
    }

    // MARK: - presentClassifyWord

    func test_presentClassifyWord_correct_normalFeedback() {
        let (sut, spy) = makeSUT()
        let response = SortingModels.ClassifyWord.Response(
            correct: true,
            wordId: "w-1",
            categoryId: "cat-1",
            streak: 1,
            streakBonusTriggered: false,
            feedback: "Верно!",
            remainingCount: 5
        )
        sut.presentClassifyWord(response)
        XCTAssertTrue(spy.classifyWordVM?.correct ?? false)
        XCTAssertEqual(spy.classifyWordVM?.feedbackText, "Верно!")
    }

    func test_presentClassifyWord_correctStreakBonus_overridesFeedback() {
        let (sut, spy) = makeSUT()
        let response = SortingModels.ClassifyWord.Response(
            correct: true,
            wordId: "w-2",
            categoryId: "cat-1",
            streak: 3,
            streakBonusTriggered: true,
            feedback: "Молодец!",
            remainingCount: 4
        )
        sut.presentClassifyWord(response)
        XCTAssertTrue(spy.classifyWordVM?.streakBadgeVisible ?? false)
        XCTAssertFalse(spy.classifyWordVM?.feedbackText == "Молодец!")
    }

    func test_presentClassifyWord_incorrect_feedbackPassedThrough() {
        let (sut, spy) = makeSUT()
        let response = SortingModels.ClassifyWord.Response(
            correct: false,
            wordId: "w-3",
            categoryId: "cat-2",
            streak: 0,
            streakBonusTriggered: false,
            feedback: "Попробуй ещё!",
            remainingCount: 3
        )
        sut.presentClassifyWord(response)
        XCTAssertFalse(spy.classifyWordVM?.correct ?? true)
        XCTAssertEqual(spy.classifyWordVM?.feedbackText, "Попробуй ещё!")
    }

    // MARK: - presentHint

    func test_presentHint_level1_passesHintText() {
        let (sut, spy) = makeSUT()
        let response = SortingModels.RequestHint.Response(
            wordId: "w-1",
            hintLevel: 1,
            highlightCategoryId: "cat-1",
            hintText: "Смотри на первую букву",
            isAutoPlace: false
        )
        sut.presentHint(response)
        XCTAssertEqual(spy.hintVM?.hintText, "Смотри на первую букву")
        XCTAssertFalse(spy.hintVM?.isAutoPlace ?? true)
    }

    func test_presentHint_levelDefault_autoPlaceMessage() {
        let (sut, spy) = makeSUT()
        let response = SortingModels.RequestHint.Response(
            wordId: "w-1",
            hintLevel: 3,
            highlightCategoryId: "",
            hintText: "",
            isAutoPlace: true
        )
        sut.presentHint(response)
        XCTAssertFalse(spy.hintVM?.hintText.isEmpty ?? true)
        XCTAssertTrue(spy.hintVM?.isAutoPlace ?? false)
    }

    // MARK: - presentAutoPlace

    func test_presentAutoPlace_passesThrough() {
        let (sut, spy) = makeSUT()
        let response = SortingModels.AutoPlace.Response(wordId: "w-1", categoryId: "cat-1")
        sut.presentAutoPlace(response)
        XCTAssertEqual(spy.autoPlaceVM?.wordId, "w-1")
        XCTAssertEqual(spy.autoPlaceVM?.categoryId, "cat-1")
    }

    // MARK: - presentStreakBonus

    func test_presentStreakBonus_streak3_specialText() {
        let (sut, spy) = makeSUT()
        sut.presentStreakBonus(SortingModels.StreakBonus.Response(streak: 3))
        XCTAssertFalse(spy.streakBonusVM?.bonusText.isEmpty ?? true)
        XCTAssertEqual(spy.streakBonusVM?.streak, 3)
    }

    func test_presentStreakBonus_streak5_superText() {
        let (sut, spy) = makeSUT()
        sut.presentStreakBonus(SortingModels.StreakBonus.Response(streak: 5))
        XCTAssertFalse(spy.streakBonusVM?.bonusText.isEmpty ?? true)
    }

    func test_presentStreakBonus_unknownStreak_defaultText() {
        let (sut, spy) = makeSUT()
        sut.presentStreakBonus(SortingModels.StreakBonus.Response(streak: 10))
        XCTAssertTrue(spy.streakBonusVM?.bonusText.contains("10") ?? false)
    }

    // MARK: - presentTimerTick

    func test_presentTimerTick_above30_green() {
        let (sut, spy) = makeSUT()
        sut.presentTimerTick(SortingModels.TimerTick.Response(remaining: 45, expired: false))
        XCTAssertEqual(spy.timerTickVM?.timerColor, "green")
        XCTAssertEqual(spy.timerTickVM?.timerLabel, "00:45")
    }

    func test_presentTimerTick_orange_range() {
        let (sut, spy) = makeSUT()
        sut.presentTimerTick(SortingModels.TimerTick.Response(remaining: 20, expired: false))
        XCTAssertEqual(spy.timerTickVM?.timerColor, "orange")
    }

    func test_presentTimerTick_red_range() {
        let (sut, spy) = makeSUT()
        sut.presentTimerTick(SortingModels.TimerTick.Response(remaining: 10, expired: false))
        XCTAssertEqual(spy.timerTickVM?.timerColor, "red")
    }

    func test_presentTimerTick_zeroExpired() {
        let (sut, spy) = makeSUT()
        sut.presentTimerTick(SortingModels.TimerTick.Response(remaining: 0, expired: true))
        XCTAssertTrue(spy.timerTickVM?.expired ?? false)
        XCTAssertEqual(spy.timerTickVM?.timerColor, "red")
    }

    // MARK: - presentCompleteSession

    func test_presentCompleteSession_perfectScore_3stars() {
        let (sut, spy) = makeSUT()
        let response = SortingModels.CompleteSession.Response(
            correctCount: 10,
            total: 10,
            humanCorrect: 10,
            humanTotal: 10,
            elapsedSeconds: 30,
            timeLimit: 120,
            bestStreak: 10,
            autoPlacedCount: 0,
            reason: .allClassified,
            finalScore: 1.0,
            categoryBreakdown: [],
            bestCategoryTitle: nil,
            worstCategoryTitle: nil
        )
        sut.presentCompleteSession(response)
        XCTAssertEqual(spy.completeSessionVM?.starsEarned, 3)
        XCTAssertEqual(spy.completeSessionVM?.scoreLabel, "10 / 10")
    }

    func test_presentCompleteSession_timeExpired_message() {
        let (sut, spy) = makeSUT()
        let response = SortingModels.CompleteSession.Response(
            correctCount: 3,
            total: 10,
            humanCorrect: 3,
            humanTotal: 10,
            elapsedSeconds: 120,
            timeLimit: 120,
            bestStreak: 1,
            autoPlacedCount: 0,
            reason: .timeExpired,
            finalScore: 0.2,
            categoryBreakdown: [],
            bestCategoryTitle: nil,
            worstCategoryTitle: nil
        )
        sut.presentCompleteSession(response)
        XCTAssertEqual(spy.completeSessionVM?.starsEarned, 0)
        XCTAssertFalse(spy.completeSessionVM?.message.isEmpty ?? true)
    }

    func test_presentCompleteSession_autoDistributed_message() {
        let (sut, spy) = makeSUT()
        let response = SortingModels.CompleteSession.Response(
            correctCount: 5,
            total: 10,
            humanCorrect: 0,
            humanTotal: 10,
            elapsedSeconds: 90,
            timeLimit: 120,
            bestStreak: 0,
            autoPlacedCount: 5,
            reason: .autoDistributed,
            finalScore: 0.4,
            categoryBreakdown: [],
            bestCategoryTitle: nil,
            worstCategoryTitle: nil
        )
        sut.presentCompleteSession(response)
        XCTAssertFalse(spy.completeSessionVM?.message.isEmpty ?? true)
    }
}
