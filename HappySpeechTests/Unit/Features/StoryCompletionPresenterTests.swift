@testable import HappySpeech
import XCTest

// MARK: - StoryCompletionPresenterTests
//
// Phase 2.6.1 v25 — покрытие StoryCompletionPresenter (12 тестов).
// Тестируются все 4 метода: presentLoadStory, presentChooseWord,
// presentNextScene, presentComplete.

@MainActor
final class StoryCompletionPresenterTests: XCTestCase {

    // MARK: - DisplaySpy

    @MainActor
    private final class DisplaySpy: StoryCompletionDisplayLogic {
        var loadStoryVM: StoryCompletionModels.LoadStory.ViewModel?
        var chooseWordVM: StoryCompletionModels.ChooseWord.ViewModel?
        var nextSceneVM: StoryCompletionModels.NextScene.ViewModel?
        var completeVM: StoryCompletionModels.Complete.ViewModel?

        func displayLoadStory(_ viewModel: StoryCompletionModels.LoadStory.ViewModel) { loadStoryVM = viewModel }
        func displayChooseWord(_ viewModel: StoryCompletionModels.ChooseWord.ViewModel) { chooseWordVM = viewModel }
        func displayNextScene(_ viewModel: StoryCompletionModels.NextScene.ViewModel) { nextSceneVM = viewModel }
        func displayComplete(_ viewModel: StoryCompletionModels.Complete.ViewModel) { completeVM = viewModel }
    }

    private func makeSUT() -> (StoryCompletionPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = StoryCompletionPresenter()
        presenter.display = spy
        return (presenter, spy)
    }

    private func makeScene() -> StoryScene {
        StoryScene(
            id: UUID(),
            storyText: "Маша пошла в лес и нашла ___.",
            choices: ["слон", "сова", "рак"],
            correctIndex: 1,
            soundGroup: "whistling",
            emoji: "owl"
        )
    }

    // MARK: - presentLoadStory

    func test_presentLoadStory_replacesMarkerWithBlank() {
        let (sut, spy) = makeSUT()
        let response = StoryCompletionModels.LoadStory.Response(
            scene: makeScene(),
            sceneIndex: 0,
            totalScenes: 5
        )
        sut.presentLoadStory(response)
        XCTAssertNotNil(spy.loadStoryVM)
        // storyText сохраняет маркер "___" (3 подч.)
        XCTAssertTrue(spy.loadStoryVM?.storyText.contains(StoryPlaceholder.marker) ?? false)
        // displayText должен содержать blank "_______" (7 подч.)
        XCTAssertTrue(spy.loadStoryVM?.displayText.contains(StoryPlaceholder.blank) ?? false)
        // storyText и displayText отличаются
        XCTAssertNotEqual(spy.loadStoryVM?.storyText, spy.loadStoryVM?.displayText)
    }

    func test_presentLoadStory_progressFraction_firstScene() {
        let (sut, spy) = makeSUT()
        let response = StoryCompletionModels.LoadStory.Response(
            scene: makeScene(),
            sceneIndex: 0,
            totalScenes: 5
        )
        sut.presentLoadStory(response)
        XCTAssertEqual(spy.loadStoryVM?.progressFraction ?? -1, 0.0, accuracy: 0.001)
    }

    func test_presentLoadStory_progressFraction_midpoint() {
        let (sut, spy) = makeSUT()
        let response = StoryCompletionModels.LoadStory.Response(
            scene: makeScene(),
            sceneIndex: 2,
            totalScenes: 4
        )
        sut.presentLoadStory(response)
        XCTAssertEqual(spy.loadStoryVM?.progressFraction ?? -1, 0.5, accuracy: 0.001)
    }

    func test_presentLoadStory_passesChoicesThrough() {
        let (sut, spy) = makeSUT()
        let response = StoryCompletionModels.LoadStory.Response(
            scene: makeScene(),
            sceneIndex: 0,
            totalScenes: 5
        )
        sut.presentLoadStory(response)
        XCTAssertEqual(spy.loadStoryVM?.choices.count, 3)
    }

    // MARK: - presentChooseWord

    func test_presentChooseWord_correct_correctStateAtIndex() {
        let (sut, spy) = makeSUT()
        let response = StoryCompletionModels.ChooseWord.Response(
            choiceIndex: 1,
            correctIndex: 1,
            isCorrect: true,
            chosenWord: "сова",
            correctWord: "сова",
            filledStoryText: "Маша пошла в лес и нашла сову."
        )
        sut.presentChooseWord(response)
        XCTAssertTrue(spy.chooseWordVM?.feedbackCorrect ?? false)
        XCTAssertEqual(spy.chooseWordVM?.choiceStates[1], .correct)
        XCTAssertFalse(spy.chooseWordVM?.feedbackMessage.isEmpty ?? true)
    }

    func test_presentChooseWord_incorrect_wrongAndRevealedStates() {
        let (sut, spy) = makeSUT()
        let response = StoryCompletionModels.ChooseWord.Response(
            choiceIndex: 0,
            correctIndex: 1,
            isCorrect: false,
            chosenWord: "слон",
            correctWord: "сова",
            filledStoryText: "Маша пошла в лес и нашла сову."
        )
        sut.presentChooseWord(response)
        XCTAssertFalse(spy.chooseWordVM?.feedbackCorrect ?? true)
        XCTAssertEqual(spy.chooseWordVM?.choiceStates[0], .wrong)
        XCTAssertEqual(spy.chooseWordVM?.choiceStates[1], .revealed)
    }

    func test_presentChooseWord_incorrect_feedbackContainsCorrectWord() {
        let (sut, spy) = makeSUT()
        let response = StoryCompletionModels.ChooseWord.Response(
            choiceIndex: 2,
            correctIndex: 1,
            isCorrect: false,
            chosenWord: "рак",
            correctWord: "сова",
            filledStoryText: "Маша пошла в лес и нашла сову."
        )
        sut.presentChooseWord(response)
        XCTAssertTrue(spy.chooseWordVM?.feedbackMessage.contains("сова") ?? false)
    }

    // MARK: - presentNextScene

    func test_presentNextScene_hasNext_truePassedThrough() {
        let (sut, spy) = makeSUT()
        sut.presentNextScene(StoryCompletionModels.NextScene.Response(hasNextScene: true, nextSceneIndex: 1))
        XCTAssertTrue(spy.nextSceneVM?.hasNextScene ?? false)
        XCTAssertEqual(spy.nextSceneVM?.nextSceneIndex, 1)
    }

    func test_presentNextScene_noNext_falsePassedThrough() {
        let (sut, spy) = makeSUT()
        sut.presentNextScene(StoryCompletionModels.NextScene.Response(hasNextScene: false, nextSceneIndex: 0))
        XCTAssertFalse(spy.nextSceneVM?.hasNextScene ?? true)
    }

    // MARK: - presentComplete

    func test_presentComplete_perfectScore_3stars() {
        let (sut, spy) = makeSUT()
        sut.presentComplete(StoryCompletionModels.Complete.Response(correctCount: 5, totalScenes: 5, score: 1.0))
        XCTAssertEqual(spy.completeVM?.starsEarned, 3)
        XCTAssertFalse(spy.completeVM?.scoreLabel.isEmpty ?? true)
        XCTAssertFalse(spy.completeVM?.completionMessage.isEmpty ?? true)
    }

    func test_presentComplete_midScore_2stars() {
        let (sut, spy) = makeSUT()
        sut.presentComplete(StoryCompletionModels.Complete.Response(correctCount: 4, totalScenes: 5, score: 0.8))
        XCTAssertEqual(spy.completeVM?.starsEarned, 2)
    }

    func test_presentComplete_lowScore_0stars() {
        let (sut, spy) = makeSUT()
        sut.presentComplete(StoryCompletionModels.Complete.Response(correctCount: 0, totalScenes: 5, score: 0.1))
        XCTAssertEqual(spy.completeVM?.starsEarned, 0)
    }

    func test_presentComplete_scoreLabelContainsPercent() {
        let (sut, spy) = makeSUT()
        sut.presentComplete(StoryCompletionModels.Complete.Response(correctCount: 4, totalScenes: 5, score: 0.8))
        XCTAssertTrue(spy.completeVM?.scoreLabel.contains("%") ?? false)
    }
}
