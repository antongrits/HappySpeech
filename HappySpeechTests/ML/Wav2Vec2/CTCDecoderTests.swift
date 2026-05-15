@testable import HappySpeech
import CoreML
import XCTest

// MARK: - CTCDecoderTests
//
// Phase 2.4 v25 — покрытие CTCDecoder и Wav2Vec2Vocabulary.
// CTCDecoder.decode() требует MLMultiArray — используем синтетические массивы.
// Тесты проверяют постпроцессинг: greedy collapse, blank-skip, buildText.

final class CTCDecoderTests: XCTestCase {

    // MARK: - Вспомогательная фабрика MLMultiArray

    /// Создаёт MLMultiArray [1, timeSteps, vocabSize] с заданными логитами.
    /// `logits` — массив размера timeSteps × vocabSize (строки — timestep, столбцы — vocab).
    private func makeLogitsArray(
        timeSteps: Int,
        vocabSize: Int,
        logits: [[Float]]
    ) throws -> MLMultiArray {
        let array = try MLMultiArray(
            shape: [1, NSNumber(value: timeSteps), NSNumber(value: vocabSize)],
            dataType: .float32
        )
        for t in 0..<timeSteps {
            for v in 0..<vocabSize {
                let idx = t * vocabSize + v
                array[idx] = NSNumber(value: logits[t][v])
            }
        }
        return array
    }

    // MARK: - Wav2Vec2Vocabulary

    func test_vocab_size_is37() {
        XCTAssertEqual(Wav2Vec2Vocabulary.size, 37)
    }

    func test_vocab_blankIndex_is0() {
        XCTAssertEqual(Wav2Vec2Vocabulary.blankIndex, 0)
    }

    func test_vocab_wordBoundaryIndex_is4() {
        XCTAssertEqual(Wav2Vec2Vocabulary.wordBoundaryIndex, 4)
    }

    func test_vocab_symbol_atValidIndex() {
        XCTAssertEqual(Wav2Vec2Vocabulary.symbol(at: 0), "<pad>")
        XCTAssertEqual(Wav2Vec2Vocabulary.symbol(at: 4), "|")
    }

    func test_vocab_symbol_atNegativeIndex_returnsNil() {
        XCTAssertNil(Wav2Vec2Vocabulary.symbol(at: -1))
    }

    func test_vocab_symbol_atOutOfBounds_returnsNil() {
        XCTAssertNil(Wav2Vec2Vocabulary.symbol(at: 37))
    }

    func test_vocab_indexOf_pad_is0() {
        XCTAssertEqual(Wav2Vec2Vocabulary.index(of: "<pad>"), 0)
    }

    func test_vocab_indexOf_boundary_is4() {
        XCTAssertEqual(Wav2Vec2Vocabulary.index(of: "|"), 4)
    }

    func test_vocab_indexOf_unknown_isNil() {
        XCTAssertNil(Wav2Vec2Vocabulary.index(of: "xyz"))
    }

    func test_vocab_a_atIndex5() {
        XCTAssertEqual(Wav2Vec2Vocabulary.symbol(at: 5), "а")
    }

    func test_vocab_ya_atIndex36() {
        XCTAssertEqual(Wav2Vec2Vocabulary.symbol(at: 36), "я")
    }

    func test_vocab_symbols_noEmptyStrings() {
        for symbol in Wav2Vec2Vocabulary.symbols {
            XCTAssertFalse(symbol.isEmpty, "Символ в словаре не должен быть пустым")
        }
    }

    // MARK: - CTCDecoder.decode: невалидная форма

    func test_decode_emptyLike_wrongShape_returnsEmpty() throws {
        // Форма [1, 1, 37]: один timestep, единственный логит — blank
        let logits: [[Float]] = [[Float]([100] + Array(repeating: 0.0, count: 36))]
        let array = try makeLogitsArray(timeSteps: 1, vocabSize: 37, logits: logits)
        let result = CTCDecoder.decode(logitsArray: array)
        // blank (индекс 0) → пустой текст и нет фонем
        XCTAssertTrue(result.phonemes.isEmpty, "Только blank → нет фонем")
        XCTAssertTrue(result.decodedText.isEmpty, "Только blank → пустой текст")
    }

    // MARK: - CTCDecoder.decode: один символ

    func test_decode_singleCyrillicChar_decodesLetter() throws {
        // «а» — индекс 5 в словаре
        let vocab = Wav2Vec2Vocabulary.symbols
        let aIdx = Wav2Vec2Vocabulary.index(of: "а") ?? 5
        var row = [Float](repeating: 0.0, count: vocab.count)
        row[aIdx] = 100.0  // argmax → «а»
        let array = try makeLogitsArray(timeSteps: 1, vocabSize: vocab.count, logits: [row])
        let result = CTCDecoder.decode(logitsArray: array)
        XCTAssertEqual(result.decodedText, "а", "Один timestep с «а» → текст «а»")
        XCTAssertFalse(result.phonemes.isEmpty)
    }

    // MARK: - CTCDecoder.decode: greedy collapse (повторы)

    func test_decode_repeatedChar_collapsedToOne() throws {
        let aIdx = Wav2Vec2Vocabulary.index(of: "а") ?? 5
        var row = [Float](repeating: 0.0, count: 37)
        row[aIdx] = 100.0
        // 3 timestep с одним и тем же символом → collapse до одного «а»
        let array = try makeLogitsArray(timeSteps: 3, vocabSize: 37, logits: [row, row, row])
        let result = CTCDecoder.decode(logitsArray: array)
        XCTAssertEqual(result.decodedText, "а", "Повторяющийся символ должен схлопнуться в один")
        XCTAssertEqual(result.phonemes.count, 1)
    }

    // MARK: - CTCDecoder.decode: два разных символа

    func test_decode_twoDifferentChars_decodesSequence() throws {
        let aIdx = Wav2Vec2Vocabulary.index(of: "а") ?? 5
        let bIdx = Wav2Vec2Vocabulary.index(of: "б") ?? 6
        var rowA = [Float](repeating: 0.0, count: 37)
        var rowB = [Float](repeating: 0.0, count: 37)
        rowA[aIdx] = 100.0
        rowB[bIdx] = 100.0
        let array = try makeLogitsArray(timeSteps: 2, vocabSize: 37, logits: [rowA, rowB])
        let result = CTCDecoder.decode(logitsArray: array)
        XCTAssertEqual(result.decodedText, "аб")
    }

    // MARK: - CTCDecoder.decode: word boundary

    func test_decode_wordBoundary_insertsSpace() throws {
        let aIdx = Wav2Vec2Vocabulary.index(of: "а") ?? 5
        let bndIdx = Wav2Vec2Vocabulary.wordBoundaryIndex  // "|" → 4
        let vIdx = Wav2Vec2Vocabulary.index(of: "в") ?? 7
        var rowA = [Float](repeating: 0.0, count: 37)
        var rowBnd = [Float](repeating: 0.0, count: 37)
        var rowV = [Float](repeating: 0.0, count: 37)
        rowA[aIdx] = 100.0
        rowBnd[bndIdx] = 100.0
        rowV[vIdx] = 100.0
        let array = try makeLogitsArray(timeSteps: 3, vocabSize: 37,
                                        logits: [rowA, rowBnd, rowV])
        let result = CTCDecoder.decode(logitsArray: array)
        XCTAssertTrue(result.decodedText.contains(" "), "Граница слова «|» должна вставлять пробел")
    }

    // MARK: - CTCDecoder.decode: averageConfidence в диапазоне [0,1]

    func test_decode_averageConfidence_inRange() throws {
        let aIdx = Wav2Vec2Vocabulary.index(of: "а") ?? 5
        var row = [Float](repeating: 0.0, count: 37)
        row[aIdx] = 2.0  // небольшой логит
        let array = try makeLogitsArray(timeSteps: 1, vocabSize: 37, logits: [row])
        let result = CTCDecoder.decode(logitsArray: array)
        XCTAssertGreaterThanOrEqual(result.averageConfidence, 0.0)
        XCTAssertLessThanOrEqual(result.averageConfidence, 1.0)
    }

    // MARK: - CTCDecodeResult: Equatable

    func test_ctcDecodeResult_equatable_same() {
        let r1 = CTCDecodeResult(phonemes: [], decodedText: "кот", averageConfidence: 0.9)
        let r2 = CTCDecodeResult(phonemes: [], decodedText: "кот", averageConfidence: 0.9)
        XCTAssertEqual(r1, r2)
    }

    func test_ctcDecodeResult_equatable_different() {
        let r1 = CTCDecodeResult(phonemes: [], decodedText: "кот", averageConfidence: 0.9)
        let r2 = CTCDecodeResult(phonemes: [], decodedText: "лес", averageConfidence: 0.9)
        XCTAssertNotEqual(r1, r2)
    }

    // MARK: - PhonemeLogit: Equatable

    func test_phonemeLogit_equatable() {
        let a = PhonemeLogit(timestep: 0, phonemeIndex: 5, confidence: 0.9)
        let b = PhonemeLogit(timestep: 0, phonemeIndex: 5, confidence: 0.9)
        XCTAssertEqual(a, b)
    }

    func test_phonemeLogit_differentTimestep_notEqual() {
        let a = PhonemeLogit(timestep: 0, phonemeIndex: 5, confidence: 0.9)
        let b = PhonemeLogit(timestep: 1, phonemeIndex: 5, confidence: 0.9)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Wav2Vec2Error: локализованные описания

    func test_wav2vec2Error_modelNotLoaded_hasDescription() {
        let error = Wav2Vec2Error.modelNotLoaded
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func test_wav2vec2Error_audioTooShort_hasDescription() {
        let error = Wav2Vec2Error.audioTooShort(4000)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    func test_wav2vec2Error_audioConversionFailed_hasDescription() {
        let error = Wav2Vec2Error.audioConversionFailed
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    func test_wav2vec2Error_predictionFailed_mentionsDetail() {
        let error = Wav2Vec2Error.predictionFailed("тест-ошибка")
        XCTAssertTrue(error.errorDescription?.contains("тест-ошибка") ?? false)
    }
}
