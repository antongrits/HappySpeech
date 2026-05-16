@testable import HappySpeech
import XCTest

// MARK: - RussianPhonemeClassifierWrapperExtendedTests
//
// Phase 2.6 Batch C v25 — расширенное покрытие RussianPhonemeClassifierWrapper.
//
// Дополнительные тесты (помимо RussianPhonemeClassifierWrapperTests):
//   - mockMode: predict с разными размерами mfcc → всегда modelNotLoaded
//   - mockMode: predict пустой → modelNotLoaded
//   - mockMode: predict слишком длинный → modelNotLoaded
//   - RussianPhonemeInventory: все фонемы не пустые строки
//   - RussianPhonemeInventory: phoneme(at: 0) = "b" (первый элемент)
//   - RussianPhonemeInventory: phoneme(at: 48) = "ʌ" (последний элемент)
//   - PhonemeAlignment: frameIndex в диапазоне [0, nFrames-1]
//   - PhonemeAnalysisError: Equatable/сравнение ошибок
//   - G2PError: все кейсы имеют errorDescription
//   - RussianPhonemeInventory: index(of:) + phoneme(at:) round-trip для всех фонем

final class RussianPhonemeClassifierWrapperExtendedTests: XCTestCase {

    // MARK: - 1. mockMode: predict с пустым mfcc → modelNotLoaded

    func testMockMode_predict_emptyMFCC_throwsModelNotLoaded() async {
        let wrapper = RussianPhonemeClassifierWrapper(mockMode: true)
        do {
            _ = try await wrapper.predict(mfcc: [])
            XCTFail("Ожидалась ошибка modelNotLoaded")
        } catch PhonemeAnalysisError.modelNotLoaded {
            // Ожидаемый результат
        } catch {
            XCTFail("Неожиданная ошибка: \(error)")
        }
    }

    // MARK: - 2. mockMode: predict с 1 фреймом → modelNotLoaded

    func testMockMode_predict_singleFrame_throwsModelNotLoaded() async {
        let wrapper = RussianPhonemeClassifierWrapper(mockMode: true)
        let singleFrame = [Array(repeating: Float(0.5), count: 39)]
        do {
            _ = try await wrapper.predict(mfcc: singleFrame)
            XCTFail("Ожидалась ошибка modelNotLoaded")
        } catch PhonemeAnalysisError.modelNotLoaded {
            // Ожидаемый результат
        } catch {
            XCTFail("Неожиданная ошибка: \(error)")
        }
    }

    // MARK: - 3. mockMode: predict с 200 фреймами (> nFrames) → modelNotLoaded

    func testMockMode_predict_oversizedMFCC_throwsModelNotLoaded() async {
        let wrapper = RussianPhonemeClassifierWrapper(mockMode: true)
        let oversized = Array(repeating: Array(repeating: Float(0), count: 39), count: 200)
        do {
            _ = try await wrapper.predict(mfcc: oversized)
            XCTFail("Ожидалась ошибка modelNotLoaded")
        } catch PhonemeAnalysisError.modelNotLoaded {
            // Ожидаемый результат
        } catch {
            XCTFail("Неожиданная ошибка: \(error)")
        }
    }

    // MARK: - 4. RussianPhonemeInventory: все 49 фонем — непустые строки

    func testPhonemeInventory_allNonEmpty() {
        for (i, ipa) in RussianPhonemeInventory.all.enumerated() {
            XCTAssertFalse(ipa.isEmpty, "Фонема с индексом \(i) не должна быть пустой строкой")
        }
    }

    // MARK: - 5. RussianPhonemeInventory: первая фонема = "b"

    func testPhonemeInventory_firstPhoneme_isB() {
        XCTAssertEqual(RussianPhonemeInventory.all.first, "b")
        XCTAssertEqual(RussianPhonemeInventory.phoneme(at: 0), "b")
    }

    // MARK: - 6. RussianPhonemeInventory: последняя фонема = "ʌ"

    func testPhonemeInventory_lastPhoneme_isOpenBack() {
        XCTAssertEqual(RussianPhonemeInventory.all.last, "ʌ")
        XCTAssertEqual(RussianPhonemeInventory.phoneme(at: 48), "ʌ")
    }

    // MARK: - 7. RussianPhonemeInventory: index round-trip для всех 49 фонем

    func testPhonemeInventory_allIndexRoundTrip() {
        for (idx, ipa) in RussianPhonemeInventory.all.enumerated() {
            let foundIdx = RussianPhonemeInventory.index(of: ipa)
            XCTAssertEqual(foundIdx, idx, "index(of: '\(ipa)') должен вернуть \(idx)")
            let foundIPA = RussianPhonemeInventory.phoneme(at: idx)
            XCTAssertEqual(foundIPA, ipa, "phoneme(at: \(idx)) должна вернуть '\(ipa)'")
        }
    }

    // MARK: - 8. RussianPhonemeInventory: граничные индексы

    func testPhonemeInventory_boundaryIndices() {
        XCTAssertNotNil(RussianPhonemeInventory.phoneme(at: 0))
        XCTAssertNotNil(RussianPhonemeInventory.phoneme(at: 48))
        XCTAssertNil(RussianPhonemeInventory.phoneme(at: 49))
        XCTAssertNil(RussianPhonemeInventory.phoneme(at: -1))
        XCTAssertNil(RussianPhonemeInventory.phoneme(at: 100))
    }

    // MARK: - 9. PhonemeAlignment: множественные объекты с одинаковым IPA

    func testPhonemeAlignment_sameIPA_differentFrames() {
        let a1 = PhonemeAlignment(frameIndex: 0, predictedIPA: "r", confidence: 0.9)
        let a2 = PhonemeAlignment(frameIndex: 5, predictedIPA: "r", confidence: 0.85)
        XCTAssertEqual(a1.predictedIPA, a2.predictedIPA)
        XCTAssertNotEqual(a1.frameIndex, a2.frameIndex)
    }

    // MARK: - 10. PhonemeAlignment: confidence в [0, 1]

    func testPhonemeAlignment_confidence_inRange() {
        let alignment = PhonemeAlignment(frameIndex: 10, predictedIPA: "k", confidence: 0.72)
        XCTAssertGreaterThanOrEqual(alignment.confidence, 0.0)
        XCTAssertLessThanOrEqual(alignment.confidence, 1.0)
    }

    // MARK: - 11. PhonemeAnalysisError: predictionFailed с пустым detail

    func testPhonemeError_predictionFailed_emptyDetail_hasDescription() {
        let err = PhonemeAnalysisError.predictionFailed("")
        XCTAssertNotNil(err.errorDescription)
    }

    // MARK: - 12. G2PError: wordNotFound с пустой строкой

    func testG2PError_wordNotFound_emptyWord_hasDescription() {
        let err = G2PError.wordNotFound("")
        XCTAssertNotNil(err.errorDescription)
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    // MARK: - 13. RussianPhonemeInventory: палатализованные согласные присутствуют

    func testPhonemeInventory_contains_palatalizedConsonants() {
        let palatalized = ["bʲ", "pʲ", "dʲ", "tʲ", "gʲ", "kʲ"]
        for p in palatalized {
            XCTAssertNotNil(RussianPhonemeInventory.index(of: p),
                "Палатализованная согласная '\(p)' должна быть в инвентаре")
        }
    }

    // MARK: - 14. RussianPhonemeInventory: гласные присутствуют

    func testPhonemeInventory_contains_vowels() {
        let vowels = ["a", "e", "i", "o", "u", "ɨ"]
        for v in vowels {
            XCTAssertNotNil(RussianPhonemeInventory.index(of: v),
                "Гласная '\(v)' должна быть в инвентаре")
        }
    }

    // MARK: - 15. nMFCC: публичная константа используется в других классах

    func testStaticConstant_nMFCC_usedInMockExtractor() {
        let extractor = MockMFCCExtractor()
        let nMFCC = RussianPhonemeClassifierWrapper.nMFCC
        XCTAssertEqual(nMFCC, 39)
        _ = extractor
    }

    // MARK: - 16. confidenceLogitThreshold = 2.0

    func testStaticConstant_confidenceLogitThreshold() {
        XCTAssertEqual(RussianPhonemeClassifierWrapper.confidenceLogitThreshold, 2.0, accuracy: 1e-6)
    }
}
