@testable import HappySpeech
import XCTest

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

@MainActor
final class SoundHunterInteractorTests: XCTestCase {

    private func makeSUT(sound: String = "С") -> (SoundHunterInteractor, SpySoundHunterPresenter) {
        let spy = SpySoundHunterPresenter()
        let sut = SoundHunterInteractor(targetSound: sound)
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - 1. loadScene загружает 9 предметов

    func test_loadScene_loads9Items() {
        let (sut, spy) = makeSUT()
        sut.loadScene(.init(sceneIndex: 0))
        XCTAssertTrue(spy.loadSceneCalled)
        XCTAssertEqual(spy.lastLoadScene?.items.count, 9)
    }

    // MARK: - 2. resolveSoundGroup

    func test_resolveSoundGroup_allGroups() {
        XCTAssertEqual(SoundHunterInteractor.resolveSoundGroup(for: "С"), "whistling")
        XCTAssertEqual(SoundHunterInteractor.resolveSoundGroup(for: "Ш"), "hissing")
        XCTAssertEqual(SoundHunterInteractor.resolveSoundGroup(for: "Р"), "sonants")
        XCTAssertEqual(SoundHunterInteractor.resolveSoundGroup(for: "К"), "velar")
    }

    // MARK: - 3. tapItem на правильный предмет

    func test_tapCorrectItem_stateCorrect() {
        let (sut, spy) = makeSUT(sound: "С")
        sut.loadScene(.init(sceneIndex: 0))
        guard let scene = spy.lastLoadScene else { return }
        guard let correctItem = scene.items.first(where: { $0.hasTargetSound }) else {
            XCTFail("В сцене нет правильных предметов")
            return
        }
        sut.tapItem(.init(itemId: correctItem.id))
        XCTAssertTrue(spy.tapItemCalled)
        XCTAssertEqual(spy.lastTapItem?.newState, .correct)
    }

    // MARK: - 4. tapItem на неправильный предмет

    func test_tapWrongItem_stateWrong() {
        let (sut, spy) = makeSUT(sound: "С")
        sut.loadScene(.init(sceneIndex: 0))
        guard let scene = spy.lastLoadScene else { return }
        guard let wrongItem = scene.items.first(where: { !$0.hasTargetSound }) else { return }
        sut.tapItem(.init(itemId: wrongItem.id))
        XCTAssertEqual(spy.lastTapItem?.newState, .wrong)
    }

    // MARK: - 5. correctCount растёт после правильного тапа

    func test_correctCount_grows() {
        let (sut, spy) = makeSUT()
        sut.loadScene(.init(sceneIndex: 0))
        guard let scene = spy.lastLoadScene else { return }
        let correctItems = scene.items.filter(\.hasTargetSound)
        guard !correctItems.isEmpty else { return }

        sut.tapItem(.init(itemId: correctItems[0].id))
        XCTAssertEqual(spy.lastTapItem?.correctCount ?? 0, 1)
    }

    // MARK: - 6. completeGame → score in [0,1]

    func test_completeGame_scoreInRange() {
        let (sut, spy) = makeSUT()
        sut.loadScene(.init(sceneIndex: 0))
        sut.completeGame()
        XCTAssertTrue(spy.completeSceneCalled)
        let score = spy.lastCompleteScene?.totalScore ?? -1
        XCTAssertGreaterThanOrEqual(score, 0)
        XCTAssertLessThanOrEqual(score, 1)
    }

    // MARK: - 7. buildScenes возвращает 3 сцены для каждой группы

    func test_buildScenes_3PerGroup() {
        for group in ["whistling", "hissing", "sonants", "velar"] {
            let scenes = SoundHunterInteractor.buildScenes(for: group)
            XCTAssertEqual(scenes.count, 3, "Группа \(group) должна иметь 3 сцены")
        }
    }

    // MARK: - 8. повторный tap на правильный предмет игнорируется

    func test_doubleTap_ignored() {
        let (sut, spy) = makeSUT()
        sut.loadScene(.init(sceneIndex: 0))
        guard let scene = spy.lastLoadScene,
              let correctItem = scene.items.first(where: { $0.hasTargetSound }) else { return }

        sut.tapItem(.init(itemId: correctItem.id))
        let countAfterFirst = spy.lastTapItem?.correctCount ?? 0
        sut.tapItem(.init(itemId: correctItem.id))
        let countAfterSecond = spy.lastTapItem?.correctCount ?? 0
        XCTAssertEqual(countAfterFirst, countAfterSecond)
    }
}
