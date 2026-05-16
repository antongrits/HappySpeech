import XCTest
@testable import HappySpeech

// MARK: - GrammarGamePresenterTests
//
// Phase 2.6 batch 3 — покрытие GrammarGamePresenter (0% → цель ≥90%).

@MainActor
final class GrammarGamePresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: GrammarGameDisplayLogic {
        var loadGameVM: GrammarGameModels.LoadGame.ViewModel?
        var roundVM: GrammarGameModels.PresentRound.ViewModel?
        var evaluateVM: GrammarGameModels.EvaluateAnswer.ViewModel?
        var dragDropVM: GrammarGameModels.DragDrop.ViewModel?
        var sessionCompleteVM: GrammarGameModels.SessionComplete.ViewModel?
        var exitConfirmationVM: GrammarGameModels.ExitConfirmation.ViewModel?
        var errorMessage: String?

        func displayLoadGame(_ vm: GrammarGameModels.LoadGame.ViewModel) { loadGameVM = vm }
        func displayRound(_ vm: GrammarGameModels.PresentRound.ViewModel) { roundVM = vm }
        func displayEvaluateAnswer(_ vm: GrammarGameModels.EvaluateAnswer.ViewModel) { evaluateVM = vm }
        func displayDragDrop(_ vm: GrammarGameModels.DragDrop.ViewModel) { dragDropVM = vm }
        func displaySessionComplete(_ vm: GrammarGameModels.SessionComplete.ViewModel) { sessionCompleteVM = vm }
        func displayExitConfirmation(_ vm: GrammarGameModels.ExitConfirmation.ViewModel) { exitConfirmationVM = vm }
        func displayError(_ message: String) { errorMessage = message }
    }

    private func makeSUT() -> (GrammarGamePresenter, DisplaySpy) {
        let sut = GrammarGamePresenter()
        let spy = DisplaySpy()
        sut.display = spy
        return (sut, spy)
    }

    private func makePackItem(id: String = "item-1") -> GrammarPackItem {
        GrammarPackItem(id: id, word: "собака", hint: "С-С-С", difficulty: 1, audioFile: "dog.mp3")
    }

    private func makeRound(mode: GrammarGameMode = .dative) -> GrammarRound {
        let item = makePackItem()
        let choices = [
            GrammarChoice(id: "c1", text: "Собаке", imageName: nil),
            GrammarChoice(id: "c2", text: "Кошке", imageName: nil)
        ]
        return GrammarRound(
            id: UUID(),
            mode: mode,
            sourceItem: item,
            questionText: "Кому нужна кость?",
            correctAnswer: "собаке",
            choices: choices,
            correctIndex: 0,
            imageName: "word_dog",
            extraData: .none
        )
    }

    // MARK: - presentLoadGame

    func test_presentLoadGame_modeTitle_notEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentLoadGame(.init(mode: .dative, difficulty: .easy, rounds: [], totalRounds: 5))
        XCTAssertNotNil(spy.loadGameVM)
        XCTAssertFalse(spy.loadGameVM?.modeTitle.isEmpty ?? true)
        XCTAssertFalse(spy.loadGameVM?.difficultyLabel.isEmpty ?? true)
        XCTAssertEqual(spy.loadGameVM?.totalRounds, 5)
    }

    func test_presentLoadGame_allModes() {
        let (sut, spy) = makeSUT()
        for mode in GrammarGameMode.allCases {
            sut.presentLoadGame(.init(mode: mode, difficulty: .medium, rounds: [], totalRounds: 7))
            XCTAssertFalse(spy.loadGameVM?.modeTitle.isEmpty ?? true, "Mode \(mode) must have title")
        }
    }

    func test_presentLoadGame_allDifficulties() {
        let (sut, spy) = makeSUT()
        for difficulty in GrammarDifficulty.allCases {
            sut.presentLoadGame(.init(mode: .oneMany, difficulty: difficulty, rounds: [], totalRounds: 5))
            XCTAssertFalse(spy.loadGameVM?.difficultyLabel.isEmpty ?? true)
        }
    }

    // MARK: - presentRound

    func test_presentRound_propagatesData() {
        let (sut, spy) = makeSUT()
        let round = makeRound()
        sut.presentRound(.init(round: round, roundIndex: 0, totalRounds: 5, mode: .dative, difficulty: .easy))
        XCTAssertNotNil(spy.roundVM)
        XCTAssertEqual(spy.roundVM?.questionText, "Кому нужна кость?")
        XCTAssertEqual(spy.roundVM?.roundIndex, 0)
        XCTAssertEqual(spy.roundVM?.totalRounds, 5)
    }

    func test_presentRound_choicesCount_matches() {
        let (sut, spy) = makeSUT()
        let round = makeRound()
        sut.presentRound(.init(round: round, roundIndex: 2, totalRounds: 10, mode: .genitive, difficulty: .hard))
        XCTAssertEqual(spy.roundVM?.choices.count, 2)
    }

    // MARK: - presentEvaluateAnswer

    func test_presentEvaluateAnswer_correct_isCorrectTrue() {
        let (sut, spy) = makeSUT()
        sut.presentEvaluateAnswer(.init(
            isCorrect: true,
            correctChoiceId: "c1",
            selectedChoiceId: "c1",
            errorsOnThisRound: 0,
            feedbackText: "Молодец!",
            hintText: nil,
            shouldShowHint: false,
            score: 1
        ))
        XCTAssertTrue(spy.evaluateVM?.isCorrect == true)
        XCTAssertFalse(spy.evaluateVM?.showHint ?? true)
    }

    func test_presentEvaluateAnswer_incorrect_showHint() {
        let (sut, spy) = makeSUT()
        sut.presentEvaluateAnswer(.init(
            isCorrect: false,
            correctChoiceId: "c1",
            selectedChoiceId: "c2",
            errorsOnThisRound: 1,
            feedbackText: "Попробуй ещё!",
            hintText: "Подсказка",
            shouldShowHint: true,
            score: 0
        ))
        XCTAssertFalse(spy.evaluateVM?.isCorrect ?? true)
        XCTAssertTrue(spy.evaluateVM?.showHint == true)
        XCTAssertEqual(spy.evaluateVM?.hintText, "Подсказка")
    }

    // MARK: - presentDragDrop

    func test_presentDragDrop_correct_withDativeName_feedbackNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentDragDrop(.init(
            isCorrect: true,
            correctCharacterId: "char-1",
            droppedCharacterId: "char-1",
            charDativeName: "Барбосу",
            correctAnswer: "собаке"
        ))
        XCTAssertTrue(spy.dragDropVM?.isCorrect == true)
        XCTAssertFalse(spy.dragDropVM?.feedbackPhrase.isEmpty ?? true)
    }

    func test_presentDragDrop_correct_noDativeName_feedbackNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentDragDrop(.init(
            isCorrect: true,
            correctCharacterId: "char-1",
            droppedCharacterId: "char-1",
            charDativeName: "",
            correctAnswer: "кошке"
        ))
        XCTAssertTrue(spy.dragDropVM?.isCorrect == true)
        XCTAssertFalse(spy.dragDropVM?.feedbackPhrase.isEmpty ?? true)
    }

    func test_presentDragDrop_incorrect_tryAgainPhrase() {
        let (sut, spy) = makeSUT()
        sut.presentDragDrop(.init(
            isCorrect: false,
            correctCharacterId: "char-1",
            droppedCharacterId: "char-2",
            charDativeName: "",
            correctAnswer: "собаке"
        ))
        XCTAssertFalse(spy.dragDropVM?.isCorrect ?? true)
        XCTAssertFalse(spy.dragDropVM?.feedbackPhrase.isEmpty ?? true)
    }

    // MARK: - presentSessionComplete

    func test_presentSessionComplete_highRate_showReward() {
        let (sut, spy) = makeSUT()
        sut.presentSessionComplete(.init(
            mode: .dative,
            difficulty: .easy,
            totalRounds: 10,
            correctCount: 9,
            successRate: 0.9,
            sessionDurationSeconds: 120
        ))
        XCTAssertTrue(spy.sessionCompleteVM?.showReward == true)
        XCTAssertFalse(spy.sessionCompleteVM?.resultText.isEmpty ?? true)
        XCTAssertEqual(spy.sessionCompleteVM?.correctCount, 9)
    }

    func test_presentSessionComplete_mediumRate_showReward() {
        let (sut, spy) = makeSUT()
        sut.presentSessionComplete(.init(
            mode: .oneMany,
            difficulty: .medium,
            totalRounds: 10,
            correctCount: 6,
            successRate: 0.6,
            sessionDurationSeconds: 180
        ))
        XCTAssertTrue(spy.sessionCompleteVM?.showReward == true)
    }

    func test_presentSessionComplete_lowRate_noReward() {
        let (sut, spy) = makeSUT()
        sut.presentSessionComplete(.init(
            mode: .genitive,
            difficulty: .easy,
            totalRounds: 10,
            correctCount: 3,
            successRate: 0.3,
            sessionDurationSeconds: 60
        ))
        XCTAssertFalse(spy.sessionCompleteVM?.showReward ?? true)
        XCTAssertFalse(spy.sessionCompleteVM?.resultText.isEmpty ?? true)
    }

    func test_presentSessionComplete_borderline60_showReward() {
        let (sut, spy) = makeSUT()
        sut.presentSessionComplete(.init(
            mode: .instrumental,
            difficulty: .medium,
            totalRounds: 10,
            correctCount: 6,
            successRate: 0.6,
            sessionDurationSeconds: 150
        ))
        XCTAssertTrue(spy.sessionCompleteVM?.showReward == true)
    }

    // MARK: - presentExitConfirmation

    func test_presentExitConfirmation_allLabelsNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentExitConfirmation()
        XCTAssertNotNil(spy.exitConfirmationVM)
        XCTAssertFalse(spy.exitConfirmationVM?.title.isEmpty ?? true)
        XCTAssertFalse(spy.exitConfirmationVM?.body.isEmpty ?? true)
        XCTAssertFalse(spy.exitConfirmationVM?.confirmLabel.isEmpty ?? true)
        XCTAssertFalse(spy.exitConfirmationVM?.cancelLabel.isEmpty ?? true)
    }

    // MARK: - presentError

    func test_presentError_passesMessage() {
        let (sut, spy) = makeSUT()
        sut.presentError("Не удалось загрузить")
        XCTAssertEqual(spy.errorMessage, "Не удалось загрузить")
    }
}
