import Testing
@testable import HappySpeech

// MARK: - Spy

@MainActor
private final class SpyRhythmPresenter: RhythmPresentationLogic {
    var loadPatternCalled = false
    var playPatternCalled = false
    var startRecordCalled = false
    var evalCalled = false
    var nextPatternCalled = false
    var completeCalled = false
    var rmsUpdateCalled = false

    var lastLoadPattern: RhythmModels.LoadPattern.Response?
    var lastEvaluate: RhythmModels.EvaluateRhythm.Response?
    var lastComplete: RhythmModels.Complete.Response?

    func presentLoadPattern(_ response: RhythmModels.LoadPattern.Response) {
        loadPatternCalled = true
        lastLoadPattern = response
    }
    func presentPlayPattern(_ response: RhythmModels.PlayPattern.Response) {
        playPatternCalled = true
    }
    func presentStartRecord(_ response: RhythmModels.StartRecord.Response) {
        startRecordCalled = true
    }
    func presentEvaluateRhythm(_ response: RhythmModels.EvaluateRhythm.Response) {
        evalCalled = true
        lastEvaluate = response
    }
    func presentNextPattern(_ response: RhythmModels.NextPattern.Response) {
        nextPatternCalled = true
    }
    func presentComplete(_ response: RhythmModels.Complete.Response) {
        completeCalled = true
        lastComplete = response
    }
    func presentUpdateRMS(_ response: RhythmModels.UpdateRMS.Response) {
        rmsUpdateCalled = true
    }
}

// MARK: - Tests

@Suite("RhythmInteractor")
@MainActor
struct RhythmInteractorTests {

    private func makeSUT(group: String = "sonants") -> (RhythmInteractor, SpyRhythmPresenter) {
        let sut = RhythmInteractor(soundGroup: group, totalPatternsPerSession: 3)
        let spy = SpyRhythmPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - 1. loadPattern загружает паттерн

    @Test("loadPattern загружает паттерн для группы sonants")
    func loadPatternSonants() async {
        let (sut, spy) = makeSUT(group: "sonants")
        await sut.loadPattern(.init(soundGroup: "sonants", index: 0))
        #expect(spy.loadPatternCalled)
        #expect(spy.lastLoadPattern?.pattern.soundGroup == "sonants")
    }

    // MARK: - 2. patternCatalog содержит все группы

    @Test("patternCatalog содержит записи для всех 4 групп")
    func patternCatalogAllGroups() {
        for group in ["whistling", "hissing", "sonants", "velar"] {
            let patterns = RhythmInteractor.patternCatalog[group]
            #expect(patterns != nil, "Группа \(group) должна быть в каталоге")
            #expect((patterns?.count ?? 0) >= 5, "Каждая группа должна иметь >= 5 паттернов")
        }
    }

    // MARK: - 3. soundGroup маппинг

    @Test("soundGroup(for:) корректно маппит звуки")
    func soundGroupMapping() {
        #expect(RhythmInteractor.soundGroup(for: "С") == "whistling")
        #expect(RhythmInteractor.soundGroup(for: "Ш") == "hissing")
        #expect(RhythmInteractor.soundGroup(for: "Р") == "sonants")
        #expect(RhythmInteractor.soundGroup(for: "К") == "velar")
    }

    // MARK: - 4. evaluateRhythm: точное совпадение → score = 1.0

    @Test("evaluateRhythm с detectedBeats == expectedBeats → score = 1.0")
    func evaluatePerfectMatch() async {
        let (sut, spy) = makeSUT()
        await sut.loadPattern(.init(soundGroup: "sonants", index: 0))
        let expected = spy.lastLoadPattern?.pattern.beats.count ?? 2
        // Не запускаем реальный движок — вызываем evaluateRhythm напрямую через тест-хук
        sut._test_setCurrentPattern(RhythmInteractor.patternCatalog["sonants"]![0])
        await sut.evaluateRhythm(.init(detectedBeats: expected, expectedBeats: expected))
        #expect(spy.evalCalled)
        #expect(spy.lastEvaluate?.score == 1.0)
        #expect(spy.lastEvaluate?.correct == true)
    }

    // MARK: - 5. evaluateRhythm: разница 1 → score = 0.8

    @Test("evaluateRhythm с diff=1 → score = 0.8")
    func evaluateDiffOne() async {
        let (sut, spy) = makeSUT()
        sut._test_setCurrentPattern(RhythmInteractor.patternCatalog["sonants"]![0])
        let expected = RhythmInteractor.patternCatalog["sonants"]![0].beats.count
        await sut.evaluateRhythm(.init(detectedBeats: expected - 1, expectedBeats: expected))
        #expect(spy.lastEvaluate?.score == 0.8)
    }

    // MARK: - 6. evaluateRhythm: diff >= 3 → score = 0.3

    @Test("evaluateRhythm с diff >= 3 → score = 0.3")
    func evaluateDiffThreeOrMore() async {
        let (sut, spy) = makeSUT()
        // Выбираем паттерн с 4 битами (velar: "ка-РА-мель-ка")
        let fourBeatPattern = RhythmInteractor.patternCatalog["velar"]!.first(where: { $0.beats.count == 4 })!
        sut._test_setCurrentPattern(fourBeatPattern)
        let expected = fourBeatPattern.beats.count
        // detectedBeats = 0, diff = 4 → score = 0.3
        await sut.evaluateRhythm(.init(detectedBeats: 0, expectedBeats: expected))
        #expect(spy.lastEvaluate?.score == 0.3)
    }

    // MARK: - 7. _test_pushRMS обновляет presenter через RMS

    @Test("_test_pushRMS вызывает presentUpdateRMS")
    func pushRMSCallsPresenter() {
        let (sut, spy) = makeSUT()
        sut._test_pushRMS(0.5)
        #expect(spy.rmsUpdateCalled)
    }

    // MARK: - 8. complete без записи даёт finalScore = 0

    @Test("complete без правильных паттернов даёт finalScore = 0")
    func completeNoCorrect() async {
        let (sut, spy) = makeSUT(group: "sonants")
        await sut.complete(.init())
        #expect(spy.completeCalled)
        #expect(spy.lastComplete?.finalScore == 0.0)
    }
}
