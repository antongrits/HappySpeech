@preconcurrency import AVFoundation
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

    // MARK: - LiveEnsembleASRService — recognize (через mock-зависимости + реальный WAV)

    /// Создаёт валидный WAV-файл 16kHz mono в tmp для LiveEnsembleASRService.loadPCMData.
    private func makeTempWAV(durationSec: Double = 1.0) throws -> URL {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ) else {
            throw NSError(domain: "EnsembleASRTest", code: 1)
        }
        let frameCount = AVAudioFrameCount(16_000 * durationSec)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "EnsembleASRTest", code: 2)
        }
        buffer.frameLength = frameCount
        if let channel = buffer.floatChannelData?[0] {
            for index in 0..<Int(frameCount) {
                channel[index] = sin(2.0 * .pi * 440.0 * Float(index) / 16_000.0) * 0.3
            }
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ensemble_\(UUID().uuidString).wav")
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }

    func test_live_recognize_tierA_returnsResultWithTierA() async throws {
        let sut = makeLive()
        let url = try makeTempWAV()
        defer { try? FileManager.default.removeItem(at: url) }
        let result = try await sut.recognize(url: url, tier: .a)
        XCTAssertEqual(result.detectedTier, .a, "Tier A — детский on-device контур")
        XCTAssertGreaterThanOrEqual(result.confidence, 0.0)
        XCTAssertLessThanOrEqual(result.confidence, 1.0)
        XCTAssertGreaterThanOrEqual(result.processingTimeMs, 0)
    }

    func test_live_recognize_tierB_returnsResultWithTierB() async throws {
        let sut = makeLive()
        let url = try makeTempWAV()
        defer { try? FileManager.default.removeItem(at: url) }
        let result = try await sut.recognize(url: url, tier: .b)
        XCTAssertEqual(result.detectedTier, .b, "Tier B — родительский/специалист контур")
        XCTAssertGreaterThanOrEqual(result.confidence, 0.0)
    }

    func test_live_recognize_tierB_usesWhisperTranscript() async throws {
        let sut = makeLive()
        let url = try makeTempWAV()
        defer { try? FileManager.default.removeItem(at: url) }
        let result = try await sut.recognize(url: url, tier: .b)
        // MockASRService возвращает "рыба" — Tier B берёт Whisper-транскрипт.
        XCTAssertEqual(result.transcript, "рыба")
    }

    func test_live_recognize_invalidURL_throws() async {
        let sut = makeLive()
        let badURL = URL(fileURLWithPath: "/tmp/definitely_missing_\(UUID().uuidString).wav")
        do {
            _ = try await sut.recognize(url: badURL, tier: .a)
            XCTFail("Несуществующий файл должен бросить ошибку")
        } catch {
            // Ожидаемо — AVAudioFile не открывает несуществующий путь.
        }
    }

    func test_live_warmUp_doesNotCrash() async {
        let sut = makeLive()
        await sut.warmUp(tier: .a)
        await sut.warmUp(tier: .b)
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
