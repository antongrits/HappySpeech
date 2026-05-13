@testable import HappySpeech
import XCTest

// MARK: - MLIntegrationTests
//
// Plan v22 Block 4.3 — 15 ML integration tests.
//
// Стратегия: тестируем ML-слой через mock-реализации и domain-типы без
// зависимости от реальных Core ML моделей (которые недоступны в тест-таргете).
//
// Покрываемые компоненты:
//   - PronunciationResult (domain invariants via direct init — избегаем AVAudioPCMBuffer)
//   - MockMLExecutor (inference baseline)
//   - VADResult / VADSession (domain logic)
//   - PronunciationPhonemeGroup (enum coverage)

// MARK: - PronunciationResult Direct Tests (без AVAudioPCMBuffer)

/// Тесты domain logic PronunciationResult — без зависимости от AVAudioPCMBuffer.
/// MockPronunciationScorer тестируется через PronunciationResult напрямую.
final class MockScorerBaselineTests: XCTestCase {

    // MARK: - 1. correctProbability=0.85 → isCorrect=true

    func test_pronunciationResult_highProbability_isCorrect() {
        let result = PronunciationResult(
            correctProbability: 0.85,
            incorrectProbability: 0.15,
            predictedLabel: "correct",
            phonemeGroup: .whistling
        )
        XCTAssertEqual(result.correctProbability, 0.85, accuracy: 0.001)
        XCTAssertTrue(result.isCorrect, "0.85 >= 0.6 → isCorrect должен быть true")
    }

    // MARK: - 2. correctProbability=0.15 → isCorrect=false

    func test_pronunciationResult_lowProbability_isIncorrect() {
        let result = PronunciationResult(
            correctProbability: 0.15,
            incorrectProbability: 0.85,
            predictedLabel: "incorrect",
            phonemeGroup: .sonants
        )
        XCTAssertFalse(result.isCorrect,
                       "0.15 < 0.6 → isCorrect должен быть false")
        XCTAssertEqual(result.incorrectProbability, 0.85, accuracy: 0.001)
    }

    // MARK: - 3. displayScore range 0–100

    func test_pronunciationResult_displayScore_inRange() {
        let result = PronunciationResult(
            correctProbability: 0.72,
            incorrectProbability: 0.28,
            predictedLabel: "correct",
            phonemeGroup: .hissing
        )
        XCTAssertGreaterThanOrEqual(result.displayScore, 0)
        XCTAssertLessThanOrEqual(result.displayScore, 100,
                                 "displayScore должен быть в диапазоне 0–100")
        XCTAssertEqual(result.displayScore, 72)
    }

    // MARK: - 4. phonemeGroup сохраняется в результате

    func test_pronunciationResult_phonemeGroup_preservedForAllCases() {
        for group in PronunciationPhonemeGroup.allCases {
            let result = PronunciationResult(
                correctProbability: 0.75,
                incorrectProbability: 0.25,
                predictedLabel: "correct",
                phonemeGroup: group
            )
            XCTAssertEqual(result.phonemeGroup, group,
                           "phonemeGroup должен сохраняться для \(group.rawValue)")
        }
    }

    // MARK: - 5. PronunciationPhonemeGroup — 4 кейса

    func test_phonemeGroup_allCases_countIs4() {
        XCTAssertEqual(PronunciationPhonemeGroup.allCases.count, 4,
                       "Должно быть 4 группы фонем: whistling, hissing, sonants, velar")
    }
}

// MARK: - MockMLExecutor Tests

/// Тесты MockMLExecutor — детерминированная ML inference baseline.
final class MockMLExecutorTests: XCTestCase {

    // MARK: - 6. classify возвращает 49 вероятностей

    func test_mockExecutor_classify_returns49Values() async {
        let executor = MockMLExecutor()
        let result = await executor.classify(audio: Data())
        XCTAssertEqual(result.count, 49,
                       "RussianPhonemeClassifier output: 49 вероятностей (все фонемы)")
    }

    // MARK: - 7. Uniform distribution — сумма ≈ 1.0

    func test_mockExecutor_classify_uniformDistribution() async {
        let executor = MockMLExecutor()
        let result = await executor.classify(audio: Data())
        let sum = result.reduce(0.0, +)
        XCTAssertEqual(Double(sum), 1.0, accuracy: 0.001,
                       "Uniform distribution: сумма вероятностей должна быть ≈ 1.0")
    }

    // MARK: - 8. callCount инкрементируется

    func test_mockExecutor_callCount_increments() async {
        let executor = MockMLExecutor()
        let countBefore = await executor.classifyCallCount
        XCTAssertEqual(countBefore, 0)

        _ = await executor.classify(audio: Data())
        _ = await executor.classify(audio: Data())
        _ = await executor.classify(audio: Data())

        let countAfter = await executor.classifyCallCount
        XCTAssertEqual(countAfter, 3,
                       "classifyCallCount должен увеличиться на 3 после 3 вызовов")
    }

    // MARK: - 9. Батч inference — детерминированный вывод

    func test_mockExecutor_batchInference_consistentResults() async {
        let executor = MockMLExecutor()
        var results = [[Float]]()
        for _ in 0..<10 {
            results.append(await executor.classify(audio: Data()))
        }
        let allEqual = results.allSatisfy { $0 == results[0] }
        XCTAssertTrue(allEqual,
                      "MockMLExecutor должен возвращать детерминированный вывод в батче")
    }

    // MARK: - 10. classifyDelay=0 → завершается быстро

    func test_mockExecutor_noDelay_completesImmediately() async {
        let executor = MockMLExecutor(classifyDelay: 0.0)
        let start = Date()
        _ = await executor.classify(audio: Data())
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 0.5,
                          "Без задержки inference должна завершиться за 500ms")
    }
}

// MARK: - VADResult Domain Logic Tests

/// Тесты VADSession domain logic (без Core ML).
final class VADSessionDomainTests: XCTestCase {

    // MARK: - 11. hasSpeech = true когда ≥30% чанков имеют речь

    func test_vadSession_hasSpeech_whenThresholdMet() {
        let chunks = (0..<10).map { i in
            VADResult(
                speechProbability: i < 4 ? 0.9 : 0.1,
                isSpeech: i < 4,
                threshold: 0.5,
                timestamp: TimeInterval(i) * 0.032
            )
        }
        let session = VADSession(chunks: chunks)
        XCTAssertTrue(session.hasSpeech,
                      "40% чанков с речью должны давать hasSpeech=true (порог 30%)")
    }

    // MARK: - 12. hasSpeech = false когда <30% чанков

    func test_vadSession_noSpeech_whenBelowThreshold() {
        let chunks = (0..<10).map { i in
            VADResult(
                speechProbability: i < 2 ? 0.9 : 0.1,
                isSpeech: i < 2,
                threshold: 0.5,
                timestamp: TimeInterval(i) * 0.032
            )
        }
        let session = VADSession(chunks: chunks)
        XCTAssertFalse(session.hasSpeech,
                       "20% чанков с речью должны давать hasSpeech=false (порог 30%)")
    }

    // MARK: - 13. speechDuration вычисляется корректно

    func test_vadSession_speechDuration_calculatedCorrectly() {
        let speechChunkCount = 5
        let chunks = (0..<10).map { i in
            VADResult(
                speechProbability: i < speechChunkCount ? 0.8 : 0.2,
                isSpeech: i < speechChunkCount,
                threshold: 0.5,
                timestamp: TimeInterval(i) * 0.032
            )
        }
        let session = VADSession(chunks: chunks)
        // 5 чанков * 512 сэмплов / 16000 Hz = 0.16 секунды
        let expected = TimeInterval(speechChunkCount) * TimeInterval(VADResult.Constants.chunkSize) /
                       TimeInterval(VADResult.Constants.sampleRate)
        XCTAssertEqual(session.speechDuration, expected, accuracy: 0.001,
                       "speechDuration должна равняться 5 * 512 / 16000 секунды")
    }

    // MARK: - 14. speechStart — первый момент начала речи

    func test_vadSession_speechStart_returnsFirstSpeechTimestamp() {
        let chunks = [
            VADResult(speechProbability: 0.1, isSpeech: false, threshold: 0.5, timestamp: 0.0),
            VADResult(speechProbability: 0.1, isSpeech: false, threshold: 0.5, timestamp: 0.032),
            VADResult(speechProbability: 0.9, isSpeech: true,  threshold: 0.5, timestamp: 0.064),
            VADResult(speechProbability: 0.9, isSpeech: true,  threshold: 0.5, timestamp: 0.096)
        ]
        let session = VADSession(chunks: chunks)
        XCTAssertEqual(session.speechStart ?? -1.0, 0.064, accuracy: 0.001,
                       "speechStart должен быть timestamp первого чанка с речью")
    }
}

// MARK: - PronunciationResult Domain Invariants

/// Тесты domain invariants PronunciationResult.
final class PronunciationResultDomainTests: XCTestCase {

    // MARK: - 15. isCorrect порог 0.6

    func test_pronunciationResult_isCorrect_atThreshold() {
        let belowThreshold = PronunciationResult(
            correctProbability: 0.59,
            incorrectProbability: 0.41,
            predictedLabel: "incorrect",
            phonemeGroup: .whistling
        )
        XCTAssertFalse(belowThreshold.isCorrect,
                       "0.59 < 0.6 → isCorrect должен быть false")

        let atThreshold = PronunciationResult(
            correctProbability: 0.60,
            incorrectProbability: 0.40,
            predictedLabel: "correct",
            phonemeGroup: .whistling
        )
        XCTAssertTrue(atThreshold.isCorrect,
                      "0.60 >= 0.6 → isCorrect должен быть true")
    }
}
