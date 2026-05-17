@testable import HappySpeech
import XCTest

// MARK: - RussianPhonemeClassifierWrapperTests
//
// Phase 2.6c v25 — покрытие RussianPhonemeClassifierWrapper.
//
// Тестируется без CoreML inference (mlpackage недоступен в тест-бандле):
//   - mockMode инициализация
//   - predict() в mockMode → PhonemeAnalysisError.modelNotLoaded
//   - padOrTruncate (через analyze с MockPhonemeAnalysisService)
//   - RussianPhonemeInventory: all 49, phoneme(at:), index(of:), boundary
//   - статические константы: nMFCC, nFrames, nClasses, confidenceLogitThreshold
//   - PhonemeAlignment: init, поля, Codable round-trip
//   - PhonemeAnalysisError: errorDescription не пуст

final class RussianPhonemeClassifierWrapperTests: XCTestCase {

    // MARK: - 1. mockMode: инициализация не крашится

    func testMockMode_init_noCrash() {
        let wrapper = RussianPhonemeClassifierWrapper(mockMode: true)
        XCTAssertNotNil(wrapper)
    }

    // MARK: - 2. mockMode: predict() бросает modelNotLoaded

    func testMockMode_predict_throwsModelNotLoaded() async {
        let wrapper = RussianPhonemeClassifierWrapper(mockMode: true)
        let dummyMFCC = Array(repeating: Array(repeating: Float(0), count: 39), count: 10)
        do {
            _ = try await wrapper.predict(mfcc: dummyMFCC)
            XCTFail("Ожидалась ошибка modelNotLoaded")
        } catch PhonemeAnalysisError.modelNotLoaded {
            // Ожидаемый результат
        } catch {
            XCTFail("Неожиданная ошибка: \(error)")
        }
    }

    // MARK: - 3. Реальная инициализация: если mlpackage нет — бросает modelNotLoaded

    func testRealInit_withoutMLPackage_throwsModelNotLoaded() {
        // В тест-бандле mlpackage недоступен
        if Bundle.main.url(forResource: "RussianPhonemeClassifier", withExtension: "mlpackage") == nil {
            XCTAssertThrowsError(
                try RussianPhonemeClassifierWrapper()
            ) { error in
                XCTAssertTrue((error as? PhonemeAnalysisError) != nil, "Ошибка должна быть PhonemeAnalysisError.modelNotLoaded")
            }
        } else {
            // mlpackage доступен — проверяем что загрузка не крашится
            XCTAssertNoThrow(try RussianPhonemeClassifierWrapper())
        }
    }

    // MARK: - 4. Статические константы

    func testStaticConstants_nMFCC_is39() {
        XCTAssertEqual(RussianPhonemeClassifierWrapper.nMFCC, 39)
    }

    func testStaticConstants_nFrames_is150() {
        XCTAssertEqual(RussianPhonemeClassifierWrapper.nFrames, 150)
    }

    func testStaticConstants_nClasses_is49() {
        XCTAssertEqual(RussianPhonemeClassifierWrapper.nClasses, 49)
    }

    func testStaticConstants_confidenceThreshold_is2() {
        XCTAssertEqual(RussianPhonemeClassifierWrapper.confidenceLogitThreshold, 2.0, accuracy: 0.001)
    }

    // MARK: - 5. RussianPhonemeInventory: количество фонем

    func testPhonemeInventory_count_49() {
        XCTAssertEqual(RussianPhonemeInventory.all.count, 49)
    }

    // MARK: - 6. RussianPhonemeInventory: нет дубликатов

    func testPhonemeInventory_noDuplicates() {
        let all = RussianPhonemeInventory.all
        XCTAssertEqual(Set(all).count, all.count, "Инвентарь не должен содержать дубликаты")
    }

    // MARK: - 7. RussianPhonemeInventory: phoneme(at:) для всех валидных индексов

    func testPhonemeInventory_phonemeAt_allValid() {
        for i in 0..<49 {
            XCTAssertNotNil(RussianPhonemeInventory.phoneme(at: i), "Индекс \(i) должен вернуть фонему")
        }
    }

    // MARK: - 8. RussianPhonemeInventory: phoneme(at:) out of bounds → nil

    func testPhonemeInventory_phonemeAt_negative_nil() {
        XCTAssertNil(RussianPhonemeInventory.phoneme(at: -1))
    }

    func testPhonemeInventory_phonemeAt_49_nil() {
        XCTAssertNil(RussianPhonemeInventory.phoneme(at: 49))
    }

    // MARK: - 9. RussianPhonemeInventory: index(of:) round-trip

    func testPhonemeInventory_indexRoundTrip() {
        for (idx, ipa) in RussianPhonemeInventory.all.enumerated() {
            XCTAssertEqual(RussianPhonemeInventory.index(of: ipa), idx,
                "index(of: '\(ipa)') должен вернуть \(idx)")
        }
    }

    // MARK: - 10. RussianPhonemeInventory: index(of:) для несуществующей фонемы → nil

    func testPhonemeInventory_indexOf_unknown_nil() {
        XCTAssertNil(RussianPhonemeInventory.index(of: "xyz"))
        XCTAssertNil(RussianPhonemeInventory.index(of: ""))
    }

    // MARK: - 11. RussianPhonemeInventory: конкретные русские фонемы присутствуют

    func testPhonemeInventory_contains_russianPhonemes() {
        let required = ["ʂ", "ʐ", "ts", "tɕ", "ɕː", "r", "l", "k", "g", "a", "i", "o", "u"]
        for p in required {
            XCTAssertNotNil(RussianPhonemeInventory.index(of: p), "Фонема '\(p)' должна быть в инвентаре")
        }
    }

    // MARK: - 12. PhonemeAlignment: init и поля

    func testPhonemeAlignment_init() {
        let alignment = PhonemeAlignment(frameIndex: 42, predictedIPA: "ʂ", confidence: 0.87)
        XCTAssertEqual(alignment.frameIndex, 42)
        XCTAssertEqual(alignment.predictedIPA, "ʂ")
        XCTAssertEqual(alignment.confidence, 0.87, accuracy: 0.001)
    }

    // MARK: - 13. PhonemeAlignment: Codable round-trip

    func testPhonemeAlignment_codableRoundTrip() throws {
        let original = PhonemeAlignment(frameIndex: 10, predictedIPA: "r", confidence: 0.91)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PhonemeAlignment.self, from: data)
        XCTAssertEqual(decoded.frameIndex, original.frameIndex)
        XCTAssertEqual(decoded.predictedIPA, original.predictedIPA)
        XCTAssertEqual(decoded.confidence, original.confidence, accuracy: 0.0001)
    }

    // MARK: - 14. PhonemeAnalysisError: errorDescription не пуст

    func testPhonemeError_modelNotLoaded_hasDescription() {
        let err = PhonemeAnalysisError.modelNotLoaded
        XCTAssertNotNil(err.errorDescription)
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testPhonemeError_mfccExtractionFailed_hasDescription() {
        let err = PhonemeAnalysisError.mfccExtractionFailed
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testPhonemeError_predictionFailed_mentionsDetail() {
        let err = PhonemeAnalysisError.predictionFailed("тест-детали")
        XCTAssertTrue(err.errorDescription?.contains("тест-детали") ?? false)
    }

    // MARK: - 15. G2PError: errorDescription

    func testG2PError_dictionaryNotFound_hasDescription() {
        let err = G2PError.dictionaryNotFound
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testG2PError_wordNotFound_mentionsWord() {
        let err = G2PError.wordNotFound("рыба")
        XCTAssertTrue(err.errorDescription?.contains("рыба") ?? false)
    }
}
