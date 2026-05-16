@testable import HappySpeech
import XCTest

// MARK: - DragAndMatchPresenterTests
//
// Phase 2.6.1 v25 — покрытие DragAndMatchPresenter (12 тестов).
// Тестируются все 5 методов: presentLoadSession, presentDropWord,
// presentHint, presentCompleteRound, presentCompleteSession.

@MainActor
final class DragAndMatchPresenterTests: XCTestCase {

    // MARK: - DisplaySpy

    @MainActor
    private final class DisplaySpy: DragAndMatchDisplayLogic {
        var loadSessionVM: DragAndMatchModels.LoadSession.ViewModel?
        var dropWordVM: DragAndMatchModels.DropWord.ViewModel?
        var hintVM: DragAndMatchModels.RequestHint.ViewModel?
        var completeRoundVM: DragAndMatchModels.CompleteRound.ViewModel?
        var completeSessionVM: DragAndMatchModels.CompleteSession.ViewModel?

        func displayLoadSession(_ viewModel: DragAndMatchModels.LoadSession.ViewModel) { loadSessionVM = viewModel }
        func displayDropWord(_ viewModel: DragAndMatchModels.DropWord.ViewModel) { dropWordVM = viewModel }
        func displayHint(_ viewModel: DragAndMatchModels.RequestHint.ViewModel) { hintVM = viewModel }
        func displayCompleteRound(_ viewModel: DragAndMatchModels.CompleteRound.ViewModel) { completeRoundVM = viewModel }
        func displayCompleteSession(_ viewModel: DragAndMatchModels.CompleteSession.ViewModel) { completeSessionVM = viewModel }
    }

    private func makeSUT() -> (DragAndMatchPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = DragAndMatchPresenter()
        presenter.viewModel = spy
        return (presenter, spy)
    }

    private func makeRoundStats(accuracy: Double = 1.0, hints: Int = 0, duration: Double = 30) -> RoundStats {
        RoundStats(
            roundIndex: 0,
            totalCards: 8,
            correctDrops: Int(accuracy * 8),
            incorrectDrops: 8 - Int(accuracy * 8),
            hintsUsed: hints,
            durationSeconds: duration
        )
    }

    // MARK: - presentLoadSession

    func test_presentLoadSession_withName_greetingContainsName() {
        let (sut, spy) = makeSUT()
        let response = DragAndMatchModels.LoadSession.Response(
            words: [],
            buckets: [],
            childName: "Ваня",
            roundIndex: 0,
            totalRounds: 3,
            confusedPair: nil
        )
        sut.presentLoadSession(response)
        XCTAssertTrue(spy.loadSessionVM?.greeting.contains("Ваня") ?? false)
    }

    func test_presentLoadSession_emptyName_defaultGreeting() {
        let (sut, spy) = makeSUT()
        let response = DragAndMatchModels.LoadSession.Response(
            words: [],
            buckets: [],
            childName: "",
            roundIndex: 0,
            totalRounds: 3,
            confusedPair: nil
        )
        sut.presentLoadSession(response)
        XCTAssertFalse(spy.loadSessionVM?.greeting.isEmpty ?? true)
    }

    func test_presentLoadSession_confusedPair_labelSet() {
        let (sut, spy) = makeSUT()
        let pair = ConfusedPair(primary: "С", secondary: "Ш")
        let response = DragAndMatchModels.LoadSession.Response(
            words: [],
            buckets: [],
            childName: "",
            roundIndex: 0,
            totalRounds: 1,
            confusedPair: pair
        )
        sut.presentLoadSession(response)
        XCTAssertNotNil(spy.loadSessionVM?.confusedPairLabel)
        XCTAssertTrue(spy.loadSessionVM?.confusedPairLabel?.contains("С/Ш") ?? false)
    }

    func test_presentLoadSession_nilConfusedPair_labelNil() {
        let (sut, spy) = makeSUT()
        let response = DragAndMatchModels.LoadSession.Response(
            words: [],
            buckets: [],
            childName: "",
            roundIndex: 0,
            totalRounds: 1,
            confusedPair: nil
        )
        sut.presentLoadSession(response)
        XCTAssertNil(spy.loadSessionVM?.confusedPairLabel)
    }

    // MARK: - presentDropWord

    func test_presentDropWord_correct_positiveFeedback() {
        let (sut, spy) = makeSUT()
        let response = DragAndMatchModels.DropWord.Response(
            correct: true,
            wordId: "word-1",
            feedbackText: "Верно!",
            streakCount: 1,
            isStreakBonus: false,
            hintBucketId: nil
        )
        sut.presentDropWord(response)
        XCTAssertTrue(spy.dropWordVM?.correct ?? false)
        XCTAssertFalse(spy.dropWordVM?.feedbackText.isEmpty ?? true)
    }

    func test_presentDropWord_streakBonus_specialFeedback() {
        let (sut, spy) = makeSUT()
        let response = DragAndMatchModels.DropWord.Response(
            correct: true,
            wordId: "word-2",
            feedbackText: "Молодец!",
            streakCount: 3,
            isStreakBonus: true,
            hintBucketId: nil
        )
        sut.presentDropWord(response)
        XCTAssertTrue(spy.dropWordVM?.showStreakBonus ?? false)
        XCTAssertNotNil(spy.dropWordVM?.streakLabel)
    }

    func test_presentDropWord_incorrect_negativeFeedback() {
        let (sut, spy) = makeSUT()
        let response = DragAndMatchModels.DropWord.Response(
            correct: false,
            wordId: "word-3",
            feedbackText: "Попробуй другую корзину.",
            streakCount: 0,
            isStreakBonus: false,
            hintBucketId: nil
        )
        sut.presentDropWord(response)
        XCTAssertFalse(spy.dropWordVM?.correct ?? true)
        XCTAssertFalse(spy.dropWordVM?.feedbackText.isEmpty ?? true)
    }

    // MARK: - presentHint

    func test_presentHint_zeroRemaining_noHintsLabel() {
        let (sut, spy) = makeSUT()
        let response = DragAndMatchModels.RequestHint.Response(
            level: .voicePrompt,
            targetBucketId: "bucket-1",
            voicePromptText: "Слушай!",
            autoSolvedWordId: nil,
            autoSolvedBucketId: nil,
            hintsRemaining: 0
        )
        sut.presentHint(response)
        XCTAssertFalse(spy.hintVM?.hintsRemainingLabel.isEmpty ?? true)
    }

    func test_presentHint_oneRemaining_singularLabel() {
        let (sut, spy) = makeSUT()
        let response = DragAndMatchModels.RequestHint.Response(
            level: .highlightBin,
            targetBucketId: "bucket-2",
            voicePromptText: nil,
            autoSolvedWordId: nil,
            autoSolvedBucketId: nil,
            hintsRemaining: 1
        )
        sut.presentHint(response)
        XCTAssertFalse(spy.hintVM?.hintsRemainingLabel.isEmpty ?? true)
    }

    func test_presentHint_multipleRemaining_pluralLabel() {
        let (sut, spy) = makeSUT()
        let response = DragAndMatchModels.RequestHint.Response(
            level: .autoSolve,
            targetBucketId: nil,
            voicePromptText: nil,
            autoSolvedWordId: "word-1",
            autoSolvedBucketId: "bucket-1",
            hintsRemaining: 3
        )
        sut.presentHint(response)
        XCTAssertFalse(spy.hintVM?.hintsRemainingLabel.isEmpty ?? true)
        XCTAssertTrue(spy.hintVM?.hintsRemainingLabel.contains("3") ?? false)
    }

    // MARK: - presentCompleteRound

    func test_presentCompleteRound_hasNext_ctaIsNextRound() {
        let (sut, spy) = makeSUT()
        let stats = makeRoundStats(accuracy: 1.0)
        let response = DragAndMatchModels.CompleteRound.Response(
            stats: stats,
            hasNextRound: true,
            nextRoundIndex: 1
        )
        sut.presentCompleteRound(response)
        XCTAssertTrue(spy.completeRoundVM?.hasNextRound ?? false)
        XCTAssertFalse(spy.completeRoundVM?.ctaLabel.isEmpty ?? true)
    }

    func test_presentCompleteRound_zeroHints_bonusLabel() {
        let (sut, spy) = makeSUT()
        let stats = makeRoundStats(accuracy: 0.8, hints: 0)
        let response = DragAndMatchModels.CompleteRound.Response(
            stats: stats,
            hasNextRound: false,
            nextRoundIndex: 0
        )
        sut.presentCompleteRound(response)
        XCTAssertFalse(spy.completeRoundVM?.hintsLabel.isEmpty ?? true)
    }

    func test_presentCompleteRound_durationUnderMinute_secsLabel() {
        let (sut, spy) = makeSUT()
        let stats = makeRoundStats(duration: 45)
        let response = DragAndMatchModels.CompleteRound.Response(
            stats: stats,
            hasNextRound: false,
            nextRoundIndex: 0
        )
        sut.presentCompleteRound(response)
        XCTAssertFalse(spy.completeRoundVM?.durationLabel.isEmpty ?? true)
    }

    // MARK: - presentCompleteSession

    func test_presentCompleteSession_perfectScore_3stars() {
        let (sut, spy) = makeSUT()
        let response = DragAndMatchModels.CompleteSession.Response(
            correctCount: 10,
            totalWords: 10,
            allRoundStats: [makeRoundStats()],
            totalHintsUsed: 0,
            totalDurationSeconds: 120
        )
        sut.presentCompleteSession(response)
        XCTAssertEqual(spy.completeSessionVM?.starsEarned, 3)
        XCTAssertEqual(spy.completeSessionVM?.accuracyPercent, "100%")
    }

    func test_presentCompleteSession_zeroWords_noNaN() {
        let (sut, spy) = makeSUT()
        let response = DragAndMatchModels.CompleteSession.Response(
            correctCount: 0,
            totalWords: 0,
            allRoundStats: [],
            totalHintsUsed: 0,
            totalDurationSeconds: 0
        )
        sut.presentCompleteSession(response)
        XCTAssertEqual(spy.completeSessionVM?.starsEarned, 0)
        XCTAssertFalse(spy.completeSessionVM?.accuracyPercent.isEmpty ?? true)
    }

    func test_presentCompleteSession_belowHalf_0stars() {
        let (sut, spy) = makeSUT()
        let response = DragAndMatchModels.CompleteSession.Response(
            correctCount: 3,
            totalWords: 10,
            allRoundStats: [makeRoundStats(accuracy: 0.3)],
            totalHintsUsed: 5,
            totalDurationSeconds: 200
        )
        sut.presentCompleteSession(response)
        XCTAssertEqual(spy.completeSessionVM?.starsEarned, 0)
    }
}
