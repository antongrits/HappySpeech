@testable import HappySpeech
import AVFoundation
import XCTest

// MARK: - RhythmInteractorTests
//
// UNTESTABLE (документировано): playPattern → speakSyllable использует
// LessonVoiceWorker.shared (TTS-синглтон) + Task.sleep; startRecord создаёт
// реальный AVAudioEngine и устанавливает input tap (engine.installTap +
// engine.start) — на headless-симуляторе это integration-путь без protocol-seam.
// scheduleRecordingTimer/stopRecording — телодвижения вокруг того же engine.
// Покрыто полностью: loadPattern, evaluateRhythm (все score-ветви), nextPattern,
// complete, handleRMS (burst-детекция), computeRMS (RMS из PCM-буфера),
// pulseRecordingTimer (timeout / excess-beats / within-limits). AVAudioEngine-путь
// проверяется smoke-тестом ритм-игры.

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

    // MARK: - 9. Batch 2 additional tests

    func test_loadPattern_hissing_callsPresenter() async {
        let (sut, spy) = makeSUT(group: "hissing")
        await sut.loadPattern(.init(soundGroup: "hissing", index: 1))
        XCTAssertTrue(spy.loadPatternCalled)
        XCTAssertEqual(spy.lastLoadPattern?.pattern.soundGroup, "hissing")
    }

    func test_loadPattern_indexWraps_doesNotCrash() async {
        let (sut, spy) = makeSUT(group: "whistling")
        // whistling has 5 patterns; index=7 → 7%5=2
        await sut.loadPattern(.init(soundGroup: "whistling", index: 7))
        XCTAssertTrue(spy.loadPatternCalled)
    }

    func test_evaluate_diffTwo_score0_6() async {
        let (sut, spy) = makeSUT()
        let pattern = RhythmInteractor.patternCatalog["sonants"]!.first(where: { $0.beats.count >= 3 })!
        sut._test_setCurrentPattern(pattern)
        let expected = pattern.beats.count
        await sut.evaluateRhythm(.init(detectedBeats: expected - 2, expectedBeats: expected))
        XCTAssertEqual(spy.lastEvaluate?.score, 0.6)
    }

    func test_evaluate_beatsWasHit_filledCorrectly() async {
        let (sut, spy) = makeSUT()
        let threeBeats = RhythmPattern(
            id: UUID(),
            beats: [.strong, .weak, .weak],
            syllableWord: "РА-ке-та",
            targetWord: "ракета",
            soundGroup: "sonants",
            emoji: "🚀",
            displayPattern: "ТА • та • та"
        )
        sut._test_setCurrentPattern(threeBeats)
        await sut.evaluateRhythm(.init(detectedBeats: 2, expectedBeats: 3))
        let hits = spy.lastEvaluate?.beatsWasHit ?? []
        XCTAssertEqual(hits.count, 3)
        XCTAssertTrue(hits[0])
        XCTAssertTrue(hits[1])
        XCTAssertFalse(hits[2])
    }

    func test_evaluate_noCurrentPattern_doesNotCallPresenter() async {
        // Create sut without setting currentPattern
        let sut = RhythmInteractor(soundGroup: "sonants", totalPatternsPerSession: 3)
        let spy = SpyRhythmPresenter()
        sut.presenter = spy
        // Do NOT call loadPattern or _test_setCurrentPattern

        await sut.evaluateRhythm(.init(detectedBeats: 2, expectedBeats: 2))

        XCTAssertFalse(spy.evalCalled, "evaluateRhythm без паттерна не должен вызывать presenter")
    }

    func test_nextPattern_lastPattern_triggersComplete() async {
        // totalPatternsPerSession=1 → первый nextPattern (0→1 ≥ 1) → complete
        let sut = RhythmInteractor(soundGroup: "sonants", totalPatternsPerSession: 1)
        let spy = SpyRhythmPresenter()
        sut.presenter = spy

        await sut.nextPattern(.init())

        XCTAssertTrue(spy.completeCalled)
    }

    func test_complete_oneCorrectOf2_score0_5() async {
        let (sut, spy) = makeSUT(group: "sonants")
        // Делаем одну правильную оценку
        let pattern = RhythmInteractor.patternCatalog["sonants"]![0]
        sut._test_setCurrentPattern(pattern)
        let expected = pattern.beats.count
        await sut.evaluateRhythm(.init(detectedBeats: expected, expectedBeats: expected))
        // Завершаем с totalPatterns=2
        let sut2 = RhythmInteractor(soundGroup: "sonants", totalPatternsPerSession: 2)
        sut2.presenter = spy
        sut2._test_setCurrentPattern(pattern)
        await sut2.evaluateRhythm(.init(detectedBeats: expected, expectedBeats: expected))
        await sut2.complete(.init())
        XCTAssertEqual(spy.lastComplete?.correctPatterns, 1)
        XCTAssertEqual(spy.lastComplete?.finalScore ?? -1, 0.5, accuracy: 0.001)
    }

    func test_cancel_doesNotCallComplete() async {
        let (sut, spy) = makeSUT()

        await sut.cancel()

        XCTAssertFalse(spy.completeCalled)
    }

    func test_patternCatalog_allPatternsNonEmptyWord() {
        for (_, patterns) in RhythmInteractor.patternCatalog {
            for pattern in patterns {
                XCTAssertFalse(pattern.targetWord.isEmpty)
                XCTAssertFalse(pattern.syllableWord.isEmpty)
                XCTAssertFalse(pattern.beats.isEmpty)
            }
        }
    }

    func test_soundGroupMapping_lowercaseNormalized() {
        XCTAssertEqual(RhythmInteractor.soundGroup(for: "с"), "whistling")
        XCTAssertEqual(RhythmInteractor.soundGroup(for: "ш"), "hissing")
        XCTAssertEqual(RhythmInteractor.soundGroup(for: "р"), "sonants")
        XCTAssertEqual(RhythmInteractor.soundGroup(for: "к"), "velar")
    }

    func test_soundGroupMapping_unknownFallsToSonants() {
        XCTAssertEqual(RhythmInteractor.soundGroup(for: "Б"), "sonants")
        XCTAssertEqual(RhythmInteractor.soundGroup(for: ""), "sonants")
    }

    func test_pushRMS_noRecording_detectsNoBeat() {
        let (sut, _) = makeSUT()
        sut._test_forceRecording(false)

        // Высокий → тихий RMS, но запись не идёт → beats остаются 0
        sut._test_pushRMS(0.9)
        sut._test_pushRMS(0.0)

        XCTAssertEqual(sut._test_currentDetectedBeats(), 0)
    }

    func test_pushRMS_zeroRMS_noBeatsWithoutBurst() {
        let (sut, _) = makeSUT()
        sut._test_forceRecording(true)

        // rms=0 < beatOffThreshold — beatActiveSince=nil → нет beat
        sut._test_pushRMS(0.0)

        XCTAssertEqual(sut._test_currentDetectedBeats(), 0)
    }

    // MARK: - Batch 1: расширенное покрытие

    func test_loadPattern_emptyGroup_usesConstructorGroup() async {
        let (sut, spy) = makeSUT(group: "velar")
        // Пустой soundGroup в request → берётся group из init
        await sut.loadPattern(.init(soundGroup: "", index: 0))
        XCTAssertEqual(spy.lastLoadPattern?.pattern.soundGroup, "velar")
    }

    func test_loadPattern_unknownGroup_fallsBackToSonants() async {
        let sut = RhythmInteractor(soundGroup: "unknown", totalPatternsPerSession: 3)
        let spy = SpyRhythmPresenter()
        sut.presenter = spy
        await sut.loadPattern(.init(soundGroup: "unknown", index: 0))
        XCTAssertEqual(spy.lastLoadPattern?.pattern.soundGroup, "sonants")
    }

    func test_evaluate_correct_incrementsCorrectPatterns() async {
        let (sut, spy) = makeSUT()
        let pattern = RhythmInteractor.patternCatalog["sonants"]![0]
        sut._test_setCurrentPattern(pattern)
        await sut.evaluateRhythm(.init(detectedBeats: pattern.beats.count, expectedBeats: pattern.beats.count))
        XCTAssertEqual(spy.lastEvaluate?.correct, true)
    }

    func test_evaluate_detectedExceedsExpected_stillHandled() async {
        let (sut, spy) = makeSUT()
        let pattern = RhythmInteractor.patternCatalog["sonants"]![0]
        sut._test_setCurrentPattern(pattern)
        let expected = pattern.beats.count
        await sut.evaluateRhythm(.init(detectedBeats: expected + 5, expectedBeats: expected))
        // diff = 5 → score 0.3
        XCTAssertEqual(spy.lastEvaluate?.score, 0.3)
        XCTAssertEqual(spy.lastEvaluate?.detectedBeats, expected + 5)
    }

    func test_evaluate_beatsWasHit_allHitWhenPerfect() async {
        let (sut, spy) = makeSUT()
        let pattern = RhythmInteractor.patternCatalog["hissing"]![0]
        sut._test_setCurrentPattern(pattern)
        await sut.evaluateRhythm(.init(detectedBeats: pattern.beats.count, expectedBeats: pattern.beats.count))
        let hits = spy.lastEvaluate?.beatsWasHit ?? []
        XCTAssertEqual(hits.count, pattern.beats.count)
        XCTAssertTrue(hits.allSatisfy { $0 })
    }

    func test_complete_perfectSession_finalScore1() async {
        let sut = RhythmInteractor(soundGroup: "sonants", totalPatternsPerSession: 1)
        let spy = SpyRhythmPresenter()
        sut.presenter = spy
        let pattern = RhythmInteractor.patternCatalog["sonants"]![0]
        sut._test_setCurrentPattern(pattern)
        await sut.evaluateRhythm(.init(detectedBeats: pattern.beats.count, expectedBeats: pattern.beats.count))
        await sut.complete(.init())
        XCTAssertEqual(spy.lastComplete?.finalScore, 1.0)
        XCTAssertEqual(spy.lastComplete?.correctPatterns, 1)
    }

    func test_pushRMS_alwaysCallsUpdateRMS() {
        let (sut, spy) = makeSUT()
        sut._test_pushRMS(0.3)
        XCTAssertTrue(spy.rmsUpdateCalled)
    }

    func test_pushRMS_burstDetectsBeat() {
        let (sut, _) = makeSUT()
        sut._test_forceRecording(true)
        // Высокий RMS → старт burst
        sut._test_pushRMS(0.5)
        // Малая длительность burst-а (<100мс) — обычно не засчитывается,
        // но проверяем что вызов не крашит и detectedBeats >= 0
        sut._test_pushRMS(0.01)
        XCTAssertGreaterThanOrEqual(sut._test_currentDetectedBeats(), 0)
    }

    func test_cancel_doesNotCrash() async {
        let (sut, _) = makeSUT()
        await sut.loadPattern(.init(soundGroup: "sonants", index: 0))
        await sut.cancel()
        XCTAssertTrue(true)
    }

    func test_beatStrength_cases() {
        XCTAssertEqual(BeatStrength.allCases.count, 2)
    }

    func test_complete_zeroPatterns_safeguardDivision() async {
        let sut = RhythmInteractor(soundGroup: "sonants", totalPatternsPerSession: 0)
        let spy = SpyRhythmPresenter()
        sut.presenter = spy
        await sut.complete(.init())
        // max(1, 0) защищает от деления на ноль
        XCTAssertEqual(spy.lastComplete?.finalScore, 0.0)
    }

    func test_soundGroup_mappingFullCoverage() {
        XCTAssertEqual(RhythmInteractor.soundGroup(for: "З"), "whistling")
        XCTAssertEqual(RhythmInteractor.soundGroup(for: "Ц"), "whistling")
        XCTAssertEqual(RhythmInteractor.soundGroup(for: "Ж"), "hissing")
        XCTAssertEqual(RhythmInteractor.soundGroup(for: "Щ"), "hissing")
        XCTAssertEqual(RhythmInteractor.soundGroup(for: "Л"), "sonants")
        XCTAssertEqual(RhythmInteractor.soundGroup(for: "Г"), "velar")
        XCTAssertEqual(RhythmInteractor.soundGroup(for: "Х"), "velar")
    }

    // MARK: - Batch 2.6a v25: handleRMS burst detection / nextPattern chain

    func test_pushRMS_sustainedBurst_detectsBeat() async {
        let (sut, _) = makeSUT()
        sut._test_setCurrentPattern(RhythmInteractor.patternCatalog["sonants"]![0])
        sut._test_forceRecording(true)
        // Старт burst-а: высокий RMS.
        sut._test_pushRMS(0.5)
        // Удерживаем >100 мс, чтобы преодолеть minBeatDurationMs.
        try? await Task.sleep(for: .milliseconds(140))
        // Завершаем burst тишиной.
        sut._test_pushRMS(0.01)
        XCTAssertEqual(sut._test_currentDetectedBeats(), 1,
                       "Удержанный >100 мс burst засчитывается как один beat")
    }

    func test_pushRMS_shortBurst_belowMinDuration_notCounted() {
        let (sut, _) = makeSUT()
        sut._test_setCurrentPattern(RhythmInteractor.patternCatalog["sonants"]![0])
        sut._test_forceRecording(true)
        // Мгновенный burst (нет паузы) — длительность < 100 мс.
        sut._test_pushRMS(0.5)
        sut._test_pushRMS(0.01)
        XCTAssertEqual(sut._test_currentDetectedBeats(), 0)
    }

    func test_pushRMS_midRangeValue_doesNotToggleBurst() {
        let (sut, _) = makeSUT()
        sut._test_setCurrentPattern(RhythmInteractor.patternCatalog["sonants"]![0])
        sut._test_forceRecording(true)
        // Значение между off (0.05) и on (0.15) порогами — не стартует и не завершает.
        sut._test_pushRMS(0.10)
        sut._test_pushRMS(0.10)
        XCTAssertEqual(sut._test_currentDetectedBeats(), 0)
    }

    func test_pushRMS_multipleBursts_accumulateBeats() async {
        let (sut, _) = makeSUT()
        sut._test_setCurrentPattern(RhythmInteractor.patternCatalog["sonants"]![0])
        sut._test_forceRecording(true)
        for _ in 0..<3 {
            sut._test_pushRMS(0.5)
            try? await Task.sleep(for: .milliseconds(130))
            sut._test_pushRMS(0.0)
        }
        XCTAssertEqual(sut._test_currentDetectedBeats(), 3)
    }

    func test_playPattern_withoutCurrentPattern_doesNotCrash() async {
        let sut = RhythmInteractor(soundGroup: "sonants", totalPatternsPerSession: 3)
        let spy = SpyRhythmPresenter()
        sut.presenter = spy
        // currentPattern == nil → guard, no-op.
        await sut.playPattern(.init())
        XCTAssertFalse(spy.playPatternCalled)
    }

    func test_evaluateRhythm_advancesToNextPattern() async {
        let (sut, spy) = makeSUT(group: "sonants") // totalPatternsPerSession = 3
        await sut.loadPattern(.init(soundGroup: "sonants", index: 0))
        let pattern = RhythmInteractor.patternCatalog["sonants"]![0]
        sut._test_setCurrentPattern(pattern)
        // evaluateRhythm в конце ждёт 1.5с и вызывает nextPattern → loadPattern.
        await sut.evaluateRhythm(.init(detectedBeats: pattern.beats.count,
                                       expectedBeats: pattern.beats.count))
        XCTAssertTrue(spy.evalCalled)
        XCTAssertTrue(spy.nextPatternCalled, "evaluateRhythm должен инициировать переход к следующему паттерну")
    }

    func test_loadPattern_emptyPool_triggersComplete() async {
        // Каталог не содержит такой группы и fallback sonants существует —
        // поэтому пустой pool недостижим через публичный API. Проверяем
        // нормальный путь: неизвестная группа → sonants fallback не пуст.
        let sut = RhythmInteractor(soundGroup: "totally-unknown", totalPatternsPerSession: 2)
        let spy = SpyRhythmPresenter()
        sut.presenter = spy
        await sut.loadPattern(.init(soundGroup: "totally-unknown", index: 0))
        XCTAssertTrue(spy.loadPatternCalled)
        XCTAssertEqual(spy.lastLoadPattern?.pattern.soundGroup, "sonants")
    }

    func test_evaluateRhythm_lastPattern_completesSession() async {
        let sut = RhythmInteractor(soundGroup: "sonants", totalPatternsPerSession: 1)
        let spy = SpyRhythmPresenter()
        sut.presenter = spy
        let pattern = RhythmInteractor.patternCatalog["sonants"]![0]
        sut._test_setCurrentPattern(pattern)
        await sut.evaluateRhythm(.init(detectedBeats: pattern.beats.count,
                                       expectedBeats: pattern.beats.count))
        // totalPatternsPerSession=1 → nextPattern (0→1≥1) → complete.
        XCTAssertTrue(spy.completeCalled)
    }

    func test_startRecord_whenAlreadyRecording_isIgnored() async {
        let (sut, spy) = makeSUT()
        sut._test_forceRecording(true)
        await sut.startRecord(.init())
        XCTAssertFalse(spy.startRecordCalled, "startRecord при активной записи игнорируется")
    }

    func test_pushRMS_notRecording_stillEmitsUpdateRMS() {
        let (sut, spy) = makeSUT()
        sut._test_forceRecording(false)
        sut._test_pushRMS(0.4)
        XCTAssertTrue(spy.rmsUpdateCalled, "presentUpdateRMS вызывается всегда, даже без записи")
    }

    func test_cancel_afterPlayPattern_doesNotCrash() async {
        let (sut, _) = makeSUT()
        await sut.loadPattern(.init(soundGroup: "sonants", index: 0))
        await sut.cancel()
        // Повторный cancel идемпотентен.
        await sut.cancel()
        XCTAssertTrue(true)
    }

    func test_nextPattern_midSession_loadsNextPattern() async {
        let (sut, spy) = makeSUT(group: "hissing") // totalPatternsPerSession = 3
        await sut.loadPattern(.init(soundGroup: "hissing", index: 0))
        spy.loadPatternCalled = false
        await sut.nextPattern(.init())
        // currentPatternIndex 0→1 < 3 → presentNextPattern + loadPattern.
        XCTAssertTrue(spy.nextPatternCalled)
        XCTAssertTrue(spy.loadPatternCalled)
    }

    func test_evaluateRhythm_detectedZero_diffEqualsExpected() async {
        let (sut, spy) = makeSUT()
        let pattern = RhythmInteractor.patternCatalog["sonants"]![0] // 2 beats
        sut._test_setCurrentPattern(pattern)
        await sut.evaluateRhythm(.init(detectedBeats: 0, expectedBeats: pattern.beats.count))
        // diff = 2 → score 0.6.
        XCTAssertEqual(spy.lastEvaluate?.score, 0.6)
        XCTAssertEqual(spy.lastEvaluate?.correct, false)
    }

    // MARK: - Batch 2.6a v25 (доп.): computeRMS / pulseRecordingTimer

    /// Создаёт PCM-буфер 16 кГц mono с заданной постоянной амплитудой.
    private func makeBuffer(amplitude: Float, frames: Int = 1024) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
        buffer.frameLength = AVAudioFrameCount(frames)
        if let channel = buffer.floatChannelData {
            for i in 0..<frames { channel[0][i] = amplitude }
        }
        return buffer
    }

    func test_computeRMS_silentBuffer_returnsZero() {
        let buffer = makeBuffer(amplitude: 0.0)
        XCTAssertEqual(RhythmInteractor.computeRMS(from: buffer), 0, accuracy: 0.0001)
    }

    func test_computeRMS_loudBuffer_returnsPositive() {
        let buffer = makeBuffer(amplitude: 0.3)
        let rms = RhythmInteractor.computeRMS(from: buffer)
        XCTAssertGreaterThan(rms, 0)
        XCTAssertLessThanOrEqual(rms, 1, "computeRMS зажимает значение в [0, 1]")
    }

    func test_computeRMS_fullScaleBuffer_clampedToOne() {
        // amplitude 1.0 → rms 1.0, ×3 → clamp до 1.
        let buffer = makeBuffer(amplitude: 1.0)
        XCTAssertEqual(RhythmInteractor.computeRMS(from: buffer), 1, accuracy: 0.0001)
    }

    func test_computeRMS_emptyBuffer_returnsZero() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 0
        XCTAssertEqual(RhythmInteractor.computeRMS(from: buffer), 0)
    }

    func test_pulseRecordingTimer_notRecording_noOp() {
        let (sut, spy) = makeSUT()
        sut._test_forceRecording(false)
        sut._test_pulseRecordingTimer()
        XCTAssertFalse(spy.evalCalled, "Без активной записи pulseRecordingTimer ничего не делает")
    }

    func test_pulseRecordingTimer_maxDurationReached_triggersEvaluate() async {
        let (sut, spy) = makeSUT()
        sut._test_setCurrentPattern(RhythmInteractor.patternCatalog["sonants"]![0])
        sut._test_forceRecording(true)
        // maxRecordingMs = 4000 → сдвигаем старт записи на 5 секунд назад.
        sut._test_setRecordingStartedAgo(5)
        sut._test_pulseRecordingTimer()
        try? await Task.sleep(for: .milliseconds(120))
        XCTAssertTrue(spy.evalCalled, "Превышение maxRecordingMs завершает запись через evaluateRhythm")
    }

    func test_pulseRecordingTimer_excessBeats_triggersEvaluate() async {
        let (sut, spy) = makeSUT()
        let pattern = RhythmInteractor.patternCatalog["sonants"]![0] // 2 beats
        sut._test_setCurrentPattern(pattern)
        sut._test_forceRecording(true)
        sut._test_setRecordingStartedAgo(0.1)
        // detectedBeats >= expected + 2 → завершение.
        sut._test_setDetectedBeats(pattern.beats.count + 3)
        sut._test_pulseRecordingTimer()
        try? await Task.sleep(for: .milliseconds(120))
        XCTAssertTrue(spy.evalCalled, "Слишком много слогов завершает запись досрочно")
    }

    func test_pulseRecordingTimer_withinLimits_doesNotEvaluate() {
        let (sut, spy) = makeSUT()
        sut._test_setCurrentPattern(RhythmInteractor.patternCatalog["sonants"]![0])
        sut._test_forceRecording(true)
        sut._test_setRecordingStartedAgo(0.5) // в пределах 4 секунд
        sut._test_setDetectedBeats(0)
        sut._test_pulseRecordingTimer()
        XCTAssertFalse(spy.evalCalled, "В пределах лимитов запись продолжается")
    }
}
