@testable import HappySpeech
import XCTest

// MARK: - Spy Presenter

@MainActor
private final class SpyARSoundHunterPresenter: ARSoundHunterPresentationLogic {
    var startGameCallCount = 0
    var frameCallCount = 0
    var selectCardCallCount = 0
    var scoreCallCount = 0
    var nextRoundCallCount = 0
    var retryCallCount = 0

    var lastStartGame: ARSoundHunterModels.StartGame.Response?
    var lastFrame: ARSoundHunterModels.FrameClassified.Response?
    var lastSelectCard: ARSoundHunterModels.SelectCard.Response?
    var lastScore: ARSoundHunterModels.ScoreNaming.Response?
    var lastNextRound: ARSoundHunterModels.NextRound.Response?
    var lastRetryWord: String?

    func presentStartGame(_ response: ARSoundHunterModels.StartGame.Response) {
        startGameCallCount += 1
        lastStartGame = response
    }
    func presentFrameClassified(_ response: ARSoundHunterModels.FrameClassified.Response) {
        frameCallCount += 1
        lastFrame = response
    }
    func presentSelectCard(_ response: ARSoundHunterModels.SelectCard.Response) {
        selectCardCallCount += 1
        lastSelectCard = response
    }
    func presentScoreNaming(_ response: ARSoundHunterModels.ScoreNaming.Response) {
        scoreCallCount += 1
        lastScore = response
    }
    func presentNextRound(_ response: ARSoundHunterModels.NextRound.Response) {
        nextRoundCallCount += 1
        lastNextRound = response
    }
    func presentRetry(foundWord: String) {
        retryCallCount += 1
        lastRetryWord = foundWord
    }
}

// MARK: - Tests
//
// Покрывает VIP-логику «Звукового охотника»:
//   - startGame: разрешение целевого звука (override → профиль → дефолт),
//     возраст из профиля, режим camera/photoCards;
//   - frameClassified: анти-мерцание (lockFramesRequired подряд кадров),
//     прогресс захвата, «остывание» на пустых кадрах;
//   - scoreNaming: звёзды по совпадению слова + произношению, правило
//     «никаких звёзд за молчание»;
//   - selectCard / nextRound.
//
// Vision и запись звука — во View; здесь подаём `matches` и результаты скоринга
// как фикстуры.

@MainActor
final class ARSoundHunterInteractorTests: XCTestCase {

    private func makeSUT(
        children: [ChildProfileDTO] = []
    ) -> (ARSoundHunterInteractor, SpyARSoundHunterPresenter, SpyChildRepository) {
        let repo = SpyChildRepository(children: children)
        let sut = ARSoundHunterInteractor(
            classifier: MockVisionObjectClassifierWorker(),
            childRepository: repo
        )
        let spy = SpyARSoundHunterPresenter()
        sut.presenter = spy
        return (sut, spy, repo)
    }

    private func match(_ word: String, confidence: Float) -> SoundHunterMapping.Match {
        SoundHunterMapping.Match(visionLabel: word, word: word, confidence: confidence, sounds: ["ш"])
    }

    // MARK: - startGame

    func test_startGame_overrideSound_takesPrecedence() async {
        let (sut, spy, _) = makeSUT()
        sut.startGame(.init(childId: "", targetSoundOverride: "Р", cameraAvailable: true))
        await waitFor { spy.startGameCallCount == 1 }
        XCTAssertEqual(spy.lastStartGame?.targetSound, "Р")
        XCTAssertEqual(spy.lastStartGame?.mode, .camera)
    }

    func test_startGame_noOverride_usesChildFirstTargetSound() async {
        let profile = ChildProfileDTO(
            id: "c1", name: "Тест", age: 7, targetSounds: ["Ш", "Ж"], parentId: "p1"
        )
        let (sut, spy, _) = makeSUT(children: [profile])
        sut.startGame(.init(childId: "c1", cameraAvailable: true))
        await waitFor { spy.startGameCallCount == 1 }
        XCTAssertEqual(spy.lastStartGame?.targetSound, "Ш")
        XCTAssertEqual(spy.lastStartGame?.childAge, 7)
    }

    func test_startGame_noChild_noOverride_defaultsToS() async {
        let (sut, spy, _) = makeSUT()
        sut.startGame(.init(childId: "missing", cameraAvailable: true))
        await waitFor { spy.startGameCallCount == 1 }
        XCTAssertEqual(spy.lastStartGame?.targetSound, "С")
        XCTAssertEqual(spy.lastStartGame?.childAge, 6)
    }

    func test_startGame_noCamera_photoCardMode() async {
        let (sut, spy, _) = makeSUT()
        sut.startGame(.init(childId: "", targetSoundOverride: "С", cameraAvailable: false))
        await waitFor { spy.startGameCallCount == 1 }
        XCTAssertEqual(spy.lastStartGame?.mode, .photoCards)
    }

    // MARK: - frameClassified (anti-flicker lock)

    func test_frameClassified_singleFrame_doesNotLock() {
        let (sut, spy, _) = makeSUT()
        sut.frameClassified(.init(matches: [match("шарф", confidence: 0.9)]))
        XCTAssertNil(spy.lastFrame?.foundObject)
        XCTAssertGreaterThan(spy.lastFrame?.lockProgress ?? 0, 0)
        XCTAssertLessThan(spy.lastFrame?.lockProgress ?? 1, 1)
    }

    func test_frameClassified_sixConsecutiveFrames_locks() {
        let (sut, spy, _) = makeSUT()
        for _ in 0..<6 {
            sut.frameClassified(.init(matches: [match("шарф", confidence: 0.9)]))
        }
        XCTAssertEqual(spy.lastFrame?.foundObject?.word, "шарф")
        XCTAssertEqual(spy.lastFrame?.lockProgress, 1)
    }

    func test_frameClassified_afterLock_ignoresFurtherFrames() {
        let (sut, spy, _) = makeSUT()
        for _ in 0..<6 {
            sut.frameClassified(.init(matches: [match("шарф", confidence: 0.9)]))
        }
        let countAfterLock = spy.frameCallCount
        sut.frameClassified(.init(matches: [match("носок", confidence: 0.9)]))
        // После захвата кадры игнорируются — presenter не вызывается снова.
        XCTAssertEqual(spy.frameCallCount, countAfterLock)
    }

    func test_frameClassified_differentCandidate_resetsLock() {
        let (sut, spy, _) = makeSUT()
        // 3 кадра шарфа, затем смена кандидата — счётчик сбрасывается, lock не наступает.
        for _ in 0..<3 { sut.frameClassified(.init(matches: [match("шарф", confidence: 0.9)])) }
        for _ in 0..<4 { sut.frameClassified(.init(matches: [match("носок", confidence: 0.9)])) }
        XCTAssertNil(spy.lastFrame?.foundObject)
    }

    func test_frameClassified_lowConfidence_notCandidate() {
        let (sut, spy, _) = makeSUT()
        for _ in 0..<6 {
            sut.frameClassified(.init(matches: [match("шарф", confidence: 0.10)]))
        }
        // Уверенность ниже candidateConfidence — кандидат не засчитан, lock не наступает.
        XCTAssertNil(spy.lastFrame?.foundObject)
        XCTAssertEqual(spy.lastFrame?.lockProgress, 0)
    }

    func test_frameClassified_emptyFrame_decaysProgress() {
        let (sut, spy, _) = makeSUT()
        for _ in 0..<3 { sut.frameClassified(.init(matches: [match("шарф", confidence: 0.9)])) }
        let progressBeforeDecay = spy.lastFrame?.lockProgress ?? 0
        sut.frameClassified(.init(matches: []))
        XCTAssertLessThan(spy.lastFrame?.lockProgress ?? 1, progressBeforeDecay)
    }

    // MARK: - selectCard (fallback — target vs distractor)

    /// Поднимает фоллбэк-сетку (photoCards) с целевым звуком и возвращает,
    /// какие слова попали в сетку как целевые/дистракторы.
    private func startPhotoCardGame(
        sut: ARSoundHunterInteractor,
        spy: SpyARSoundHunterPresenter,
        sound: String
    ) async -> [SoundHunterMapping.GridCard] {
        sut.startGame(.init(childId: "", targetSoundOverride: sound, cameraAvailable: false))
        await waitFor { spy.startGameCallCount == 1 }
        return spy.lastStartGame?.gridCards ?? []
    }

    func test_selectCard_targetCard_proceedsToNaming() async {
        let (sut, spy, _) = makeSUT()
        let grid = await startPhotoCardGame(sut: sut, spy: spy, sound: "Ш")
        guard let target = grid.first(where: { $0.isTarget }) else {
            return XCTFail("В сетке не оказалось целевой карточки")
        }
        sut.selectCard(.init(cardId: target.match.word))
        XCTAssertNotNil(spy.lastSelectCard)
        XCTAssertTrue(spy.lastSelectCard?.isTarget ?? false)
        XCTAssertEqual(spy.lastSelectCard?.word, target.match.word)
    }

    func test_selectCard_distractorCard_softFeedbackNoStar() async {
        let (sut, spy, _) = makeSUT()
        let grid = await startPhotoCardGame(sut: sut, spy: spy, sound: "Ш")
        guard let distractor = grid.first(where: { !$0.isTarget }) else {
            return XCTFail("В сетке не оказалось дистрактора")
        }
        sut.selectCard(.init(cardId: distractor.match.word))
        // Дистрактор → isTarget=false, целевой звук передан для фидбэка, без
        // перехода к скорингу (звезда не присуждается).
        XCTAssertFalse(spy.lastSelectCard?.isTarget ?? true)
        XCTAssertEqual(spy.lastSelectCard?.targetSound, "Ш")
        XCTAssertEqual(spy.scoreCallCount, 0)
    }

    func test_startGame_photoCards_gridHasTargetsAndDistractors() async {
        let (sut, spy, _) = makeSUT()
        let grid = await startPhotoCardGame(sut: sut, spy: spy, sound: "Ш")
        XCTAssertGreaterThanOrEqual(grid.filter { $0.isTarget }.count, 1)
        XCTAssertGreaterThanOrEqual(grid.filter { !$0.isTarget }.count, 2)
    }

    // MARK: - scoreNaming

    func test_scoreNaming_matchedAndGoodPronunciation_threeStars() {
        let (sut, spy, _) = makeSUT()
        sut.scoreNaming(.init(
            word: "шарф", transcript: "шарф", asrConfidence: 0.9,
            pronunciationScore: PronunciationScore(rawValue: 0.85)
        ))
        XCTAssertEqual(spy.lastScore?.stars, 3)
        XCTAssertTrue(spy.lastScore?.matchedWord ?? false)
    }

    func test_scoreNaming_matchedWeakPronunciation_twoStars() {
        let (sut, spy, _) = makeSUT()
        sut.scoreNaming(.init(
            word: "шарф", transcript: "шарф", asrConfidence: 0.9,
            pronunciationScore: PronunciationScore(rawValue: 0.30)
        ))
        XCTAssertEqual(spy.lastScore?.stars, 2)
    }

    func test_scoreNaming_goodPronunciationNoWordMatch_twoStars() {
        let (sut, spy, _) = makeSUT()
        sut.scoreNaming(.init(
            word: "шарф", transcript: "кот", asrConfidence: 0.9,
            pronunciationScore: PronunciationScore(rawValue: 0.85)
        ))
        XCTAssertEqual(spy.lastScore?.stars, 2)
        XCTAssertFalse(spy.lastScore?.matchedWord ?? true)
    }

    func test_scoreNaming_neither_oneStarForEffort() {
        let (sut, spy, _) = makeSUT()
        // Что-то сказал (transcript непустой), но ни слова, ни произношения — 1★.
        sut.scoreNaming(.init(
            word: "шарф", transcript: "бубубу", asrConfidence: 0.4,
            pronunciationScore: PronunciationScore(rawValue: 0.20)
        ))
        XCTAssertEqual(spy.lastScore?.stars, 1)
    }

    func test_scoreNaming_silence_retriesWithoutStars() {
        let (sut, spy, _) = makeSUT()
        // Пустой transcript + notScored = молчание → повтор, БЕЗ звёзд.
        sut.scoreNaming(.init(
            word: "шарф", transcript: "", asrConfidence: 0,
            pronunciationScore: .notScored
        ))
        XCTAssertEqual(spy.scoreCallCount, 0)
        XCTAssertEqual(spy.retryCallCount, 1)
        XCTAssertEqual(spy.lastRetryWord, "шарф")
    }

    func test_scoreNaming_caseInsensitiveWordMatch() {
        let (sut, spy, _) = makeSUT()
        sut.scoreNaming(.init(
            word: "Шарф", transcript: "ШАРФ", asrConfidence: 0.9,
            pronunciationScore: PronunciationScore(rawValue: 0.9)
        ))
        XCTAssertTrue(spy.lastScore?.matchedWord ?? false)
    }

    func test_scoreNaming_partialTranscript_stillMatches() {
        let (sut, spy, _) = makeSUT()
        // ASR вернул короткое «шар» при слове «шарф» — частичное вхождение.
        sut.scoreNaming(.init(
            word: "шарф", transcript: "шар", asrConfidence: 0.7,
            pronunciationScore: PronunciationScore(rawValue: 0.9)
        ))
        XCTAssertTrue(spy.lastScore?.matchedWord ?? false)
    }

    // MARK: - nextRound

    func test_nextRound_accumulatesTotalFound() {
        let (sut, spy, _) = makeSUT()
        sut.scoreNaming(.init(
            word: "шарф", transcript: "шарф", asrConfidence: 0.9,
            pronunciationScore: PronunciationScore(rawValue: 0.85)
        ))
        sut.nextRound(.init())
        XCTAssertEqual(spy.lastNextRound?.totalFound, 1)
    }

    func test_nextRound_resetsLockSoNewObjectCanBeFound() {
        let (sut, spy, _) = makeSUT()
        for _ in 0..<6 { sut.frameClassified(.init(matches: [match("шарф", confidence: 0.9)])) }
        XCTAssertNotNil(spy.lastFrame?.foundObject)
        sut.nextRound(.init())
        // После сброса новый предмет снова можно захватить.
        for _ in 0..<6 { sut.frameClassified(.init(matches: [match("носок", confidence: 0.9)])) }
        XCTAssertEqual(spy.lastFrame?.foundObject?.word, "носок")
    }

    // MARK: - Helper

    /// Поллинг условия (для async-startGame, который завершает Task на MainActor).
    private func waitFor(
        timeout: TimeInterval = 2,
        _ condition: @escaping () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertTrue(condition(), "Условие не выполнилось за \(timeout)с")
    }
}
