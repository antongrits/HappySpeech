import Testing
@testable import HappySpeech

// MARK: - Spy

@MainActor
private final class SpySoundHunterPresenter: SoundHunterPresentationLogic {
    var loadSceneCalled = false
    var tapItemCalled = false
    var completeSceneCalled = false
    var nextSceneCalled = false

    var lastLoadScene: SoundHunterModels.LoadScene.Response?
    var lastTapItem: SoundHunterModels.TapItem.Response?
    var lastCompleteScene: SoundHunterModels.CompleteScene.Response?

    func presentLoadScene(_ response: SoundHunterModels.LoadScene.Response) {
        loadSceneCalled = true
        lastLoadScene = response
    }
    func presentTapItem(_ response: SoundHunterModels.TapItem.Response) {
        tapItemCalled = true
        lastTapItem = response
    }
    func presentCompleteScene(_ response: SoundHunterModels.CompleteScene.Response) {
        completeSceneCalled = true
        lastCompleteScene = response
    }
    func presentNextScene(_ response: SoundHunterModels.NextScene.Response) {
        nextSceneCalled = true
    }
}

// MARK: - Tests

@Suite("SoundHunterInteractor")
@MainActor
struct SoundHunterInteractorTests {

    private func makeSUT(sound: String = "С") -> (SoundHunterInteractor, SpySoundHunterPresenter) {
        let spy = SpySoundHunterPresenter()
        let sut = SoundHunterInteractor(targetSound: sound)
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - 1. loadScene загружает 9 предметов

    @Test("loadScene загружает ровно 9 предметов для сцены 0")
    func loadSceneLoads9Items() {
        let (sut, spy) = makeSUT()
        sut.loadScene(.init(sceneIndex: 0))
        #expect(spy.loadSceneCalled)
        #expect(spy.lastLoadScene?.items.count == 9)
    }

    // MARK: - 2. resolveSoundGroup

    @Test("resolveSoundGroup корректно маппит все группы")
    func resolveSoundGroup() {
        #expect(SoundHunterInteractor.resolveSoundGroup(for: "С") == "whistling")
        #expect(SoundHunterInteractor.resolveSoundGroup(for: "Ш") == "hissing")
        #expect(SoundHunterInteractor.resolveSoundGroup(for: "Р") == "sonants")
        #expect(SoundHunterInteractor.resolveSoundGroup(for: "К") == "velar")
    }

    // MARK: - 3. tapItem на правильный предмет

    @Test("tapItem на предмет с целевым звуком даёт newState = correct")
    func tapCorrectItem() {
        let (sut, spy) = makeSUT(sound: "С")
        sut.loadScene(.init(sceneIndex: 0))
        guard let scene = spy.lastLoadScene else { return }
        guard let correctItem = scene.items.first(where: { $0.hasTargetSound }) else {
            Issue.record("В сцене нет правильных предметов")
            return
        }
        sut.tapItem(.init(itemId: correctItem.id))
        #expect(spy.tapItemCalled)
        #expect(spy.lastTapItem?.newState == .correct)
    }

    // MARK: - 4. tapItem на неправильный предмет

    @Test("tapItem на предмет без целевого звука даёт newState = wrong")
    func tapWrongItem() {
        let (sut, spy) = makeSUT(sound: "С")
        sut.loadScene(.init(sceneIndex: 0))
        guard let scene = spy.lastLoadScene else { return }
        guard let wrongItem = scene.items.first(where: { !$0.hasTargetSound }) else { return }
        sut.tapItem(.init(itemId: wrongItem.id))
        #expect(spy.lastTapItem?.newState == .wrong)
    }

    // MARK: - 5. correctCount растёт после правильного тапа

    @Test("correctCount увеличивается после каждого правильного тапа")
    func correctCountGrowsOnCorrectTap() {
        let (sut, spy) = makeSUT()
        sut.loadScene(.init(sceneIndex: 0))
        guard let scene = spy.lastLoadScene else { return }
        let correctItems = scene.items.filter(\.hasTargetSound)
        guard !correctItems.isEmpty else { return }

        sut.tapItem(.init(itemId: correctItems[0].id))
        #expect((spy.lastTapItem?.correctCount ?? 0) == 1)
    }

    // MARK: - 6. completeGame вызывает presenter с finalScore

    @Test("completeGame передаёт score в диапазоне [0, 1]")
    func completeGameScoreInRange() {
        let (sut, spy) = makeSUT()
        sut.loadScene(.init(sceneIndex: 0))
        sut.completeGame()
        #expect(spy.completeSceneCalled)
        let score = spy.lastCompleteScene?.totalScore ?? -1
        #expect(score >= 0 && score <= 1)
    }

    // MARK: - 7. buildScenes возвращает 3 сцены для каждой группы

    @Test("buildScenes возвращает 3 сцены для каждой группы")
    func buildScenesReturns3PerGroup() {
        for group in ["whistling", "hissing", "sonants", "velar"] {
            let scenes = SoundHunterInteractor.buildScenes(for: group)
            #expect(scenes.count == 3, "Группа \(group) должна иметь 3 сцены")
        }
    }

    // MARK: - 8. повторный tap на обработанный предмет игнорируется

    @Test("повторный tapItem на уже правильный предмет игнорируется")
    func doubleTapIgnored() {
        let (sut, spy) = makeSUT()
        sut.loadScene(.init(sceneIndex: 0))
        guard let scene = spy.lastLoadScene,
              let correctItem = scene.items.first(where: { $0.hasTargetSound }) else { return }

        sut.tapItem(.init(itemId: correctItem.id))
        let countAfterFirst = spy.lastTapItem?.correctCount ?? 0
        sut.tapItem(.init(itemId: correctItem.id))
        let countAfterSecond = spy.lastTapItem?.correctCount ?? 0
        #expect(countAfterFirst == countAfterSecond)
    }
}
