@testable import HappySpeech
import CoreML
import XCTest

// MARK: - Wav2Vec2ServiceTests
// ============================================================================
// 5 unit-тестов для Wav2Vec2Service (Plan v13 Block E).
//
// Все тесты используют Mock или прямые структуры — CoreML модель НЕ загружается
// в unit-тестах (302 MB, требует реального bundle, медленно).
//
// Покрытие:
//   1. testMockTranscribeReturnsCTCResult — Wav2Vec2ServiceMock корректно транскрибирует
//   2. testMockThrowsWhenConfigured       — shouldThrow=true бросает Wav2Vec2Error
//   3. testCTCDecoderSilence             — нулевой логит декодируется без краша
//   4. testWav2Vec2VocabularySize        — словарь содержит 37 символов
//   5. testPhonemeLogitCodable           — PhonemeLogit Codable round-trip
// ============================================================================

final class Wav2Vec2ServiceTests: XCTestCase {

    // MARK: - 1. testMockTranscribeReturnsCTCResult

    /// ``Wav2Vec2ServiceMock`` возвращает CTCDecodeResult с ожидаемым текстом и confidence.
    func testMockTranscribeReturnsCTCResult() async throws {
        let mock = Wav2Vec2ServiceMock(text: "кот", confidence: 0.82)

        // Создаём минимальный PCM Data (1 сэмпл Float32 = 4 байта)
        let dummyAudio = Data(repeating: 0, count: 48_000 * 4)
        let result = try await mock.transcribe(audio: dummyAudio)

        XCTAssertEqual(result.decodedText, "кот")
        XCTAssertEqual(result.averageConfidence, 0.82, accuracy: 0.001)
        XCTAssertFalse(result.phonemes.isEmpty, "Должны быть фонемы в результате")
    }

    // MARK: - 2. testMockThrowsWhenConfigured

    /// ``Wav2Vec2ServiceMock`` с `shouldThrow=true` бросает ``Wav2Vec2Error/modelNotLoaded``.
    func testMockThrowsWhenConfigured() async {
        let mock = Wav2Vec2ServiceMock(shouldThrow: true)
        let dummyAudio = Data(repeating: 0, count: 48_000 * 4)

        do {
            _ = try await mock.transcribe(audio: dummyAudio)
            XCTFail("Ожидалась ошибка Wav2Vec2Error.modelNotLoaded")
        } catch Wav2Vec2Error.modelNotLoaded {
            // Ожидаемый результат
        } catch {
            XCTFail("Неожиданная ошибка: \(error)")
        }
    }

    // MARK: - 3. testCTCDecoderSilence

    /// ``CTCDecoder`` корректно обрабатывает входной массив с доминирующим blank-токеном (тишина).
    func testCTCDecoderSilence() throws {
        // Создаём логит-массив (shape [1, 10, 37]) где blank token (index 0) явно доминирует.
        // Все нули → softmax равномерный → argmax непредсказуем.
        // Задаём blank = +100, все остальные = -100 → CTC greedy уберёт все blank.
        let timeSteps = 10
        let vocabSize = Wav2Vec2Vocabulary.size
        let shape: [NSNumber] = [1, NSNumber(value: timeSteps), NSNumber(value: vocabSize)]

        guard let array = try? MLMultiArray(shape: shape, dataType: .float32) else {
            XCTFail("Не удалось создать MLMultiArray")
            return
        }

        // Blank token (index 0) получает logit +100, все остальные -100
        for t in 0..<timeSteps {
            for v in 0..<vocabSize {
                let index = [0, t, v] as [NSNumber]
                array[index] = v == Wav2Vec2Vocabulary.blankIndex ? 100.0 : -100.0
            }
        }

        let result = CTCDecoder.decode(logitsArray: array)

        // Доминирующий blank → всё коллапсирует в пустую строку
        XCTAssertEqual(result.decodedText, "", "Доминирующий blank должен декодироваться в пустую строку")
        XCTAssertTrue(result.phonemes.isEmpty, "При всех blank фонем быть не должно")
    }

    // MARK: - 4. testWav2Vec2VocabularySize

    /// ``Wav2Vec2Vocabulary`` содержит ровно 37 символов (bond005/wav2vec2-large-ru-golos vocab).
    func testWav2Vec2VocabularySize() {
        XCTAssertEqual(
            Wav2Vec2Vocabulary.size,
            37,
            "Словарь Wav2Vec2RuChild должен содержать 37 символов"
        )
        XCTAssertEqual(
            Wav2Vec2Vocabulary.blankIndex,
            0,
            "Blank token должен быть на индексе 0 (<pad>)"
        )
        XCTAssertEqual(
            Wav2Vec2Vocabulary.symbol(at: 0),
            "<pad>",
            "Индекс 0 должен быть <pad> (blank)"
        )
        XCTAssertNotNil(
            Wav2Vec2Vocabulary.index(of: "а"),
            "Символ 'а' должен быть в словаре"
        )
    }

    // MARK: - 5. testPhonemeLogitCodable

    /// ``PhonemeLogit`` поддерживает Codable round-trip (для сериализации результатов).
    func testPhonemeLogitCodable() throws {
        let original = PhonemeLogit(timestep: 42, phonemeIndex: 15, confidence: 0.91)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PhonemeLogit.self, from: data)

        XCTAssertEqual(decoded.timestep, original.timestep)
        XCTAssertEqual(decoded.phonemeIndex, original.phonemeIndex)
        XCTAssertEqual(decoded.confidence, original.confidence, accuracy: 0.0001)
    }
}
