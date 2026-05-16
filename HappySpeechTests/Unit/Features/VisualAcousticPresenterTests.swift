@testable import HappySpeech
import XCTest

// MARK: - VisualAcousticPresenterTests
//
// Phase 2.6.1 v25 — покрытие VisualAcousticPresenter (12 тестов).
// Тестируются все 5 методов: presentLoadRound, presentPlayAudio,
// presentChoiceWord, presentNextRound, presentComplete.

@MainActor
final class VisualAcousticPresenterTests: XCTestCase {

    // MARK: - DisplaySpy

    @MainActor
    private final class DisplaySpy: VisualAcousticDisplayLogic {
        var loadRoundVM: VisualAcousticModels.LoadRound.ViewModel?
        var playAudioVM: VisualAcousticModels.PlayAudio.ViewModel?
        var choiceWordVM: VisualAcousticModels.ChoiceWord.ViewModel?
        var nextRoundVM: VisualAcousticModels.NextRound.ViewModel?
        var completeVM: VisualAcousticModels.Complete.ViewModel?

        func displayLoadRound(_ viewModel: VisualAcousticModels.LoadRound.ViewModel) { loadRoundVM = viewModel }
        func displayPlayAudio(_ viewModel: VisualAcousticModels.PlayAudio.ViewModel) { playAudioVM = viewModel }
        func displayChoiceWord(_ viewModel: VisualAcousticModels.ChoiceWord.ViewModel) { choiceWordVM = viewModel }
        func displayNextRound(_ viewModel: VisualAcousticModels.NextRound.ViewModel) { nextRoundVM = viewModel }
        func displayComplete(_ viewModel: VisualAcousticModels.Complete.ViewModel) { completeVM = viewModel }
    }

    private func makeSUT() -> (VisualAcousticPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = VisualAcousticPresenter()
        presenter.display = spy
        return (presenter, spy)
    }

    private func makeRound(soundGroup: String = "whistling", correctIndex: Int = 0) -> VisualAcousticRound {
        VisualAcousticRound(
            id: UUID(),
            imageEmoji: "snake",
            imageLabel: "Змея",
            question: "Что это?",
            questionWithSound: "Найди звук С",
            choices: ["сок", "рак", "мёд", "бег"],
            correctIndex: correctIndex,
            soundGroup: soundGroup,
            ttsText: "Что это? сок рак мёд бег"
        )
    }

    // MARK: - presentLoadRound

    func test_presentLoadRound_progressFraction_zeroAtStart() {
        let (sut, spy) = makeSUT()
        let response = VisualAcousticModels.LoadRound.Response(
            round: makeRound(),
            roundIndex: 0,
            totalRounds: 6
        )
        sut.presentLoadRound(response)
        XCTAssertNotNil(spy.loadRoundVM)
        XCTAssertEqual(spy.loadRoundVM?.progressFraction ?? -1, 0.0, accuracy: 0.001)
    }

    func test_presentLoadRound_progressFraction_midway() {
        let (sut, spy) = makeSUT()
        let response = VisualAcousticModels.LoadRound.Response(
            round: makeRound(),
            roundIndex: 3,
            totalRounds: 6
        )
        sut.presentLoadRound(response)
        XCTAssertEqual(spy.loadRoundVM?.progressFraction ?? 0, 0.5, accuracy: 0.001)
    }

    func test_presentLoadRound_emptyTotalRounds_noNaN() {
        let (sut, spy) = makeSUT()
        let response = VisualAcousticModels.LoadRound.Response(
            round: makeRound(),
            roundIndex: 0,
            totalRounds: 0
        )
        sut.presentLoadRound(response)
        let fraction = spy.loadRoundVM?.progressFraction ?? -1
        XCTAssertFalse(fraction.isNaN)
        XCTAssertEqual(fraction, 0.0)
    }

    func test_presentLoadRound_passesRoundData() {
        let (sut, spy) = makeSUT()
        let round = makeRound(soundGroup: "hissing")
        let response = VisualAcousticModels.LoadRound.Response(
            round: round,
            roundIndex: 1,
            totalRounds: 6
        )
        sut.presentLoadRound(response)
        XCTAssertEqual(spy.loadRoundVM?.imageEmoji, "snake")
        XCTAssertEqual(spy.loadRoundVM?.choices.count, 4)
    }

    // MARK: - presentPlayAudio

    func test_presentPlayAudio_playing_truePassedThrough() {
        let (sut, spy) = makeSUT()
        sut.presentPlayAudio(VisualAcousticModels.PlayAudio.Response(isPlaying: true))
        XCTAssertTrue(spy.playAudioVM?.isPlaying ?? false)
    }

    func test_presentPlayAudio_stopped_falsePassedThrough() {
        let (sut, spy) = makeSUT()
        sut.presentPlayAudio(VisualAcousticModels.PlayAudio.Response(isPlaying: false))
        XCTAssertFalse(spy.playAudioVM?.isPlaying ?? true)
    }

    // MARK: - presentChoiceWord

    func test_presentChoiceWord_correct_feedbackCorrect() {
        let (sut, spy) = makeSUT()
        let response = VisualAcousticModels.ChoiceWord.Response(
            choiceIndex: 0,
            correctIndex: 0,
            isCorrect: true,
            correctWord: "сок"
        )
        sut.presentChoiceWord(response)
        XCTAssertTrue(spy.choiceWordVM?.feedbackCorrect ?? false)
        XCTAssertFalse(spy.choiceWordVM?.feedbackText.isEmpty ?? true)
        XCTAssertEqual(spy.choiceWordVM?.choiceResults[0], .correct)
    }

    func test_presentChoiceWord_incorrect_marksWrongAndRevealedSlots() {
        let (sut, spy) = makeSUT()
        let response = VisualAcousticModels.ChoiceWord.Response(
            choiceIndex: 2,
            correctIndex: 0,
            isCorrect: false,
            correctWord: "сок"
        )
        sut.presentChoiceWord(response)
        XCTAssertFalse(spy.choiceWordVM?.feedbackCorrect ?? true)
        // choiceIndex=2 должен быть wrong
        if case .wrong = spy.choiceWordVM?.choiceResults[2] {
            // ok
        } else {
            XCTFail("Неправильный слот должен иметь состояние .wrong")
        }
    }

    func test_presentChoiceWord_incorrect_feedbackContainsCorrectWord() {
        let (sut, spy) = makeSUT()
        let response = VisualAcousticModels.ChoiceWord.Response(
            choiceIndex: 1,
            correctIndex: 0,
            isCorrect: false,
            correctWord: "сок"
        )
        sut.presentChoiceWord(response)
        XCTAssertTrue(spy.choiceWordVM?.feedbackText.contains("сок") ?? false)
    }

    // MARK: - presentNextRound

    func test_presentNextRound_hasNext_truePassedThrough() {
        let (sut, spy) = makeSUT()
        sut.presentNextRound(VisualAcousticModels.NextRound.Response(hasNextRound: true, nextRoundIndex: 1))
        XCTAssertTrue(spy.nextRoundVM?.hasNextRound ?? false)
        XCTAssertEqual(spy.nextRoundVM?.nextRoundIndex, 1)
    }

    func test_presentNextRound_noNext_falsePassedThrough() {
        let (sut, spy) = makeSUT()
        sut.presentNextRound(VisualAcousticModels.NextRound.Response(hasNextRound: false, nextRoundIndex: 0))
        XCTAssertFalse(spy.nextRoundVM?.hasNextRound ?? true)
    }

    // MARK: - presentComplete

    func test_presentComplete_highScore_3stars() {
        let (sut, spy) = makeSUT()
        sut.presentComplete(VisualAcousticModels.Complete.Response(correctCount: 6, totalRounds: 6, score: 0.95))
        XCTAssertEqual(spy.completeVM?.starsEarned, 3)
        XCTAssertFalse(spy.completeVM?.scoreLabel.isEmpty ?? true)
        XCTAssertFalse(spy.completeVM?.completionMessage.isEmpty ?? true)
    }

    func test_presentComplete_lowScore_0stars() {
        let (sut, spy) = makeSUT()
        sut.presentComplete(VisualAcousticModels.Complete.Response(correctCount: 1, totalRounds: 6, score: 0.2))
        XCTAssertEqual(spy.completeVM?.starsEarned, 0)
    }
}
