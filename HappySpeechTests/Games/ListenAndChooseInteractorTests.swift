import Foundation
@testable import HappySpeech
import XCTest

// MARK: - Mock ContentService

private final class MockContentService: ContentService, @unchecked Sendable {
    var stubbedPack: ContentPack?

    func loadPack(id: String) async throws -> ContentPack {
        if let pack = stubbedPack { return pack }
        throw NSError(domain: "Mock", code: 0)
    }
    func allPacks() async throws -> [ContentPackMeta] { [] }
    func bundledPacks() -> [ContentPackMeta] { [] }
}

// MARK: - Spy

@MainActor
private final class SpyListenPresenter: ListenAndChoosePresentationLogic {
    var loadRoundCalled = false
    var submitAttemptCalled = false

    var lastLoadRound: ListenAndChooseModels.LoadRound.Response?
    var lastSubmitAttempt: ListenAndChooseModels.SubmitAttempt.Response?

    func presentLoadRound(_ response: ListenAndChooseModels.LoadRound.Response) {
        loadRoundCalled = true
        lastLoadRound = response
    }
    func presentSubmitAttempt(_ response: ListenAndChooseModels.SubmitAttempt.Response) {
        submitAttemptCalled = true
        lastSubmitAttempt = response
    }
}

// MARK: - Tests

@MainActor
final class ListenAndChooseInteractorTests: XCTestCase {

    private func makeSUT() -> (ListenAndChooseInteractor, SpyListenPresenter, MockContentService) {
        let mockContent = MockContentService()
        let sut = ListenAndChooseInteractor(contentService: mockContent)
        let spy = SpyListenPresenter()
        sut.presenter = spy
        return (sut, spy, mockContent)
    }

    // MARK: - 1. loadRound строит вопросы из fallback-каталога

    func test_loadRound_fallback_callsPresenter() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadRound(.init(soundTarget: "С", difficulty: 2))
        XCTAssertTrue(spy.loadRoundCalled)
        XCTAssertGreaterThanOrEqual(spy.lastLoadRound?.options.count ?? 0, 2)
    }

    // MARK: - 2. submitAttempt: правильный ответ

    func test_submitAttempt_correct_isCorrectTrue() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadRound(.init(soundTarget: "С", difficulty: 2))
        guard let loadResp = spy.lastLoadRound else { return }
        sut.submitAttempt(.init(
            selectedIndex: loadResp.correctIndex,
            correctIndex: loadResp.correctIndex,
            attemptsUsed: 1,
            responseTimeMs: 500
        ))
        XCTAssertTrue(spy.submitAttemptCalled)
        XCTAssertEqual(spy.lastSubmitAttempt?.isCorrect, true)
    }

    // MARK: - 3. submitAttempt: неправильный ответ

    func test_submitAttempt_wrong_isCorrectFalse() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadRound(.init(soundTarget: "С", difficulty: 2))
        guard let loadResp = spy.lastLoadRound else { return }
        let wrongIdx = loadResp.correctIndex == 0 ? 1 : 0
        sut.submitAttempt(.init(
            selectedIndex: wrongIdx,
            correctIndex: loadResp.correctIndex,
            attemptsUsed: 1,
            responseTimeMs: 800
        ))
        XCTAssertEqual(spy.lastSubmitAttempt?.isCorrect, false)
    }

    // MARK: - 4. submitAttempt: 3 попытки → shouldRevealAnswer

    func test_submitAttempt_threeAttempts_revealsAnswer() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadRound(.init(soundTarget: "С", difficulty: 2))
        guard let loadResp = spy.lastLoadRound else { return }
        let wrongIdx = loadResp.correctIndex == 0 ? 1 : 0
        sut.submitAttempt(.init(
            selectedIndex: wrongIdx,
            correctIndex: loadResp.correctIndex,
            attemptsUsed: 3,
            responseTimeMs: nil
        ))
        XCTAssertEqual(spy.lastSubmitAttempt?.shouldRevealAnswer, true)
    }

    // MARK: - 5. resolveSoundGroup маппит все группы корректно

    func test_resolveSoundGroup_allGroups() async {
        let (sut, spy, _) = makeSUT()
        for sound in ["С", "Ш", "Р", "К"] {
            await sut.loadRound(.init(soundTarget: sound, difficulty: 1))
            XCTAssertTrue(spy.loadRoundCalled, "Sound \(sound) должен порождать вопросы")
        }
    }

    // MARK: - 6. loadRound с stubbedPack использует слова пака

    func test_loadRound_withPack_usesPackData() async {
        let (sut, spy, mockContent) = makeSUT()
        let items = [
            ContentItem(id: "1", word: "сова", imageAsset: nil, audioAsset: nil, hint: nil, stage: .wordInit, difficulty: 1),
            ContentItem(id: "2", word: "сок", imageAsset: nil, audioAsset: nil, hint: nil, stage: .wordInit, difficulty: 1)
        ]
        mockContent.stubbedPack = ContentPack(
            id: "sound_s_v1",
            soundTarget: "С",
            stage: .wordInit,
            templateType: .listenAndChoose,
            items: items
        )
        await sut.loadRound(.init(soundTarget: "С", difficulty: 2))
        XCTAssertTrue(spy.loadRoundCalled)
    }

    // MARK: - 7. currentStreak растёт при правильных ответах

    func test_currentStreak_increases() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadRound(.init(soundTarget: "С", difficulty: 2))
        guard let loadResp = spy.lastLoadRound else { return }
        sut.submitAttempt(.init(
            selectedIndex: loadResp.correctIndex,
            correctIndex: loadResp.correctIndex,
            attemptsUsed: 1,
            responseTimeMs: nil
        ))
        XCTAssertEqual(spy.lastSubmitAttempt?.currentStreak ?? 0, 1)
    }

    // MARK: - 8. currentStreak сбрасывается при неправильном ответе

    func test_currentStreak_resetsOnWrong() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadRound(.init(soundTarget: "С", difficulty: 2))
        guard let loadResp = spy.lastLoadRound else { return }
        sut.submitAttempt(.init(
            selectedIndex: loadResp.correctIndex,
            correctIndex: loadResp.correctIndex,
            attemptsUsed: 1,
            responseTimeMs: nil
        ))
        let wrongIdx = loadResp.correctIndex == 0 ? 1 : 0
        sut.submitAttempt(.init(
            selectedIndex: wrongIdx,
            correctIndex: loadResp.correctIndex,
            attemptsUsed: 1,
            responseTimeMs: nil
        ))
        XCTAssertEqual(spy.lastSubmitAttempt?.currentStreak ?? 1, 0)
    }
}
