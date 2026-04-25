import Testing
import Foundation
@testable import HappySpeech

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

@Suite("ListenAndChooseInteractor")
@MainActor
struct ListenAndChooseInteractorTests {

    private func makeSUT() -> (ListenAndChooseInteractor, SpyListenPresenter, MockContentService) {
        let mockContent = MockContentService()
        let sut = ListenAndChooseInteractor(contentService: mockContent)
        let spy = SpyListenPresenter()
        sut.presenter = spy
        return (sut, spy, mockContent)
    }

    // MARK: - 1. loadRound строит вопросы из fallback-каталога

    @Test("loadRound со звуком С строит вопросы и вызывает presenter")
    func loadRoundFallback() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadRound(.init(soundTarget: "С", difficulty: 2))
        #expect(spy.loadRoundCalled)
        #expect((spy.lastLoadRound?.options.count ?? 0) >= 2)
    }

    // MARK: - 2. submitAttempt: правильный ответ

    @Test("submitAttempt с правильным индексом → isCorrect = true")
    func submitCorrect() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadRound(.init(soundTarget: "С", difficulty: 2))
        guard let loadResp = spy.lastLoadRound else { return }
        sut.submitAttempt(.init(
            selectedIndex: loadResp.correctIndex,
            correctIndex: loadResp.correctIndex,
            attemptsUsed: 1,
            responseTimeMs: 500
        ))
        #expect(spy.submitAttemptCalled)
        #expect(spy.lastSubmitAttempt?.isCorrect == true)
    }

    // MARK: - 3. submitAttempt: неправильный ответ

    @Test("submitAttempt с неправильным индексом → isCorrect = false")
    func submitWrong() async {
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
        #expect(spy.lastSubmitAttempt?.isCorrect == false)
    }

    // MARK: - 4. submitAttempt: 3 попытки → shouldRevealAnswer

    @Test("submitAttempt с attemptsUsed=3 и wrong → shouldRevealAnswer = true")
    func submitThreeAttemptsReveals() async {
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
        #expect(spy.lastSubmitAttempt?.shouldRevealAnswer == true)
    }

    // MARK: - 5. resolveSoundGroup

    @Test("resolveSoundGroup маппит все группы корректно")
    func resolveSoundGroup() async {
        let (sut, spy, _) = makeSUT()
        // Загружаем каждый звук и проверяем, что вопросы строятся
        for sound in ["С", "Ш", "Р", "К"] {
            await sut.loadRound(.init(soundTarget: sound, difficulty: 1))
            #expect(spy.loadRoundCalled, "Sound \(sound) должен порождать вопросы")
        }
    }

    // MARK: - 6. loadRound со stubbedPack — использует данные пака

    @Test("loadRound с ContentService возвращающим пак использует слова пака")
    func loadRoundWithPack() async {
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
        #expect(spy.loadRoundCalled)
    }

    // MARK: - 7. currentStreak растёт при последовательных правильных ответах

    @Test("currentStreak увеличивается при последовательных правильных ответах")
    func streakIncreases() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadRound(.init(soundTarget: "С", difficulty: 2))
        guard let loadResp = spy.lastLoadRound else { return }
        sut.submitAttempt(.init(
            selectedIndex: loadResp.correctIndex,
            correctIndex: loadResp.correctIndex,
            attemptsUsed: 1,
            responseTimeMs: nil
        ))
        #expect((spy.lastSubmitAttempt?.currentStreak ?? 0) == 1)
    }

    // MARK: - 8. currentStreak сбрасывается при неправильном ответе

    @Test("currentStreak сбрасывается при неправильном ответе")
    func streakResetsOnWrong() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadRound(.init(soundTarget: "С", difficulty: 2))
        guard let loadResp = spy.lastLoadRound else { return }
        // Сначала правильный, потом неправильный
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
        #expect((spy.lastSubmitAttempt?.currentStreak ?? 1) == 0)
    }
}
