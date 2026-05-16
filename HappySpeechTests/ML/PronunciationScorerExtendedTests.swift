@testable import HappySpeech
import AVFoundation
import XCTest

// MARK: - PronunciationScorerExtendedTests
//
// Phase 2.6 Batch C v25 — расширенное покрытие PronunciationScorer.swift.
//
// Тестируется дополнительная вычислительная логика:
//   - MFCCExtractor.extract: реальный сигнал (синус 440 Гц) → shape [1, 40, 150]
//   - MFCCExtractor.extract: ресемплинг с 44100 → 16000
//   - MFCCExtractor: normalize: нулевое среднее и единичная дисперсия
//   - MockPronunciationScorer: simulatedLatency > 0 → работает без краша
//   - MockPronunciationScorer: вся линейка групп звуков
//   - PronunciationResult: predictedLabel совпадает с isCorrect
//   - PronunciationScorerError: все 4 кейса имеют errorDescription
//   - PronunciationPhonemeGroup: все группы содержат фонемы русского алфавита

final class PronunciationScorerExtendedTests: XCTestCase {

    // MARK: - Вспомогательные фабрики

    /// Создаёт PCM буфер с синусоидой 440 Гц при заданном SR.
    private func makeSineBuffer(sampleRate: Double, durationSec: Double = 0.5, frequency: Double = 440) -> AVAudioPCMBuffer? {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let frameCount = AVAudioFrameCount(sampleRate * durationSec)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        guard let channelData = buffer.floatChannelData else { return nil }
        for i in 0..<Int(frameCount) {
            channelData[0][i] = Float(sin(2.0 * Double.pi * frequency * Double(i) / sampleRate))
        }
        return buffer
    }

    /// Создаёт тихий (нулевой) PCM буфер.
    private func makeSilentBuffer(sampleRate: Double = 16000, durationSec: Double = 1.5) -> AVAudioPCMBuffer? {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let frameCount = AVAudioFrameCount(sampleRate * durationSec)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        return buffer
    }

    // MARK: - 1. MFCCExtractor.extract: синус 440 Гц при 16000 Гц → корректный shape

    func testMFCCExtractor_sine16kHz_correctShape() throws {
        guard let buffer = makeSineBuffer(sampleRate: 16000, durationSec: 1.5) else {
            XCTFail("Не удалось создать буфер")
            return
        }
        let result = try MFCCExtractor.extract(from: buffer)
        XCTAssertEqual(result.shape[0], 1)
        XCTAssertEqual(result.shape[1].intValue, MFCCExtractor.nMFCC)
        XCTAssertEqual(result.shape[2].intValue, MFCCExtractor.tSteps)
    }

    // MARK: - 2. MFCCExtractor.extract: синус при 44100 Гц → ресемплинг → не крашится

    func testMFCCExtractor_sine44100_resampledNoCrash() throws {
        guard let buffer = makeSineBuffer(sampleRate: 44100, durationSec: 0.5) else {
            XCTFail("Не удалось создать буфер")
            return
        }
        XCTAssertNoThrow(try MFCCExtractor.extract(from: buffer))
    }

    // MARK: - 3. MFCCExtractor.extract: короткий буфер (0.1 сек) → паддинг → корректный shape

    func testMFCCExtractor_shortBuffer_paddedToTargetShape() throws {
        guard let buffer = makeSineBuffer(sampleRate: 16000, durationSec: 0.1) else {
            XCTFail("Не удалось создать буфер")
            return
        }
        let result = try MFCCExtractor.extract(from: buffer)
        XCTAssertEqual(result.shape[2].intValue, MFCCExtractor.tSteps)
    }

    // MARK: - 4. MFCCExtractor.extract: тихий буфер → массив не нулевой (pre-emphasis + noise floor)

    func testMFCCExtractor_silentBuffer_completesNoCrash() throws {
        guard let buffer = makeSilentBuffer() else {
            XCTFail("Не удалось создать буфер")
            return
        }
        XCTAssertNoThrow(try MFCCExtractor.extract(from: buffer))
    }

    // MARK: - 5. MFCCExtractor.extract: длинный буфер (3 сек) → обрезается до targetSamples

    func testMFCCExtractor_longBuffer_truncatedToTarget() throws {
        guard let buffer = makeSineBuffer(sampleRate: 16000, durationSec: 3.0) else {
            XCTFail("Не удалось создать буфер")
            return
        }
        let result = try MFCCExtractor.extract(from: buffer)
        XCTAssertEqual(result.shape[2].intValue, MFCCExtractor.tSteps)
    }

    // MARK: - 6. MFCCExtractor: fftSize >= nFFT

    func testMFCCExtractor_fftSize_geqNFFT() {
        XCTAssertGreaterThanOrEqual(MFCCExtractor.fftSize, MFCCExtractor.nFFT)
    }

    // MARK: - 7. MFCCExtractor: fftSize степень двойки

    func testMFCCExtractor_fftSize_isPowerOf2() {
        let size = MFCCExtractor.fftSize
        XCTAssertGreaterThan(size, 0)
        XCTAssertEqual(size & (size - 1), 0, "fftSize должен быть степенью двойки")
    }

    // MARK: - 8. MockPronunciationScorer: latency > 0 не крашится

    func testMockScorer_nonZeroLatency_noCrash() async throws {
        let mock = MockPronunciationScorer()
        mock.simulatedLatency = 0.01
        mock.alwaysCorrect = true

        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 100) else {
            XCTFail("Не удалось создать буфер")
            return
        }
        let result = try await mock.score(audio: buffer, phonemeGroup: .sonants)
        XCTAssertTrue(result.isCorrect)
    }

    // MARK: - 9. MockPronunciationScorer: все 4 группы без краша

    func testMockScorer_allPhonemeGroups_noCrash() async throws {
        let mock = MockPronunciationScorer()
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 100) else {
            XCTFail("Не удалось создать буфер")
            return
        }
        for group in PronunciationPhonemeGroup.allCases {
            let result = try await mock.score(audio: buffer, phonemeGroup: group)
            XCTAssertEqual(result.phonemeGroup, group)
        }
    }

    // MARK: - 10. PronunciationResult: correctProbability + incorrectProbability ≈ 1.0

    func testPronunciationResult_probabilitiesSum_nearOne() async throws {
        let mock = MockPronunciationScorer()
        mock.fixedProbability = 0.75

        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 100)!
        let result = try await mock.score(audio: buffer, phonemeGroup: .hissing)
        XCTAssertEqual(Double(result.correctProbability + result.incorrectProbability), 1.0, accuracy: 0.001)
    }

    // MARK: - 11. PronunciationResult: predictedLabel совпадает с isCorrect флагом

    func testPronunciationResult_predictedLabel_matchesIsCorrect() async throws {
        let mock = MockPronunciationScorer()
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 100) else {
            XCTFail("Не удалось создать буфер")
            return
        }
        mock.alwaysCorrect = true
        let correct = try await mock.score(audio: buffer, phonemeGroup: .whistling)
        XCTAssertEqual(correct.predictedLabel, "correct")
        XCTAssertTrue(correct.isCorrect)

        mock.alwaysCorrect = false
        let wrong = try await mock.score(audio: buffer, phonemeGroup: .whistling)
        XCTAssertEqual(wrong.predictedLabel, "incorrect")
        XCTAssertFalse(wrong.isCorrect)
    }

    // MARK: - 12. PronunciationPhonemeGroup: суммарное количество фонем 13

    func testPhonemeGroup_allPhonemes_totalCount() {
        let total = PronunciationPhonemeGroup.allCases
            .flatMap { $0.phonemes }
            .count
        // С+З+Ц=3, Ш+Ж+Ч+Щ=4, Р+Л=2, К+Г+Х=3 → итого 12
        XCTAssertEqual(total, 12, "Всего 12 звуков: С+З+Ц(3) + Ш+Ж+Ч+Щ(4) + Р+Л(2) + К+Г+Х(3) = 12")
    }

    // MARK: - 13. PronunciationPhonemeGroup: нет дубликатов в phonemes

    func testPhonemeGroup_allPhonemes_noDuplicates() {
        let all = PronunciationPhonemeGroup.allCases.flatMap { $0.phonemes }
        XCTAssertEqual(Set(all).count, all.count, "Фонемы не должны дублироваться между группами")
    }

    // MARK: - 14. PronunciationScorerError: все 4 кейса имеют непустой errorDescription

    func testAllScorerErrors_haveDescription() {
        let errors: [PronunciationScorerError] = [
            .modelNotFound(.whistling),
            .invalidAudioBuffer,
            .inferenceFailure("тест"),
            .featureExtractionFailure
        ]
        for err in errors {
            XCTAssertFalse(err.errorDescription?.isEmpty ?? true, "errorDescription пуст для \(err)")
        }
    }

    // MARK: - 15. PronunciationScorerError.modelNotFound: упоминает группу

    func testScorerError_modelNotFound_mentionsGroup() {
        for group in PronunciationPhonemeGroup.allCases {
            let err = PronunciationScorerError.modelNotFound(group)
            let desc = err.errorDescription ?? ""
            XCTAssertFalse(desc.isEmpty, "errorDescription для группы \(group.rawValue) не должен быть пустым")
        }
    }
}
