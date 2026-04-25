import Testing
@testable import HappySpeech

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

@Suite("StoryCompletionInteractor")
@MainActor
struct StoryCompletionInteractorTests {

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

    @Test("loadStory загружает сцену 0 и вызывает presentLoadStory")
    func loadStoryLoadsFirstScene() {
        let (sut, spy) = makeSUT()
        sut.loadStory(.init(activity: makeActivity(), sceneIndex: 0))
        #expect(spy.loadStoryCalled)
        #expect(spy.lastLoadStory?.sceneIndex == 0)
        #expect(spy.lastLoadStory?.totalScenes == 5)
    }

    // MARK: - 2. buildScenes возвращает 5 сцен

    @Test("buildScenes возвращает 5 сцен для каждой группы")
    func buildScenesReturnsFiveScenes() {
        for group in ["whistling", "hissing", "sonants", "velar"] {
            let scenes = StoryCompletionInteractor.buildScenes(for: group, total: 5)
            #expect(scenes.count == 5, "Группа \(group) должна иметь 5 сцен")
        }
    }

    // MARK: - 3. resolveSoundGroup

    @Test("resolveSoundGroup корректно маппит звуки")
    func resolveSoundGroup() {
        #expect(StoryCompletionInteractor.resolveSoundGroup(for: "С") == "whistling")
        #expect(StoryCompletionInteractor.resolveSoundGroup(for: "Ш") == "hissing")
        #expect(StoryCompletionInteractor.resolveSoundGroup(for: "Р") == "sonants")
        #expect(StoryCompletionInteractor.resolveSoundGroup(for: "К") == "velar")
    }

    // MARK: - 4. chooseWord: правильный ответ

    @Test("chooseWord с правильным индексом возвращает isCorrect = true")
    func chooseWordCorrect() {
        let (sut, spy) = makeSUT()
        sut.loadStory(.init(activity: makeActivity(), sceneIndex: 0))
        guard let scene = spy.lastLoadStory?.scene else { return }
        sut.chooseWord(.init(choiceIndex: scene.correctIndex))
        #expect(spy.chooseWordCalled)
        #expect(spy.lastChooseWord?.isCorrect == true)
    }

    // MARK: - 5. chooseWord: неправильный ответ

    @Test("chooseWord с неправильным индексом возвращает isCorrect = false")
    func chooseWordWrong() {
        let (sut, spy) = makeSUT()
        sut.loadStory(.init(activity: makeActivity(), sceneIndex: 0))
        guard let scene = spy.lastLoadStory?.scene else { return }
        let wrongIndex = scene.correctIndex == 0 ? 1 : 0
        sut.chooseWord(.init(choiceIndex: wrongIndex))
        #expect(spy.lastChooseWord?.isCorrect == false)
    }

    // MARK: - 6. complete вычисляет score

    @Test("complete передаёт score в диапазоне [0, 1]")
    func completeScoreInRange() {
        let (sut, spy) = makeSUT()
        sut.loadStory(.init(activity: makeActivity(), sceneIndex: 0))
        sut.complete()
        #expect(spy.completeCalled)
        let score = spy.lastComplete?.score ?? -1
        #expect(score >= 0 && score <= 1)
    }

    // MARK: - 7. complete дважды — игнорируется

    @Test("повторный вызов complete игнорируется")
    func completeTwiceIgnored() {
        let (sut, spy) = makeSUT()
        sut.loadStory(.init(activity: makeActivity(), sceneIndex: 0))
        sut.complete()
        let firstScore = spy.lastComplete?.score
        spy.lastComplete = nil
        sut.complete()
        #expect(spy.lastComplete == nil, "Второй complete не должен вызывать presenter")
        _ = firstScore
    }

    // MARK: - 8. cancel завершает игру без вызова complete

    @Test("cancel не вызывает presentComplete")
    func cancelDoesNotCallComplete() {
        let (sut, spy) = makeSUT()
        sut.loadStory(.init(activity: makeActivity(), sceneIndex: 0))
        sut.cancel()
        #expect(!spy.completeCalled)
    }

    // MARK: - 9. filledStoryText содержит правильное слово

    @Test("filledStoryText заменяет маркер правильным словом")
    func filledStoryTextContainsCorrectWord() {
        let (sut, spy) = makeSUT()
        sut.loadStory(.init(activity: makeActivity(), sceneIndex: 0))
        guard let scene = spy.lastLoadStory?.scene else { return }
        sut.chooseWord(.init(choiceIndex: scene.correctIndex))
        let filledText = spy.lastChooseWord?.filledStoryText ?? ""
        let correctWord = scene.choices[scene.correctIndex]
        #expect(filledText.contains(correctWord))
    }
}
