@testable import HappySpeech
import XCTest

// MARK: - MockFluencyAnalyzerWorker

private final class MockFluencyAnalyzerWorker: FluencyAnalyzerWorkerProtocol, @unchecked Sendable {
    var stubbedClassification: OnsetClassification = .soft
    var stubbedAttackMs: Float = 120.0
    var classifyCallCount: Int = 0

    func classifyOnset(
        rmsBuffer: [Float],
        threshold: Float,
        difficulty: StutteringDifficulty
    ) -> (classification: OnsetClassification, attackTimeMs: Float) {
        classifyCallCount += 1
        return (stubbedClassification, stubbedAttackMs)
    }

    func analyzeDysfluency(transcript: String) -> (repetitions: Int, totalTokens: Int) {
        return (0, 0)
    }

    func estimateSyllableCount(in text: String) -> Int { return 0 }
    func dysfluencyRate(count: Int, syllables: Int) -> Float { return 0 }
}

private final class MockSoftOnsetHapticService: HapticService, @unchecked Sendable {
    var playedPatterns: [HapticPattern] = []
    var isAvailable: Bool { true }

    func play(pattern: HapticPattern) async { playedPatterns.append(pattern) }
    func setIntensityScale(_ scale: Float) {}
    func stop() async {}
    func selection() {}
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {}
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {}
}

// MARK: - SoftOnsetInteractorTests

@MainActor
final class SoftOnsetInteractorTests: XCTestCase {

    private func makeSUT(
        classification: OnsetClassification = .soft,
        attackMs: Float = 120.0
    ) -> (SoftOnsetInteractor, MockFluencyAnalyzerWorker, MockSoftOnsetHapticService) {
        let analyzer = MockFluencyAnalyzerWorker()
        analyzer.stubbedClassification = classification
        analyzer.stubbedAttackMs = attackMs
        let haptic = MockSoftOnsetHapticService()
        let sut = SoftOnsetInteractor(
            analyzerWorker: analyzer,
            hapticService: haptic
        )
        return (sut, analyzer, haptic)
    }

    // MARK: - 1. startSession инициализирует display

    func test_startSession_easy_resetsDisplay() async {
        let (sut, _, _) = makeSUT()
        await sut.startSession(difficulty: .easy)

        XCTAssertEqual(sut.display.totalWords, 5)
        XCTAssertEqual(sut.display.wordsSucceeded, 0)
        XCTAssertFalse(sut.display.sessionComplete)
        XCTAssertEqual(sut.display.sessionScore, 0)
        XCTAssertFalse(sut.display.showDifficultyUpgrade)
    }

    func test_startSession_medium_setsCorrectDifficultyLabel() async {
        let (sut, _, _) = makeSUT()
        await sut.startSession(difficulty: .medium)

        XCTAssertFalse(sut.display.difficultyLabel.isEmpty)
    }

    func test_startSession_hard_setsCorrectDifficultyLabel() async {
        let (sut, _, _) = makeSUT()
        await sut.startSession(difficulty: .hard)

        XCTAssertFalse(sut.display.difficultyLabel.isEmpty)
    }

    func test_startSession_loadsCurrentWord() async {
        let (sut, _, _) = makeSUT()
        await sut.startSession(difficulty: .easy)

        XCTAssertFalse(sut.display.currentWord.isEmpty,
                       "Первое слово должно быть загружено после startSession")
    }

    func test_startSession_maxAttempts_isSetTo5() async {
        let (sut, _, _) = makeSUT()
        await sut.startSession(difficulty: .easy)

        XCTAssertEqual(sut.display.maxAttempts, 5)
    }

    // MARK: - 2. stopListening триггерит classifyOnset

    func test_stopListening_callsClassifyOnset() async {
        let (sut, analyzer, _) = makeSUT(classification: .soft)
        await sut.startSession(difficulty: .easy)
        sut.stopListening()

        XCTAssertEqual(analyzer.classifyCallCount, 1)
    }

    // MARK: - 3. Soft onset → lantern bright, wordsSucceeded растёт

    func test_stopListening_softClassification_lanternBright() async {
        let (sut, _, _) = makeSUT(classification: .soft)
        await sut.startSession(difficulty: .easy)
        sut.stopListening()

        XCTAssertEqual(sut.display.lanternState, .bright)
        XCTAssertEqual(sut.display.waveformColorMode, .soft)
        XCTAssertEqual(sut.display.feedbackStyle, .success)
    }

    func test_stopListening_softClassification_incrementsWordsSucceeded() async {
        let (sut, _, _) = makeSUT(classification: .soft)
        await sut.startSession(difficulty: .easy)
        sut.stopListening()

        XCTAssertEqual(sut.display.wordsSucceeded, 1)
    }

    func test_stopListening_softClassification_hapticPerfectRoundFired() async throws {
        let (sut, _, haptic) = makeSUT(classification: .soft)
        await sut.startSession(difficulty: .easy)
        sut.stopListening()
        // Sleep to let the unstructured Task { await hapticService.play(...) } complete
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertTrue(haptic.playedPatterns.contains(.perfectRound))
    }

    // MARK: - 4. Borderline onset

    func test_stopListening_borderlineClassification_lanternFlicker() async {
        let (sut, _, _) = makeSUT(classification: .borderline)
        await sut.startSession(difficulty: .easy)
        sut.stopListening()

        XCTAssertEqual(sut.display.lanternState, .flicker)
        XCTAssertEqual(sut.display.waveformColorMode, .borderline)
        XCTAssertEqual(sut.display.feedbackStyle, .warning)
    }

    func test_stopListening_borderlineClassification_doesNotIncrementWordsSucceeded() async {
        let (sut, _, _) = makeSUT(classification: .borderline)
        await sut.startSession(difficulty: .easy)
        sut.stopListening()

        XCTAssertEqual(sut.display.wordsSucceeded, 0)
    }

    // MARK: - 5. Hard onset

    func test_stopListening_hardClassification_feedbackStyleError() async {
        let (sut, _, _) = makeSUT(classification: .hard)
        await sut.startSession(difficulty: .easy)
        sut.stopListening()

        XCTAssertEqual(sut.display.feedbackStyle, .error)
        XCTAssertEqual(sut.display.waveformColorMode, .hard)
    }

    func test_stopListening_hardClassification_hapticErrorBuzzFired() async throws {
        let (sut, _, haptic) = makeSUT(classification: .hard)
        await sut.startSession(difficulty: .easy)
        sut.stopListening()
        // Sleep to let the unstructured Task { await hapticService.play(...) } complete
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertTrue(haptic.playedPatterns.contains(.errorBuzz))
    }

    // MARK: - 6. attackTimeMs записывается в display

    func test_stopListening_storesAttackTimeMs() async {
        let (sut, _, _) = makeSUT(classification: .soft, attackMs: 150.0)
        await sut.startSession(difficulty: .easy)
        sut.stopListening()

        XCTAssertEqual(sut.display.attackTimeMs, 150.0, accuracy: 0.001)
    }

    // MARK: - 7. attemptNumber растёт при ошибке

    func test_stopListening_wrongAttempt_incrementsAttemptNumber() async {
        let (sut, _, _) = makeSUT(classification: .hard)
        await sut.startSession(difficulty: .easy)
        let before = sut.display.attemptNumber
        sut.stopListening()

        XCTAssertGreaterThan(sut.display.attemptNumber, before)
    }

    // MARK: - 8. SoftOnsetSessionStats.resultLevel

    func test_sessionStats_excellent_above85() {
        let stats = SoftOnsetSessionStats(
            totalWords: 5,
            wordsSucceeded: 5,
            successRate: 1.0,
            averageAttackTimeMs: 110,
            difficulty: .easy,
            sessionScore: 100
        )
        XCTAssertEqual(stats.resultLevel, .excellent)
    }

    func test_sessionStats_good_60to84() {
        let stats = SoftOnsetSessionStats(
            totalWords: 5,
            wordsSucceeded: 4,
            successRate: 0.8,
            averageAttackTimeMs: 80,
            difficulty: .medium,
            sessionScore: 70
        )
        XCTAssertEqual(stats.resultLevel, .good)
    }

    func test_sessionStats_fair_40to59() {
        let stats = SoftOnsetSessionStats(
            totalWords: 5,
            wordsSucceeded: 2,
            successRate: 0.4,
            averageAttackTimeMs: 60,
            difficulty: .medium,
            sessionScore: 50
        )
        XCTAssertEqual(stats.resultLevel, .fair)
    }

    func test_sessionStats_needsWork_below40() {
        let stats = SoftOnsetSessionStats(
            totalWords: 5,
            wordsSucceeded: 1,
            successRate: 0.2,
            averageAttackTimeMs: 30,
            difficulty: .hard,
            sessionScore: 20
        )
        XCTAssertEqual(stats.resultLevel, .needsWork)
    }

    // MARK: - 9. feedbackText не пустой при каждой классификации

    func test_stopListening_soft_feedbackTextNonEmpty() async {
        let (sut, _, _) = makeSUT(classification: .soft)
        await sut.startSession(difficulty: .easy)
        sut.stopListening()

        XCTAssertNotNil(sut.display.feedbackText)
        XCTAssertFalse(sut.display.feedbackText?.isEmpty ?? true)
    }

    func test_stopListening_borderline_feedbackTextNonEmpty() async {
        let (sut, _, _) = makeSUT(classification: .borderline)
        await sut.startSession(difficulty: .easy)
        sut.stopListening()

        XCTAssertNotNil(sut.display.feedbackText)
        XCTAssertFalse(sut.display.feedbackText?.isEmpty ?? true)
    }

    func test_stopListening_hard_feedbackTextNonEmpty() async {
        let (sut, _, _) = makeSUT(classification: .hard)
        await sut.startSession(difficulty: .easy)
        sut.stopListening()

        XCTAssertNotNil(sut.display.feedbackText)
        XCTAssertFalse(sut.display.feedbackText?.isEmpty ?? true)
    }

    // MARK: - 10. difficulty upgrade: проверяется только при сложности не hard

    func test_difficultyUpgrade_notShown_whenAlreadyHard() async {
        let (sut, _, _) = makeSUT(classification: .soft)
        await sut.startSession(difficulty: .hard)

        // Имитируем несколько успешных сессий — startSession сбрасывает wordsSucceeded
        // и мы проверяем что showDifficultyUpgrade не появится для уровня hard
        for _ in 0..<5 { sut.stopListening() }

        XCTAssertFalse(sut.display.showDifficultyUpgrade,
                       "На сложности hard апгрейд невозможен")
    }

    // MARK: - 11. isRecording сбрасывается после stopListening

    func test_stopListening_resetsIsRecording() async {
        let (sut, _, _) = makeSUT(classification: .soft)
        await sut.startSession(difficulty: .easy)
        sut.stopListening()

        XCTAssertFalse(sut.display.isRecording)
    }

    // MARK: - 12. Multiple stopListening без startSession не краш

    func test_stopListening_withoutStartSession_doesNotCrash() {
        let (sut, _, _) = makeSUT()
        sut.stopListening()
        XCTAssertFalse(sut.display.isRecording)
    }
}
