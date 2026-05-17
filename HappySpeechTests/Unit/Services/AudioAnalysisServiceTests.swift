@preconcurrency import AVFoundation
@testable import HappySpeech
import XCTest

// MARK: - AudioAnalysisServiceTests
//
// 2.6b v25 — покрытие AudioAnalysisService.
// LiveAudioAnalysisService — actor без Firebase-зависимостей. Модель
// SoundClassifier.mlpackage отсутствует в тестовом бандле, поэтому
// classifySound / isSpeech идут по детерминированной fallback-ветви
// (.silence, confidence 1.0) — это и проверяется (COPPA-safe pre-filter).
// Реальный CoreML inference (runInference / computeLogMel через модель) —
// genuinely SDK/файл-bound, документировано для ADR-V25-COVERAGE.

final class AudioAnalysisServiceTests: XCTestCase {

    // MARK: - Helpers

    /// Создаёт PCM-буфер 16kHz mono, заполненный заданной амплитудой.
    private func makeBuffer(
        frameCount: Int = 16_000,
        amplitude: Float = 0.0
    ) throws -> AVAudioPCMBuffer {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ) else {
            throw NSError(domain: "AudioAnalysisTest", code: 1)
        }
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(frameCount)
        ) else {
            throw NSError(domain: "AudioAnalysisTest", code: 2)
        }
        buffer.frameLength = AVAudioFrameCount(frameCount)
        if let channel = buffer.floatChannelData?[0] {
            for index in 0..<frameCount {
                channel[index] = amplitude
            }
        }
        return buffer
    }

    // MARK: - SoundClass

    func test_soundClass_allCases_hasFourClasses() {
        XCTAssertEqual(SoundClass.allCases.count, 4)
        XCTAssertEqual(
            Set(SoundClass.allCases.map(\.rawValue)),
            ["speech", "noise", "silence", "breathing"]
        )
    }

    func test_soundClass_rawValueRoundTrip() {
        for soundClass in SoundClass.allCases {
            XCTAssertEqual(SoundClass(rawValue: soundClass.rawValue), soundClass)
        }
    }

    func test_soundClass_invalidRawValue_returnsNil() {
        XCTAssertNil(SoundClass(rawValue: "music"))
    }

    func test_soundClass_localizedDescriptions_areNonEmpty() {
        for soundClass in SoundClass.allCases {
            XCTAssertFalse(
                soundClass.localizedDescription.isEmpty,
                "\(soundClass) без локализованного описания"
            )
        }
    }

    // MARK: - AudioAnalysisResult — value semantics

    func test_audioAnalysisResult_storesAllFields() {
        let probabilities: [SoundClass: Float] = [.speech: 0.8, .noise: 0.2]
        let result = AudioAnalysisResult(
            soundClass: .speech,
            confidence: 0.8,
            probabilities: probabilities
        )
        XCTAssertEqual(result.soundClass, .speech)
        XCTAssertEqual(result.confidence, 0.8, accuracy: 0.0001)
        XCTAssertEqual(result.probabilities[.speech], 0.8)
        XCTAssertEqual(result.probabilities[.noise], 0.2)
    }

    // MARK: - LiveAudioAnalysisService — fallback (модель отсутствует)

    func test_live_classifySound_withoutModel_returnsSilenceFallback() async throws {
        let service = LiveAudioAnalysisService()
        let buffer = try makeBuffer(amplitude: 0.5)
        let result = await service.classifySound(buffer)
        XCTAssertEqual(result.soundClass, .silence, "Без модели — безопасный silence fallback")
        XCTAssertEqual(result.confidence, 1.0, accuracy: 0.0001)
    }

    func test_live_classifySound_fallbackProbabilities_sumToOne() async throws {
        let service = LiveAudioAnalysisService()
        let buffer = try makeBuffer()
        let result = await service.classifySound(buffer)
        let total = result.probabilities.values.reduce(0, +)
        XCTAssertEqual(total, 1.0, accuracy: 0.0001)
    }

    func test_live_classifySound_fallbackContainsAllFourClasses() async throws {
        let service = LiveAudioAnalysisService()
        let buffer = try makeBuffer()
        let result = await service.classifySound(buffer)
        XCTAssertEqual(Set(result.probabilities.keys), Set(SoundClass.allCases))
    }

    func test_live_isSpeech_withoutModel_returnsFalse() async throws {
        let service = LiveAudioAnalysisService()
        let buffer = try makeBuffer(amplitude: 0.7)
        let isSpeech = await service.isSpeech(buffer)
        XCTAssertFalse(isSpeech, "Fallback классифицирует как silence → не речь")
    }

    func test_live_classifySound_emptyBuffer_doesNotCrash() async throws {
        let service = LiveAudioAnalysisService()
        let buffer = try makeBuffer(frameCount: 0)
        let result = await service.classifySound(buffer)
        XCTAssertEqual(result.soundClass, .silence)
    }

    func test_live_classifySound_shortBuffer_handlesPadding() async throws {
        let service = LiveAudioAnalysisService()
        // Короче nSamples (16000) — внутренний computeLogMel должен паддить.
        let buffer = try makeBuffer(frameCount: 4_000, amplitude: 0.3)
        let result = await service.classifySound(buffer)
        XCTAssertEqual(result.confidence, 1.0, accuracy: 0.0001)
    }

    func test_live_classifySound_longBuffer_handlesTrim() async throws {
        let service = LiveAudioAnalysisService()
        // Длиннее nSamples — внутренний computeLogMel должен обрезать.
        let buffer = try makeBuffer(frameCount: 32_000, amplitude: 0.2)
        let result = await service.classifySound(buffer)
        XCTAssertEqual(result.soundClass, .silence)
    }

    // MARK: - AudioAnalysisError — localized descriptions

    func test_error_descriptions_areNonEmpty() {
        let errors: [AudioAnalysisError] = [
            .modelNotFound,
            .inferenceFailure("деталь сбоя")
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
    }

    func test_error_inferenceFailure_includesDetail() {
        let description = AudioAnalysisError.inferenceFailure("CoreML сбой").errorDescription ?? ""
        XCTAssertTrue(description.contains("CoreML сбой"))
    }

    // MARK: - MockAudioAnalysisService

    func test_mock_default_returnsSpeech() async throws {
        let mock = MockAudioAnalysisService()
        let buffer = try makeBuffer()
        let result = await mock.classifySound(buffer)
        XCTAssertEqual(result.soundClass, .speech)
        XCTAssertEqual(result.confidence, 0.95, accuracy: 0.001)
    }

    func test_mock_isSpeech_followsMockedClass() async throws {
        let mock = MockAudioAnalysisService()
        let buffer = try makeBuffer()
        var isSpeech = await mock.isSpeech(buffer)
        XCTAssertTrue(isSpeech)

        mock.mockedClass = .noise
        isSpeech = await mock.isSpeech(buffer)
        XCTAssertFalse(isSpeech)
    }

    func test_mock_customConfiguration_propagates() async throws {
        let mock = MockAudioAnalysisService()
        mock.mockedClass = .breathing
        mock.mockedConfidence = 0.42
        let buffer = try makeBuffer()
        let result = await mock.classifySound(buffer)
        XCTAssertEqual(result.soundClass, .breathing)
        XCTAssertEqual(result.confidence, 0.42, accuracy: 0.001)
    }
}
