@testable import HappySpeech
import XCTest

// MARK: - ListenYourselfInteractorTests
//
// «Послушай себя» — слуховой самоконтроль. Покрываем ключевые ветки:
//   • загрузка слова + опор артикуляции;
//   • запись 2 дублей через AudioService (реальный пайплайн, мок-сервис);
//   • выбор лучшего дубля РЕБЁНКОМ (сохранение выбора);
//   • переход к сравнению + самооценка (эмодзи, без цифр);
//   • фиксация рефлексии в FSRS-планировщике по собственному суждению ребёнка;
//   • опциональный «секретный совет» (ASR) — после выбора;
//   • без сервисов записи дубль НЕ фабрикуется (мягкая ошибка).

@MainActor
final class ListenYourselfInteractorTests: XCTestCase {

    // MARK: - Capturing presenter

    private final class SpyPresenter: ListenYourselfPresentationLogic {
        var loadedWord: ListenYourselfModels.LoadWord.Response?
        var recordingStartedNumbers: [Int] = []
        var recordedTakes: [(response: ListenYourselfModels.RecordTake.Response, suggested: Int?)] = []
        var recordingFailedMessages: [String] = []
        var choices: [Int] = []
        var compares: [(word: String, chosen: Int)] = []
        var judges: [ListenYourselfModels.Judge.Response] = []
        var secretTips: [String?] = []
        var resetCount = 0

        func presentLoadWord(response: ListenYourselfModels.LoadWord.Response) async { loadedWord = response }
        func presentRecordingStarted(takeNumber: Int) async { recordingStartedNumbers.append(takeNumber) }
        func presentRecordTake(response: ListenYourselfModels.RecordTake.Response, suggestedChoice: Int?) async {
            recordedTakes.append((response, suggestedChoice))
        }
        func presentRecordingFailed(message: String) async { recordingFailedMessages.append(message) }
        func presentChoice(response: ListenYourselfModels.ChooseTake.Response) { choices.append(response.chosenTakeNumber) }
        func presentCompare(word: String, chosenTakeNumber: Int) { compares.append((word, chosenTakeNumber)) }
        func presentJudge(response: ListenYourselfModels.Judge.Response) async { judges.append(response) }
        func presentSecretTip(response: ListenYourselfModels.SecretTip.Response) async { secretTips.append(response.tip) }
        func presentReset() { resetCount += 1 }
    }

    // MARK: - Controllable scorer

    private final class StubScorer: PronunciationScorerService, @unchecked Sendable {
        let isModelLoaded = true
        let value: Double
        init(value: Double) { self.value = value }
        func score(audioURL: URL, targetSound: String) async throws -> PronunciationScore {
            PronunciationScore(rawValue: value)
        }
        func loadModel() async throws {}
    }

    // MARK: - Factory

    private func makeSUT(
        presenter: SpyPresenter,
        audio: (any AudioService)? = MockAudioService(),
        asr: (any ASRService)? = MockASRService(),
        scorer: (any PronunciationScorerService)? = StubScorer(value: 0.8),
        planner: MockAdaptivePlannerService? = nil,
        childRepo: (any ChildRepository)? = nil,
        childId: String = "kid-1"
    ) -> ListenYourselfInteractor {
        let worker = SelfCompareSessionWorker(
            audioService: audio,
            asrService: asr,
            scorer: scorer,
            voiceService: nil
        )
        return ListenYourselfInteractor(
            presenter: presenter,
            worker: worker,
            adaptivePlanner: planner,
            childRepository: childRepo,
            childId: childId
        )
    }

    // MARK: - loadWord

    func test_loadWord_presentsDeterministicWordAndLetter() async {
        let spy = SpyPresenter()
        let sut = makeSUT(presenter: spy)
        await sut.loadWord(.init(childId: "kid-1"))
        let loaded = spy.loadedWord
        XCTAssertNotNil(loaded)
        XCTAssertFalse(loaded?.word.isEmpty ?? true)
        XCTAssertFalse(loaded?.targetSound.isEmpty ?? true)
        XCTAssertEqual(loaded?.highlightLetter, loaded?.targetSound.uppercased())
        XCTAssertEqual(sut.phase, .intro)
    }

    func test_loadWord_resolvesRealChildAge() async {
        // Возраст ребёнка берётся из репозитория, не хардкод.
        let profile = ChildProfileDTO(id: "kid-age", name: "Тест", age: 8, targetSounds: ["Р"], parentId: "p")
        let repo = MockChildRepository(children: [profile])
        let spy = SpyPresenter()
        let sut = makeSUT(presenter: spy, childRepo: repo, childId: "kid-age")
        await sut.loadWord(.init(childId: "kid-age"))
        // Возраст влияет только на совет; проверяем, что загрузка прошла без сбоя.
        XCTAssertEqual(sut.phase, .intro)
        XCTAssertNotNil(spy.loadedWord)
    }

    // MARK: - Recording two takes

    func test_recordTwoTakes_buildsTwoTakes_andEntersChoosing() async {
        let spy = SpyPresenter()
        let sut = makeSUT(presenter: spy)
        await sut.loadWord(.init(childId: "kid-1"))

        await sut.recordTake(.init())
        XCTAssertEqual(sut.takes.count, 1)
        XCTAssertEqual(sut.phase, .intro) // после первого дубля — снова intro

        await sut.recordTake(.init())
        XCTAssertEqual(sut.takes.count, 2)
        XCTAssertEqual(sut.phase, .choosing)
        // Авто-предложен второй дубль, но решение за ребёнком.
        XCTAssertEqual(sut.chosenTakeNumber, 2)
        XCTAssertTrue(spy.recordedTakes.last?.response.bothTakesReady ?? false)
    }

    func test_recordTake_neverExceedsTwoTakes() async {
        let spy = SpyPresenter()
        let sut = makeSUT(presenter: spy)
        await sut.loadWord(.init(childId: "kid-1"))
        await sut.recordTake(.init())
        await sut.recordTake(.init())
        await sut.recordTake(.init()) // третий — игнорируется
        XCTAssertEqual(sut.takes.count, 2)
    }

    func test_recordTake_withoutAudioService_doesNotFabricateTake() async {
        // Без сервиса записи дубль НЕ создаётся (целостность данных).
        let spy = SpyPresenter()
        let sut = makeSUT(presenter: spy, audio: nil)
        await sut.loadWord(.init(childId: "kid-1"))
        await sut.recordTake(.init())
        XCTAssertEqual(sut.takes.count, 0)
        XCTAssertFalse(spy.recordingFailedMessages.isEmpty)
    }

    // MARK: - Child chooses best take

    func test_chooseTake_savesChildChoice() async {
        let spy = SpyPresenter()
        let sut = makeSUT(presenter: spy)
        await sut.loadWord(.init(childId: "kid-1"))
        await sut.recordTake(.init())
        await sut.recordTake(.init())

        sut.chooseTake(.init(takeNumber: 1))
        XCTAssertEqual(sut.chosenTakeNumber, 1)
        XCTAssertEqual(spy.choices.last, 1)
    }

    func test_chooseTake_ignoresUnknownTake() async {
        let spy = SpyPresenter()
        let sut = makeSUT(presenter: spy)
        await sut.loadWord(.init(childId: "kid-1"))
        await sut.recordTake(.init())
        await sut.recordTake(.init())
        let before = sut.chosenTakeNumber
        sut.chooseTake(.init(takeNumber: 9))
        XCTAssertEqual(sut.chosenTakeNumber, before)
    }

    // MARK: - goToCompare

    func test_goToCompare_requiresBothTakes() async {
        let spy = SpyPresenter()
        let sut = makeSUT(presenter: spy)
        await sut.loadWord(.init(childId: "kid-1"))
        await sut.recordTake(.init()) // only one
        sut.goToCompare()
        XCTAssertTrue(spy.compares.isEmpty)
        XCTAssertNotEqual(sut.phase, .comparing)
    }

    func test_goToCompare_movesToComparing() async {
        let spy = SpyPresenter()
        let sut = makeSUT(presenter: spy)
        await sut.loadWord(.init(childId: "kid-1"))
        await sut.recordTake(.init())
        await sut.recordTake(.init())
        sut.chooseTake(.init(takeNumber: 1))
        sut.goToCompare()
        XCTAssertEqual(sut.phase, .comparing)
        XCTAssertEqual(spy.compares.last?.chosen, 1)
    }

    // MARK: - Self-judgement (no numeric score)

    func test_judge_close_feedsScheduler_correctTrue() async {
        let planner = MockAdaptivePlannerService()
        let spy = SpyPresenter()
        let sut = makeSUT(presenter: spy, planner: planner, childId: "kid-J")
        await sut.loadWord(.init(childId: "kid-J"))
        await sut.judge(.init(judgement: .close))

        XCTAssertEqual(sut.judgement, .close)
        XCTAssertEqual(planner.recordedItemOutcomes.count, 1)
        XCTAssertEqual(planner.recordedItemOutcomes.first?.childId, "kid-J")
        XCTAssertEqual(planner.recordedItemOutcomes.first?.correct, true)
        XCTAssertFalse(spy.judges.last?.mascotMessage.isEmpty ?? true)
    }

    func test_judge_almost_feedsScheduler_correctFalse() async {
        let planner = MockAdaptivePlannerService()
        let spy = SpyPresenter()
        let sut = makeSUT(presenter: spy, planner: planner)
        await sut.loadWord(.init(childId: "kid-1"))
        await sut.judge(.init(judgement: .almost))
        XCTAssertEqual(planner.recordedItemOutcomes.first?.correct, false)
    }

    func test_judge_like_isMastered() async {
        let planner = MockAdaptivePlannerService()
        let spy = SpyPresenter()
        let sut = makeSUT(presenter: spy, planner: planner)
        await sut.loadWord(.init(childId: "kid-1"))
        await sut.judge(.init(judgement: .like))
        XCTAssertEqual(planner.recordedItemOutcomes.first?.correct, true)
    }

    func test_judge_recordsAgainstWordAndSound() async {
        let planner = MockAdaptivePlannerService()
        let spy = SpyPresenter()
        let sut = makeSUT(presenter: spy, planner: planner)
        await sut.loadWord(.init(childId: "kid-1"))
        await sut.judge(.init(judgement: .close))
        let outcome = planner.recordedItemOutcomes.first
        XCTAssertEqual(outcome?.itemId, sut.word)
        XCTAssertEqual(outcome?.sound, sut.targetSound)
    }

    // MARK: - Secret tip (optional ASR, after choice)

    func test_secretTip_withScorerAndASR_producesTip() async {
        let spy = SpyPresenter()
        let sut = makeSUT(presenter: spy, scorer: StubScorer(value: 0.8))
        await sut.loadWord(.init(childId: "kid-1"))
        await sut.recordTake(.init())
        await sut.recordTake(.init())
        sut.chooseTake(.init(takeNumber: 1))
        await sut.revealSecretTip(.init())
        XCTAssertEqual(spy.secretTips.count, 1)
        XCTAssertNotNil(spy.secretTips.last ?? nil)
    }

    func test_secretTip_withoutChosenTake_returnsNil() async {
        let spy = SpyPresenter()
        let sut = makeSUT(presenter: spy)
        await sut.loadWord(.init(childId: "kid-1"))
        // дублей нет → совет невозможен
        await sut.revealSecretTip(.init())
        XCTAssertEqual(spy.secretTips.last ?? nil, nil)
    }

    func test_secretTip_withoutScorer_returnsNil() async {
        let spy = SpyPresenter()
        let sut = makeSUT(presenter: spy, scorer: nil)
        await sut.loadWord(.init(childId: "kid-1"))
        await sut.recordTake(.init())
        await sut.recordTake(.init())
        sut.chooseTake(.init(takeNumber: 1))
        await sut.revealSecretTip(.init())
        XCTAssertEqual(spy.secretTips.last ?? nil, nil)
    }

    // MARK: - Reset (re-record)

    func test_resetTakes_clearsStateAndPresentsReset() async {
        let spy = SpyPresenter()
        let sut = makeSUT(presenter: spy)
        await sut.loadWord(.init(childId: "kid-1"))
        await sut.recordTake(.init())
        await sut.recordTake(.init())
        sut.chooseTake(.init(takeNumber: 1))
        await sut.judge(.init(judgement: .close))

        sut.resetTakes()
        XCTAssertTrue(sut.takes.isEmpty)
        XCTAssertNil(sut.chosenTakeNumber)
        XCTAssertNil(sut.judgement)
        XCTAssertEqual(sut.phase, .intro)
        XCTAssertEqual(spy.resetCount, 1)
    }

    // MARK: - Word provider

    func test_wordProvider_isDeterministicPerDay() {
        let cal = Calendar(identifier: .gregorian)
        let date = cal.date(from: DateComponents(year: 2026, month: 5, day: 30)) ?? Date()
        XCTAssertEqual(
            ListenYourselfWordProvider.wordForToday(now: date),
            ListenYourselfWordProvider.wordForToday(now: date)
        )
    }

    func test_wordProvider_cuesCountIsThree_forEachGroup() {
        for sound in ["С", "Ш", "Р", "К"] {
            XCTAssertEqual(ListenYourselfWordProvider.cues(forSound: sound).count, 3, "sound \(sound)")
        }
    }

    func test_selfJudgement_allCasesHaveEmojiAndTitle() {
        for j in ListenYourselfModels.SelfJudgement.allCases {
            XCTAssertFalse(j.emoji.isEmpty)
            XCTAssertFalse(j.title.isEmpty)
        }
    }
}
