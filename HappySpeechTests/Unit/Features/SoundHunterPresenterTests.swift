@testable import HappySpeech
import XCTest

// MARK: - SoundHunterPresenterTests
//
// Phase 2.6.1 v25 — покрытие SoundHunterPresenter (12 тестов).
// Тестируются все 4 метода: presentLoadScene, presentTapItem,
// presentCompleteScene, presentNextScene.

@MainActor
final class SoundHunterPresenterTests: XCTestCase {

    // MARK: - DisplaySpy

    @MainActor
    private final class DisplaySpy: SoundHunterDisplayLogic {
        var loadSceneVM: SoundHunterModels.LoadScene.ViewModel?
        var tapItemVM: SoundHunterModels.TapItem.ViewModel?
        var completeSceneVM: SoundHunterModels.CompleteScene.ViewModel?
        var nextSceneVM: SoundHunterModels.NextScene.ViewModel?

        func displayLoadScene(_ viewModel: SoundHunterModels.LoadScene.ViewModel) { loadSceneVM = viewModel }
        func displayTapItem(_ viewModel: SoundHunterModels.TapItem.ViewModel) { tapItemVM = viewModel }
        func displayCompleteScene(_ viewModel: SoundHunterModels.CompleteScene.ViewModel) { completeSceneVM = viewModel }
        func displayNextScene(_ viewModel: SoundHunterModels.NextScene.ViewModel) { nextSceneVM = viewModel }
    }

    private func makeSUT() -> (SoundHunterPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = SoundHunterPresenter()
        presenter.viewModel = spy
        return (presenter, spy)
    }

    private func makeItem(hasTargetSound: Bool = true) -> HuntItem {
        HuntItem(word: "сок", icon: "juice", hasTargetSound: hasTargetSound)
    }

    // MARK: - presentLoadScene

    func test_presentLoadScene_hintContainsTargetSound() {
        let (sut, spy) = makeSUT()
        let response = SoundHunterModels.LoadScene.Response(
            items: [makeItem()],
            targetSound: "С",
            targetSoundGroup: "whistling",
            sceneIndex: 0,
            totalScenes: 3,
            totalCorrectNeeded: 3
        )
        sut.presentLoadScene(response)
        XCTAssertNotNil(spy.loadSceneVM)
        XCTAssertTrue(spy.loadSceneVM?.hintText.contains("С") ?? false)
    }

    func test_presentLoadScene_progressFraction_zeroAtStart() {
        let (sut, spy) = makeSUT()
        let response = SoundHunterModels.LoadScene.Response(
            items: [],
            targetSound: "Р",
            targetSoundGroup: "sonants",
            sceneIndex: 0,
            totalScenes: 3,
            totalCorrectNeeded: 3
        )
        sut.presentLoadScene(response)
        XCTAssertEqual(spy.loadSceneVM?.progressFraction ?? -1, 0.0, accuracy: 0.001)
    }

    func test_presentLoadScene_secondScene_progressNonZero() {
        let (sut, spy) = makeSUT()
        let response = SoundHunterModels.LoadScene.Response(
            items: [],
            targetSound: "С",
            targetSoundGroup: "whistling",
            sceneIndex: 1,
            totalScenes: 3,
            totalCorrectNeeded: 3
        )
        sut.presentLoadScene(response)
        // sceneIndex=1, correctCount=0 → progress = (1+0)/3 ≈ 0.333
        XCTAssertGreaterThan(spy.loadSceneVM?.progressFraction ?? 0, 0.0)
    }

    func test_presentLoadScene_passesTargetSoundThrough() {
        let (sut, spy) = makeSUT()
        let response = SoundHunterModels.LoadScene.Response(
            items: [makeItem(hasTargetSound: false)],
            targetSound: "Ш",
            targetSoundGroup: "hissing",
            sceneIndex: 0,
            totalScenes: 3,
            totalCorrectNeeded: 4
        )
        sut.presentLoadScene(response)
        XCTAssertEqual(spy.loadSceneVM?.targetSound, "Ш")
        XCTAssertEqual(spy.loadSceneVM?.totalCorrectNeeded, 4)
    }

    // MARK: - presentTapItem

    func test_presentTapItem_correctTap_progressIncreases() {
        let (sut, spy) = makeSUT()
        let itemId = UUID()
        let response = SoundHunterModels.TapItem.Response(
            itemId: itemId,
            newState: .correct,
            correctCount: 2,
            totalCorrectNeeded: 4,
            isSceneComplete: false
        )
        sut.presentTapItem(response)
        XCTAssertNotNil(spy.tapItemVM)
        XCTAssertEqual(spy.tapItemVM?.progressFraction ?? 0, 0.5, accuracy: 0.001)
        XCTAssertNil(spy.tapItemVM?.shakeItemId)
    }

    func test_presentTapItem_wrongTap_shakeIdSet() {
        let (sut, spy) = makeSUT()
        let itemId = UUID()
        let response = SoundHunterModels.TapItem.Response(
            itemId: itemId,
            newState: .wrong,
            correctCount: 0,
            totalCorrectNeeded: 4,
            isSceneComplete: false
        )
        sut.presentTapItem(response)
        XCTAssertEqual(spy.tapItemVM?.shakeItemId, itemId)
        XCTAssertEqual(spy.tapItemVM?.newState, .wrong)
    }

    func test_presentTapItem_sceneComplete_flagSet() {
        let (sut, spy) = makeSUT()
        let itemId = UUID()
        let response = SoundHunterModels.TapItem.Response(
            itemId: itemId,
            newState: .correct,
            correctCount: 4,
            totalCorrectNeeded: 4,
            isSceneComplete: true
        )
        sut.presentTapItem(response)
        XCTAssertTrue(spy.tapItemVM?.isSceneComplete ?? false)
    }

    // MARK: - presentCompleteScene

    func test_presentCompleteScene_3stars_excellentMessage() {
        let (sut, spy) = makeSUT()
        let response = SoundHunterModels.CompleteScene.Response(
            totalScore: 0.95,
            starsEarned: 3,
            isFinalScene: false
        )
        sut.presentCompleteScene(response)
        XCTAssertEqual(spy.completeSceneVM?.starsEarned, 3)
        XCTAssertFalse(spy.completeSceneVM?.completionMessage.isEmpty ?? true)
        XCTAssertFalse(spy.completeSceneVM?.scoreLabel.isEmpty ?? true)
        XCTAssertFalse(spy.completeSceneVM?.isFinalScene ?? true)
    }

    func test_presentCompleteScene_0stars_fallbackMessage() {
        let (sut, spy) = makeSUT()
        let response = SoundHunterModels.CompleteScene.Response(
            totalScore: 0.2,
            starsEarned: 0,
            isFinalScene: true
        )
        sut.presentCompleteScene(response)
        XCTAssertEqual(spy.completeSceneVM?.starsEarned, 0)
        XCTAssertTrue(spy.completeSceneVM?.isFinalScene ?? false)
        XCTAssertFalse(spy.completeSceneVM?.completionMessage.isEmpty ?? true)
    }

    func test_presentCompleteScene_scoreLabelContainsPercent() {
        let (sut, spy) = makeSUT()
        let response = SoundHunterModels.CompleteScene.Response(
            totalScore: 0.8,
            starsEarned: 2,
            isFinalScene: false
        )
        sut.presentCompleteScene(response)
        XCTAssertTrue(spy.completeSceneVM?.scoreLabel.contains("%") ?? false)
    }

    // MARK: - presentNextScene

    func test_presentNextScene_passesDataThrough() {
        let (sut, spy) = makeSUT()
        let items = [makeItem()]
        let response = SoundHunterModels.NextScene.Response(
            nextSceneIndex: 1,
            items: items,
            targetSound: "С",
            totalCorrectNeeded: 3
        )
        sut.presentNextScene(response)
        XCTAssertEqual(spy.nextSceneVM?.nextSceneIndex, 1)
        XCTAssertEqual(spy.nextSceneVM?.targetSound, "С")
        XCTAssertEqual(spy.nextSceneVM?.totalCorrectNeeded, 3)
        XCTAssertFalse(spy.nextSceneVM?.hintText.isEmpty ?? true)
    }

    func test_presentNextScene_hintContainsTargetSound() {
        let (sut, spy) = makeSUT()
        let response = SoundHunterModels.NextScene.Response(
            nextSceneIndex: 2,
            items: [],
            targetSound: "Ж",
            totalCorrectNeeded: 3
        )
        sut.presentNextScene(response)
        XCTAssertTrue(spy.nextSceneVM?.hintText.contains("Ж") ?? false)
    }
}
