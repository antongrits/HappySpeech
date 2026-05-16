@testable import HappySpeech
import XCTest

// MARK: - EnsembleASRServiceTests
//
// 2.10 v25 — покрытие EnsembleASRService.
// phoneticAccuracy(child:reference:) — чистая on-device логика (RussianG2P +
// IPADictionary.articulationDistance), тестируется напрямую на LiveEnsembleASRService.
// recognize(url:tier:) загружает PCM из AVAudioFile и гоняет CoreML-модели —
// SDK/файл-bound, покрывается через MockEnsembleASRService (контракт + детектируемый tier).

final class EnsembleASRServiceTests: XCTestCase {

    private func makeLive() -> LiveEnsembleASRService {
        LiveEnsembleASRService(
            whisperASR: MockASRService(),
            phonemeClassifier: MockPhonemeAnalysisService(),
            pronunciationScorer: MockPronunciationScorerService()
        )
    }

    // MARK: - EnsembleASRDetailTier

    func test_tier_rawValues() {
        XCTAssertEqual(EnsembleASRDetailTier.a.rawValue, "a")
        XCTAssertEqual(EnsembleASRDetailTier.b.rawValue, "b")
    }

    // MARK: - phoneticAccuracy — pure on-device logic

    func test_phoneticAccuracy_identicalSequences_isPerfect() {
        let sut = makeLive()
        let phonemes = ["r", "ɨ", "b", "a"]
        let accuracy = sut.phoneticAccuracy(child: phonemes, reference: phonemes)
        XCTAssertEqual(accuracy, 1.0, accuracy: 0.0001, "Идентичные последовательности → 1.0")
    }

    func test_phoneticAccuracy_emptyChild_fallsBackToBaseSimilarity() {
        let sut = makeLive()
        let accuracy = sut.phoneticAccuracy(child: [], reference: ["r", "a"])
        XCTAssertGreaterThanOrEqual(accuracy, 0.0)
        XCTAssertLessThanOrEqual(accuracy, 1.0)
    }

    func test_phoneticAccuracy_isBoundedZeroToOne() {
        let sut = makeLive()
        let accuracy = sut.phoneticAccuracy(child: ["x", "y", "z"], reference: ["r", "a", "b"])
        XCTAssertGreaterThanOrEqual(accuracy, 0.0)
        XCTAssertLessThanOrEqual(accuracy, 1.0)
    }

    func test_phoneticAccuracy_closeSubstitution_scoresHigherThanFarOne() {
        let sut = makeLive()
        let reference = ["s", "a"]
        // sʲ — палатализованный s, артикуляционно близок к s.
        let closeAccuracy = sut.phoneticAccuracy(child: ["sʲ", "a"], reference: reference)
        // r — совсем другая фонема (сонор), артикуляционно далёк.
        let farAccuracy = sut.phoneticAccuracy(child: ["r", "a"], reference: reference)
        XCTAssertGreaterThanOrEqual(
            closeAccuracy, farAccuracy,
            "Близкая замена должна штрафоваться не сильнее далёкой"
        )
    }

    func test_phoneticAccuracy_differentLength_usesBaseSimilarity() {
        let sut = makeLive()
        let accuracy = sut.phoneticAccuracy(child: ["r"], reference: ["r", "ɨ", "b", "a"])
        XCTAssertGreaterThanOrEqual(accuracy, 0.0)
        XCTAssertLessThanOrEqual(accuracy, 1.0)
    }

    // MARK: - MockEnsembleASRService — voting / aggregation contract

    func test_mock_recognize_preservesRequestedTier() async throws {
        let mock = MockEnsembleASRService()
        let url = URL(fileURLWithPath: "/tmp/sample.wav")
        let resultA = try await mock.recognize(url: url, tier: .a)
        let resultB = try await mock.recognize(url: url, tier: .b)
        XCTAssertEqual(resultA.detectedTier, .a)
        XCTAssertEqual(resultB.detectedTier, .b)
    }

    func test_mock_recognize_returnsConfiguredValues() async throws {
        let mock = MockEnsembleASRService(
            transcript: "ракета", phonemeAccuracy: 0.77, confidence: 0.83, processingTimeMs: 30
        )
        let result = try await mock.recognize(url: URL(fileURLWithPath: "/tmp/x.wav"), tier: .a)
        XCTAssertEqual(result.transcript, "ракета")
        XCTAssertEqual(result.phonemeAccuracy, 0.77, accuracy: 0.0001)
        XCTAssertEqual(result.confidence, 0.83, accuracy: 0.0001)
        XCTAssertEqual(result.processingTimeMs, 30)
    }

    func test_mock_phoneticAccuracy_emptyReference_isPerfect() {
        let mock = MockEnsembleASRService()
        XCTAssertEqual(mock.phoneticAccuracy(child: [], reference: []), 1.0, accuracy: 0.0001)
    }

    func test_mock_phoneticAccuracy_fullMatch_isOne() {
        let mock = MockEnsembleASRService()
        let phonemes = ["r", "a"]
        XCTAssertEqual(
            mock.phoneticAccuracy(child: phonemes, reference: phonemes), 1.0, accuracy: 0.0001
        )
    }

    func test_mock_phoneticAccuracy_partialMatch_isProportional() {
        let mock = MockEnsembleASRService()
        let accuracy = mock.phoneticAccuracy(child: ["r", "x"], reference: ["r", "a"])
        XCTAssertEqual(accuracy, 0.5, accuracy: 0.0001, "Совпала 1 из 2 фонем → 0.5")
    }

    func test_mock_warmUp_doesNotThrow() async {
        let mock = MockEnsembleASRService()
        await mock.warmUp(tier: .a)
        await mock.warmUp(tier: .b)
    }

    // MARK: - EnsembleASRResult — value semantics

    func test_ensembleResult_storesFields() {
        let result = EnsembleASRResult(
            transcript: "рыба",
            phonemeAccuracy: 0.9,
            confidence: 0.88,
            detectedTier: .a,
            processingTimeMs: 45
        )
        XCTAssertEqual(result.transcript, "рыба")
        XCTAssertEqual(result.phonemeAccuracy, 0.9, accuracy: 0.0001)
        XCTAssertEqual(result.detectedTier, .a)
        XCTAssertEqual(result.processingTimeMs, 45)
    }
}
