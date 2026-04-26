@testable import HappySpeech
import XCTest

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

@MainActor
final class RhythmInteractorTests: XCTestCase {

    private func makeSUT(group: String = "sonants") -> (RhythmInteractor, SpyRhythmPresenter) {
        let sut = RhythmInteractor(soundGroup: group, totalPatternsPerSession: 3)
        let spy = SpyRhythmPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - 1. loadPattern загружает паттерн

    func test_loadPattern_sonants() async {
        let (sut, spy) = makeSUT(group: "sonants")
        await sut.loadPattern(.init(soundGroup: "sonants", index: 0))
        XCTAssertTrue(spy.loadPatternCalled)
        XCTAssertEqual(spy.lastLoadPattern?.pattern.soundGroup, "sonants")
    }

    // MARK: - 2. patternCatalog содержит все группы

    func test_patternCatalog_allGroups() {
        for group in ["whistling", "hissing", "sonants", "velar"] {
            let patterns = RhythmInteractor.patternCatalog[group]
            XCTAssertNotNil(patterns, "Группа \(group) должна быть в каталоге")
            XCTAssertGreaterThanOrEqual(patterns?.count ?? 0, 5, "Каждая группа должна иметь >= 5 паттернов")
        }
    }

    // MARK: - 3. soundGroup маппинг

    func test_soundGroupMapping() {
        XCTAssertEqual(RhythmInteractor.soundGroup(for: "С"), "whistling")
        XCTAssertEqual(RhythmInteractor.soundGroup(for: "Ш"), "hissing")
        XCTAssertEqual(RhythmInteractor.soundGroup(for: "Р"), "sonants")
        XCTAssertEqual(RhythmInteractor.soundGroup(for: "К"), "velar")
    }

    // MARK: - 4. evaluateRhythm: точное совпадение → score = 1.0

    func test_evaluate_perfectMatch_score1() async {
        let (sut, spy) = makeSUT()
        await sut.loadPattern(.init(soundGroup: "sonants", index: 0))
        let expected = spy.lastLoadPattern?.pattern.beats.count ?? 2
        sut._test_setCurrentPattern(RhythmInteractor.patternCatalog["sonants"]![0])
        await sut.evaluateRhythm(.init(detectedBeats: expected, expectedBeats: expected))
        XCTAssertTrue(spy.evalCalled)
        XCTAssertEqual(spy.lastEvaluate?.score, 1.0)
        XCTAssertEqual(spy.lastEvaluate?.correct, true)
    }

    // MARK: - 5. evaluateRhythm: разница 1 → score = 0.8

    func test_evaluate_diffOne_score08() async {
        let (sut, spy) = makeSUT()
        sut._test_setCurrentPattern(RhythmInteractor.patternCatalog["sonants"]![0])
        let expected = RhythmInteractor.patternCatalog["sonants"]![0].beats.count
        await sut.evaluateRhythm(.init(detectedBeats: expected - 1, expectedBeats: expected))
        XCTAssertEqual(spy.lastEvaluate?.score, 0.8)
    }

    // MARK: - 6. evaluateRhythm: diff >= 3 → score = 0.3

    func test_evaluate_diffThreeOrMore_score03() async {
        let (sut, spy) = makeSUT()
        let fourBeatPattern = RhythmInteractor.patternCatalog["velar"]!.first(where: { $0.beats.count == 4 })!
        sut._test_setCurrentPattern(fourBeatPattern)
        let expected = fourBeatPattern.beats.count
        await sut.evaluateRhythm(.init(detectedBeats: 0, expectedBeats: expected))
        XCTAssertEqual(spy.lastEvaluate?.score, 0.3)
    }

    // MARK: - 7. _test_pushRMS вызывает presentUpdateRMS

    func test_pushRMS_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut._test_pushRMS(0.5)
        XCTAssertTrue(spy.rmsUpdateCalled)
    }

    // MARK: - 8. complete без правильных паттернов → finalScore = 0

    func test_complete_noCorrect_scoreZero() async {
        let (sut, spy) = makeSUT(group: "sonants")
        await sut.complete(.init())
        XCTAssertTrue(spy.completeCalled)
        XCTAssertEqual(spy.lastComplete?.finalScore, 0.0)
    }
}
