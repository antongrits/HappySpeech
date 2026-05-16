@testable import HappySpeech
import XCTest

// MARK: - Spy

@MainActor
private final class SpyStoryPresenter: StoryCompletionPresentationLogic {
    var loadStoryCalled = false
    var chooseWordCalled = false
    var nextSceneCalled = false
    var completeCalled = false

    var lastLoadStory: StoryCompletionModels.LoadStory.Response?
    var lastChooseWord: StoryCompletionModels.ChooseWord.Response?
    var lastComplete: StoryCompletionModels.Complete.Response?

    func presentLoadStory(_ response: StoryCompletionModels.LoadStory.Response) {
        loadStoryCalled = true
        lastLoadStory = response
    }
    func presentChooseWord(_ response: StoryCompletionModels.ChooseWord.Response) {
        chooseWordCalled = true
        lastChooseWord = response
    }
    func presentNextScene(_ response: StoryCompletionModels.NextScene.Response) {
        nextSceneCalled = true
    }
    func presentComplete(_ response: StoryCompletionModels.Complete.Response) {
        completeCalled = true
        lastComplete = response
    }
}

// MARK: - Tests

@MainActor
final class StoryCompletionInteractorTests: XCTestCase {

    private func makeActivity(sound: String = "С") -> SessionActivity {
        SessionActivity(
            id: "test-story",
            gameType: .sorting,
            lessonId: "lesson-1",
            soundTarget: sound,
            difficulty: 1,
            isCompleted: false,
            score: nil
        )
    }

    private func makeSUT() -> (StoryCompletionInteractor, SpyStoryPresenter) {
        let sut = StoryCompletionInteractor()
        let spy = SpyStoryPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - 1. loadStory загружает первую сцену

    func test_loadStory_loadsFirstScene() {
        let (sut, spy) = makeSUT()
        sut.loadStory(.init(activity: makeActivity(), sceneIndex: 0))
        XCTAssertTrue(spy.loadStoryCalled)
        XCTAssertEqual(spy.lastLoadStory?.sceneIndex, 0)
        XCTAssertEqual(spy.lastLoadStory?.totalScenes, 5)
    }

    // MARK: - 2. buildScenes возвращает 5 сцен

    func test_buildScenes_returnsFiveScenes() {
        for group in ["whistling", "hissing", "sonants", "velar"] {
            let scenes = StoryCompletionInteractor.buildScenes(for: group, total: 5)
            XCTAssertEqual(scenes.count, 5, "Группа \(group) должна иметь 5 сцен")
        }
    }

    // MARK: - 3. resolveSoundGroup

    func test_resolveSoundGroup() {
        XCTAssertEqual(StoryCompletionInteractor.resolveSoundGroup(for: "С"), "whistling")
        XCTAssertEqual(StoryCompletionInteractor.resolveSoundGroup(for: "Ш"), "hissing")
        XCTAssertEqual(StoryCompletionInteractor.resolveSoundGroup(for: "Р"), "sonants")
        XCTAssertEqual(StoryCompletionInteractor.resolveSoundGroup(for: "К"), "velar")
    }

    // MARK: - 4. chooseWord: правильный ответ

    func test_chooseWord_correct() {
        let (sut, spy) = makeSUT()
        sut.loadStory(.init(activity: makeActivity(), sceneIndex: 0))
        guard let scene = spy.lastLoadStory?.scene else { return }
        sut.chooseWord(.init(choiceIndex: scene.correctIndex))
        XCTAssertTrue(spy.chooseWordCalled)
        XCTAssertEqual(spy.lastChooseWord?.isCorrect, true)
    }

    // MARK: - 5. chooseWord: неправильный ответ

    func test_chooseWord_wrong() {
        let (sut, spy) = makeSUT()
        sut.loadStory(.init(activity: makeActivity(), sceneIndex: 0))
        guard let scene = spy.lastLoadStory?.scene else { return }
        let wrongIndex = scene.correctIndex == 0 ? 1 : 0
        sut.chooseWord(.init(choiceIndex: wrongIndex))
        XCTAssertEqual(spy.lastChooseWord?.isCorrect, false)
    }

    // MARK: - 6. complete вычисляет score

    func test_complete_scoreInRange() {
        let (sut, spy) = makeSUT()
        sut.loadStory(.init(activity: makeActivity(), sceneIndex: 0))
        sut.complete()
        XCTAssertTrue(spy.completeCalled)
        let score = spy.lastComplete?.score ?? -1
        XCTAssertGreaterThanOrEqual(score, 0)
        XCTAssertLessThanOrEqual(score, 1)
    }

    // MARK: - 7. complete дважды — игнорируется

    func test_complete_twice_ignored() {
        let (sut, spy) = makeSUT()
        sut.loadStory(.init(activity: makeActivity(), sceneIndex: 0))
        sut.complete()
        let firstScore = spy.lastComplete?.score
        spy.lastComplete = nil
        sut.complete()
        XCTAssertNil(spy.lastComplete, "Второй complete не должен вызывать presenter")
        _ = firstScore
    }

    // MARK: - 8. cancel не вызывает complete

    func test_cancel_doesNotCallComplete() {
        let (sut, spy) = makeSUT()
        sut.loadStory(.init(activity: makeActivity(), sceneIndex: 0))
        sut.cancel()
        XCTAssertFalse(spy.completeCalled)
    }

    // MARK: - 9. filledStoryText содержит правильное слово

    func test_filledStoryText_containsCorrectWord() {
        let (sut, spy) = makeSUT()
        sut.loadStory(.init(activity: makeActivity(), sceneIndex: 0))
        guard let scene = spy.lastLoadStory?.scene else { return }
        sut.chooseWord(.init(choiceIndex: scene.correctIndex))
        let filledText = spy.lastChooseWord?.filledStoryText ?? ""
        let correctWord = scene.choices[scene.correctIndex]
        XCTAssertTrue(filledText.contains(correctWord))
    }

    // MARK: - Batch 1: расширенное покрытие

    func test_loadStory_clampsNegativeIndex() {
        let (sut, spy) = makeSUT()
        sut.loadStory(.init(activity: makeActivity(), sceneIndex: -5))
        XCTAssertEqual(spy.lastLoadStory?.sceneIndex, 0)
    }

    func test_loadStory_clampsLargeIndex() {
        let (sut, spy) = makeSUT()
        sut.loadStory(.init(activity: makeActivity(), sceneIndex: 99))
        XCTAssertLessThanOrEqual(spy.lastLoadStory?.sceneIndex ?? 99, 4)
    }

    func test_chooseWord_correct_incrementsScore() {
        let (sut, spy) = makeSUT()
        sut.loadStory(.init(activity: makeActivity(), sceneIndex: 0))
        guard let scene = spy.lastLoadStory?.scene else { return }
        sut.chooseWord(.init(choiceIndex: scene.correctIndex))
        sut.complete()
        XCTAssertEqual(spy.lastComplete?.correctCount, 1)
    }

    func test_chooseWord_correctIndexInResponse() {
        let (sut, spy) = makeSUT()
        sut.loadStory(.init(activity: makeActivity(), sceneIndex: 0))
        guard let scene = spy.lastLoadStory?.scene else { return }
        sut.chooseWord(.init(choiceIndex: scene.correctIndex))
        XCTAssertEqual(spy.lastChooseWord?.correctIndex, scene.correctIndex)
    }

    func test_chooseWord_outOfBoundsIndex_emptyChosenWord() {
        let (sut, spy) = makeSUT()
        sut.loadStory(.init(activity: makeActivity(), sceneIndex: 0))
        sut.chooseWord(.init(choiceIndex: 99))
        XCTAssertEqual(spy.lastChooseWord?.chosenWord, "")
        XCTAssertEqual(spy.lastChooseWord?.isCorrect, false)
    }

    func test_chooseWord_afterComplete_ignored() {
        let (sut, spy) = makeSUT()
        sut.loadStory(.init(activity: makeActivity(), sceneIndex: 0))
        sut.complete()
        spy.chooseWordCalled = false
        sut.chooseWord(.init(choiceIndex: 0))
        XCTAssertFalse(spy.chooseWordCalled, "После complete chooseWord игнорируется")
    }

    func test_nextScene_emitsHasNextScene() {
        let (sut, spy) = makeSUT()
        sut.loadStory(.init(activity: makeActivity(), sceneIndex: 0))
        sut.nextScene()
        XCTAssertTrue(spy.nextSceneCalled)
    }

    func test_nextScene_lastScene_completes() {
        let (sut, spy) = makeSUT()
        sut.loadStory(.init(activity: makeActivity(), sceneIndex: 4))
        sut.nextScene()
        XCTAssertTrue(spy.completeCalled)
    }

    func test_complete_perfectGame_scoreOne() {
        let (sut, spy) = makeSUT()
        sut.loadStory(.init(activity: makeActivity(), sceneIndex: 0))
        // Отвечаем правильно на все 5 сцен
        for idx in 0..<5 {
            sut.loadStory(.init(activity: makeActivity(), sceneIndex: idx))
            guard let scene = spy.lastLoadStory?.scene else { break }
            sut.chooseWord(.init(choiceIndex: scene.correctIndex))
        }
        sut.complete()
        XCTAssertEqual(spy.lastComplete?.score, 1.0)
    }

    func test_loadStory_afterCancel_ignored() {
        let (sut, spy) = makeSUT()
        sut.loadStory(.init(activity: makeActivity(), sceneIndex: 0))
        sut.cancel()
        spy.loadStoryCalled = false
        sut.loadStory(.init(activity: makeActivity(), sceneIndex: 1))
        XCTAssertFalse(spy.loadStoryCalled, "После cancel loadStory игнорируется")
    }

    func test_resolveSoundGroup_unknownFallback() {
        XCTAssertEqual(StoryCompletionInteractor.resolveSoundGroup(for: "Б"), "whistling")
        XCTAssertEqual(StoryCompletionInteractor.resolveSoundGroup(for: ""), "whistling")
    }

    func test_buildScenes_allChoicesHaveThreeOptions() {
        for group in ["whistling", "hissing", "sonants", "velar"] {
            let scenes = StoryCompletionInteractor.buildScenes(for: group, total: 5)
            for scene in scenes {
                XCTAssertEqual(scene.choices.count, 3, "Сцена группы \(group) должна иметь 3 варианта")
                XCTAssertTrue(scene.choices.indices.contains(scene.correctIndex))
            }
        }
    }
}
