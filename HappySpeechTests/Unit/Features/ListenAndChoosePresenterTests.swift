@testable import HappySpeech
import XCTest

// MARK: - ListenAndChoosePresenterTests
//
// Block V v18 — покрытие ListenAndChoosePresenter (8 тестов).
// Тестируются оба метода presentationLogic через DisplaySpy.

@MainActor
final class ListenAndChoosePresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: ListenAndChooseDisplayLogic {
        var loadRoundVM: ListenAndChooseModels.LoadRound.ViewModel?
        var submitAttemptVM: ListenAndChooseModels.SubmitAttempt.ViewModel?

        func displayLoadRound(_ viewModel: ListenAndChooseModels.LoadRound.ViewModel) {
            loadRoundVM = viewModel
        }
        func displaySubmitAttempt(_ viewModel: ListenAndChooseModels.SubmitAttempt.ViewModel) {
            submitAttemptVM = viewModel
        }
    }

    private func makeSUT() -> (ListenAndChoosePresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = ListenAndChoosePresenter()
        presenter.display = spy
        return (presenter, spy)
    }

    private func makeOptions() -> [ListenAndChooseModels.LoadRound.OptionItem] {
        [
            ListenAndChooseModels.LoadRound.OptionItem(id: "1", word: "Собака", imageAsset: nil),
            ListenAndChooseModels.LoadRound.OptionItem(id: "2", word: "Кошка", imageAsset: nil),
            ListenAndChooseModels.LoadRound.OptionItem(id: "3", word: "Рыба", imageAsset: nil)
        ]
    }

    // MARK: - presentLoadRound

    func test_presentLoadRound_firstRound_setsNormalInstruction() {
        let (sut, spy) = makeSUT()
        let response = ListenAndChooseModels.LoadRound.Response(
            targetWord: "Собака",
            options: makeOptions(),
            correctIndex: 0,
            audioAsset: nil,
            hint: nil,
            questionNumber: 1,
            totalQuestions: 5,
            isRetry: false
        )
        sut.presentLoadRound(response)
        XCTAssertNotNil(spy.loadRoundVM)
        XCTAssertFalse(spy.loadRoundVM?.instructionText.isEmpty ?? true)
        XCTAssertFalse(spy.loadRoundVM?.isRetry ?? true)
    }

    func test_presentLoadRound_retry_setsRetryInstruction() {
        let (sut, spy) = makeSUT()
        let response = ListenAndChooseModels.LoadRound.Response(
            targetWord: "Кошка",
            options: makeOptions(),
            correctIndex: 1,
            audioAsset: nil,
            isRetry: true
        )
        sut.presentLoadRound(response)
        XCTAssertTrue(spy.loadRoundVM?.isRetry ?? false)
        XCTAssertFalse(spy.loadRoundVM?.instructionText.isEmpty ?? true)
    }

    func test_presentLoadRound_multipleQuestions_setsProgressText() {
        let (sut, spy) = makeSUT()
        let response = ListenAndChooseModels.LoadRound.Response(
            targetWord: "Рыба",
            options: makeOptions(),
            correctIndex: 2,
            audioAsset: nil,
            questionNumber: 3,
            totalQuestions: 5
        )
        sut.presentLoadRound(response)
        XCTAssertNotNil(spy.loadRoundVM?.progressText)
    }

    func test_presentLoadRound_singleQuestion_progressTextIsNil() {
        let (sut, spy) = makeSUT()
        let response = ListenAndChooseModels.LoadRound.Response(
            targetWord: "Рыба",
            options: makeOptions(),
            correctIndex: 2,
            audioAsset: nil,
            questionNumber: 1,
            totalQuestions: 1
        )
        sut.presentLoadRound(response)
        XCTAssertNil(spy.loadRoundVM?.progressText)
    }

    func test_presentLoadRound_optionsMapped_correctCount() {
        let (sut, spy) = makeSUT()
        let response = ListenAndChooseModels.LoadRound.Response(
            targetWord: "Собака",
            options: makeOptions(),
            correctIndex: 0,
            audioAsset: nil
        )
        sut.presentLoadRound(response)
        XCTAssertEqual(spy.loadRoundVM?.options.count, 3)
    }

    // MARK: - presentSubmitAttempt

    func test_presentSubmitAttempt_correct_positiveFeedback() {
        let (sut, spy) = makeSUT()
        let response = ListenAndChooseModels.SubmitAttempt.Response(
            isCorrect: true,
            isFinalAttempt: false,
            score: 1.0,
            shouldRevealAnswer: false,
            correctIndex: 0,
            currentStreak: 1,
            hint: nil
        )
        sut.presentSubmitAttempt(response)
        XCTAssertTrue(spy.submitAttemptVM?.isCorrect ?? false)
        XCTAssertFalse(spy.submitAttemptVM?.feedbackText.isEmpty ?? true)
    }

    func test_presentSubmitAttempt_incorrect_negativeFeedback() {
        let (sut, spy) = makeSUT()
        let response = ListenAndChooseModels.SubmitAttempt.Response(
            isCorrect: false,
            isFinalAttempt: false,
            score: 0.0,
            shouldRevealAnswer: false,
            correctIndex: 1,
            currentStreak: 0,
            hint: nil
        )
        sut.presentSubmitAttempt(response)
        XCTAssertFalse(spy.submitAttemptVM?.isCorrect ?? true)
        XCTAssertFalse(spy.submitAttemptVM?.feedbackText.isEmpty ?? true)
    }

    func test_presentSubmitAttempt_streak3orMore_setsStreakText() {
        let (sut, spy) = makeSUT()
        let response = ListenAndChooseModels.SubmitAttempt.Response(
            isCorrect: true,
            isFinalAttempt: false,
            score: 1.0,
            shouldRevealAnswer: false,
            correctIndex: 0,
            currentStreak: 3,
            hint: nil
        )
        sut.presentSubmitAttempt(response)
        XCTAssertNotNil(spy.submitAttemptVM?.streakText)
    }
}
