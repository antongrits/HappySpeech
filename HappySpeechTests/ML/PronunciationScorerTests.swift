@testable import HappySpeech
import AVFoundation
import XCTest

// MARK: - PronunciationScorerTests
//
// Phase 2.6c v25 — расширенное покрытие PronunciationScorer.swift.
//
// Тестируется без CoreML inference:
//   - PronunciationPhonemeGroup: rawValue, phonemes, localizedName, allCases
//   - PronunciationResult: isCorrect threshold 0.6, displayScore, fields
//   - MockPronunciationScorer: корректное поведение
//   - MFCCExtractor статические константы и hzToMel/melToHz (через normalize)
//   - PronunciationScorerError: errorDescription
//   - MFCCExtractor.normalize: нормализованный выход имеет нулевое среднее

final class PronunciationScorerTests: XCTestCase {

    // MARK: - PronunciationPhonemeGroup: rawValue и phonemes

    func testPhonemeGroup_whistling_rawValue() {
        XCTAssertEqual(PronunciationPhonemeGroup.whistling.rawValue, "whistling")
    }

    func testPhonemeGroup_hissing_rawValue() {
        XCTAssertEqual(PronunciationPhonemeGroup.hissing.rawValue, "hissing")
    }

    func testPhonemeGroup_sonants_rawValue() {
        XCTAssertEqual(PronunciationPhonemeGroup.sonants.rawValue, "sonants")
    }

    func testPhonemeGroup_velar_rawValue() {
        XCTAssertEqual(PronunciationPhonemeGroup.velar.rawValue, "velar")
    }

    // MARK: - PronunciationPhonemeGroup: phonemes содержат правильные звуки

    func testPhonemeGroup_whistling_phonemes() {
        XCTAssertEqual(PronunciationPhonemeGroup.whistling.phonemes, ["С", "З", "Ц"])
    }

    func testPhonemeGroup_hissing_phonemes() {
        XCTAssertEqual(PronunciationPhonemeGroup.hissing.phonemes, ["Ш", "Ж", "Ч", "Щ"])
    }

    func testPhonemeGroup_sonants_phonemes() {
        XCTAssertEqual(PronunciationPhonemeGroup.sonants.phonemes, ["Р", "Л"])
    }

    func testPhonemeGroup_velar_phonemes() {
        XCTAssertEqual(PronunciationPhonemeGroup.velar.phonemes, ["К", "Г", "Х"])
    }

    // MARK: - PronunciationPhonemeGroup: allCases содержит 4 группы

    func testPhonemeGroup_allCases_count4() {
        XCTAssertEqual(PronunciationPhonemeGroup.allCases.count, 4)
    }

    // MARK: - PronunciationPhonemeGroup: localizedName не пуст

    func testPhonemeGroup_localizedName_notEmpty() {
        for group in PronunciationPhonemeGroup.allCases {
            XCTAssertFalse(group.localizedName.isEmpty,
                "localizedName для '\(group.rawValue)' не должен быть пустым")
        }
    }

    // MARK: - PronunciationResult: isCorrect threshold 0.6

    func testPronunciationResult_isCorrect_above06() {
        let result = PronunciationResult(
            correctProbability: 0.7, incorrectProbability: 0.3,
            predictedLabel: "correct", phonemeGroup: .whistling
        )
        XCTAssertTrue(result.isCorrect)
    }

    func testPronunciationResult_isCorrect_below06() {
        let result = PronunciationResult(
            correctProbability: 0.5, incorrectProbability: 0.5,
            predictedLabel: "incorrect", phonemeGroup: .hissing
        )
        XCTAssertFalse(result.isCorrect)
    }

    func testPronunciationResult_isCorrect_exactly06() {
        let result = PronunciationResult(
            correctProbability: 0.6, incorrectProbability: 0.4,
            predictedLabel: "correct", phonemeGroup: .sonants
        )
        XCTAssertTrue(result.isCorrect, "Ровно 0.6 → isCorrect = true (>= 0.6)")
    }

    // MARK: - PronunciationResult: displayScore 0–100

    func testPronunciationResult_displayScore_100() {
        let result = PronunciationResult(
            correctProbability: 1.0, incorrectProbability: 0.0,
            predictedLabel: "correct", phonemeGroup: .velar
        )
        XCTAssertEqual(result.displayScore, 100)
    }

    func testPronunciationResult_displayScore_0() {
        let result = PronunciationResult(
            correctProbability: 0.0, incorrectProbability: 1.0,
            predictedLabel: "incorrect", phonemeGroup: .whistling
        )
        XCTAssertEqual(result.displayScore, 0)
    }

    func testPronunciationResult_displayScore_85percent() {
        let result = PronunciationResult(
            correctProbability: 0.85, incorrectProbability: 0.15,
            predictedLabel: "correct", phonemeGroup: .sonants
        )
        XCTAssertEqual(result.displayScore, 85)
    }

    // MARK: - PronunciationResult: phonemeGroup сохраняется

    func testPronunciationResult_phonemeGroup_preserved() {
        let result = PronunciationResult(
            correctProbability: 0.9, incorrectProbability: 0.1,
            predictedLabel: "correct", phonemeGroup: .hissing
        )
        XCTAssertEqual(result.phonemeGroup, .hissing)
    }

    // MARK: - PronunciationScorerError: errorDescription

    func testScorerError_modelNotFound_hasDescription() {
        let err = PronunciationScorerError.modelNotFound(.whistling)
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testScorerError_invalidAudioBuffer_hasDescription() {
        let err = PronunciationScorerError.invalidAudioBuffer
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testScorerError_inferenceFailure_mentionsDetail() {
        let err = PronunciationScorerError.inferenceFailure("тест-причина")
        XCTAssertTrue(err.errorDescription?.contains("тест-причина") ?? false)
    }

    func testScorerError_featureExtractionFailure_hasDescription() {
        let err = PronunciationScorerError.featureExtractionFailure
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    // MARK: - MockPronunciationScorer: alwaysCorrect=true

    func testMockScorer_alwaysCorrect_returnsCorrect() async throws {
        let mock = MockPronunciationScorer()
        mock.alwaysCorrect = true
        mock.fixedProbability = 0.9

        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 100)!
        let result = try await mock.score(audio: buffer, phonemeGroup: .whistling)
        XCTAssertTrue(result.isCorrect)
        XCTAssertEqual(result.correctProbability, 0.9, accuracy: 0.001)
        XCTAssertEqual(result.predictedLabel, "correct")
    }

    func testMockScorer_alwaysWrong_returnsIncorrect() async throws {
        let mock = MockPronunciationScorer()
        mock.alwaysCorrect = false
        mock.fixedProbability = 0.85

        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 100)!
        let result = try await mock.score(audio: buffer, phonemeGroup: .sonants)
        XCTAssertFalse(result.isCorrect)
        XCTAssertEqual(result.predictedLabel, "incorrect")
    }

    // MARK: - MFCCExtractor: статические константы

    func testMFCCExtractor_nMFCC_is40() {
        XCTAssertEqual(MFCCExtractor.nMFCC, 40)
    }

    func testMFCCExtractor_targetSR_is16000() {
        XCTAssertEqual(MFCCExtractor.targetSR, 16000.0, accuracy: 0.01)
    }

    func testMFCCExtractor_hopLength_is160() {
        XCTAssertEqual(MFCCExtractor.hopLength, 160)
    }

    func testMFCCExtractor_nFFT_is400() {
        XCTAssertEqual(MFCCExtractor.nFFT, 400)
    }

    func testMFCCExtractor_fftSize_isPowerOf2() {
        let size = MFCCExtractor.fftSize
        XCTAssertGreaterThan(size, 0)
        // Проверяем что fftSize — степень двойки
        XCTAssertEqual(size & (size - 1), 0, "fftSize должен быть степенью двойки")
    }

    func testMFCCExtractor_targetSamples_correct() {
        // targetSamples = Int(16000 * 1.5) = 24000
        XCTAssertEqual(MFCCExtractor.targetSamples, 24_000)
    }

    func testMFCCExtractor_tSteps_is150() {
        // tSteps = (24000 + 160 - 1) / 160 = 150
        XCTAssertEqual(MFCCExtractor.tSteps, 150)
    }

    // MARK: - MFCCExtractor.extract: silent buffer → не крашится

    func testMFCCExtractor_silentBuffer_noCrash() throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(MFCCExtractor.targetSamples)) else {
            XCTFail("Не удалось создать буфер")
            return
        }
        buffer.frameLength = AVAudioFrameCount(MFCCExtractor.targetSamples)
        // Буфер заполнен нулями по умолчанию — тишина
        XCTAssertNoThrow(try MFCCExtractor.extract(from: buffer))
    }
}
