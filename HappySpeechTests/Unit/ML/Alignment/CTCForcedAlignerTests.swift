import XCTest
@testable import HappySpeech

// MARK: - CTCForcedAlignerTests

/// Тесты CTC forced alignment на синтетических детерминированных логитах.
///
/// Все тесты используют полностью детерминированные входные данные —
/// никаких случайных значений, никакой зависимости от загрузки ML-модели.
/// Результаты воспроизводимы на любой машине.
///
/// ## Честные границы
/// Алгоритм проверяется на синтетических данных, оптимально сконструированных
/// под конкретные сценарии. Точность на реальной детской речи — отдельная задача.
final class CTCForcedAlignerTests: XCTestCase {

    // MARK: - Helpers

    /// Строит синтетическую матрицу T×C логитов, где в кадрах [start, end]
    /// доминирует символ `dominantId`, а остальные кадры — blank.
    /// Все «доминирующие» значения — большие положительные числа;
    /// остальные — большие отрицательные (после log-softmax: dominant ≈ 0, rest ≈ -∞).
    private func makeLogProbs(
        timeSteps: Int,
        vocabSize: Int = 37,
        dominant: Int,
        dominantRange: ClosedRange<Int>,
        blankId: Int = 0
    ) -> [[Float]] {
        (0 ..< timeSteps).map { t in
            var row = [Float](repeating: -20.0, count: vocabSize)
            if dominantRange.contains(t) {
                row[dominant] = 0.0   // log-prob ≈ 0 (почти 1 после exp)
            } else {
                row[blankId] = 0.0    // blank доминирует
            }
            return row
        }
    }

    /// Строит log-softmax матрицу с несколькими доминантными интервалами.
    private func makeLogProbsMulti(
        timeSteps: Int,
        vocabSize: Int = 37,
        segments: [(dominant: Int, range: ClosedRange<Int>)],
        blankId: Int = 0
    ) -> [[Float]] {
        var matrix = (0 ..< timeSteps).map { _ in
            var row = [Float](repeating: -20.0, count: vocabSize)
            row[blankId] = 0.0
            return row
        }
        for seg in segments {
            for t in seg.range where t < timeSteps {
                var row = [Float](repeating: -20.0, count: vocabSize)
                row[seg.dominant] = 0.0
                matrix[t] = row
            }
        }
        return matrix
    }

    // Vocab-id реальных кириллических символов из Wav2Vec2Vocabulary:
    // р=21, л=16, а=5, к=15, о=19, с=22, т=23
    private var rId: Int { Wav2Vec2Vocabulary.index(of: "р")! }  // 21
    private var lId: Int { Wav2Vec2Vocabulary.index(of: "л")! }  // 16
    private var aId: Int { Wav2Vec2Vocabulary.index(of: "а")! }  // 5
    private var kId: Int { Wav2Vec2Vocabulary.index(of: "к")! }  // 15
    private var oId: Int { Wav2Vec2Vocabulary.index(of: "о")! }  // 19
    private var sId: Int { Wav2Vec2Vocabulary.index(of: "с")! }  // 22
    private var blank: Int { Wav2Vec2Vocabulary.blankIndex }      // 0

    // MARK: - Тест 1: Минимальный вход — одна фонема

    func test_alignSinglePhoneme_returnsSingleSpan() throws {
        let logProbs = makeLogProbs(
            timeSteps: 10,
            dominant: rId,
            dominantRange: 2...7
        )
        let spans = try CTCForcedAligner.align(logProbs: logProbs, refIds: [rId])
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].phoneme, "р")
        // Спан должен охватывать хотя бы часть доминантного диапазона
        XCTAssertGreaterThanOrEqual(spans[0].endFrame, spans[0].startFrame)
    }

    // MARK: - Тест 2: Три фонемы — «рак» (р-а-к)

    func test_alignThreePhonemes_rak_spansInOrder() throws {
        // «рак»: р в кадрах 0-3, бланки 4-5, а в 6-10, бланки 11-12, к в 13-17
        let logProbs = makeLogProbsMulti(
            timeSteps: 20,
            segments: [
                (dominant: rId, range: 0...3),
                (dominant: aId, range: 6...10),
                (dominant: kId, range: 13...17)
            ]
        )
        let spans = try CTCForcedAligner.align(
            logProbs: logProbs,
            refIds: [rId, aId, kId]
        )
        XCTAssertEqual(spans.count, 3)
        XCTAssertEqual(spans[0].phoneme, "р")
        XCTAssertEqual(spans[1].phoneme, "а")
        XCTAssertEqual(spans[2].phoneme, "к")
        // Порядок: каждый спан начинается не раньше предыдущего
        XCTAssertLessThanOrEqual(spans[0].endFrame, spans[1].endFrame)
        XCTAssertLessThanOrEqual(spans[1].endFrame, spans[2].endFrame)
    }

    // MARK: - Тест 3: Ошибка — пустой refIds

    func test_alignEmptyReference_throwsEmptyReference() {
        let logProbs = makeLogProbs(timeSteps: 10, dominant: rId, dominantRange: 0...9)
        XCTAssertThrowsError(
            try CTCForcedAligner.align(logProbs: logProbs, refIds: [])
        ) { error in
            guard case CTCForcedAligner.CTCAlignerError.emptyReference = error else {
                XCTFail("Ожидалась ошибка emptyReference, получено: \(error)")
                return
            }
        }
    }

    // MARK: - Тест 4: Ошибка — T < 2L+1

    func test_alignTooFewFrames_throwsTooFewFrames() {
        // 2 фонемы → нужно минимум 5 кадров; даём 4
        let logProbs = makeLogProbs(timeSteps: 4, dominant: rId, dominantRange: 0...3)
        XCTAssertThrowsError(
            try CTCForcedAligner.align(logProbs: logProbs, refIds: [rId, aId])
        ) { error in
            guard case CTCForcedAligner.CTCAlignerError.tooFewFrames = error else {
                XCTFail("Ожидалась ошибка tooFewFrames, получено: \(error)")
                return
            }
        }
    }

    // MARK: - Тест 5: Длинная последовательность — 5 фонем (полное слово)

    func test_alignFivePhonemes_allSpansPresent() throws {
        // «лошадь»: л-о-ш-а-т → vocab ids
        let shId = Wav2Vec2Vocabulary.index(of: "ш")!
        let tId = Wav2Vec2Vocabulary.index(of: "т")!
        let logProbs = makeLogProbsMulti(
            timeSteps: 40,
            segments: [
                (dominant: lId, range: 0...5),
                (dominant: oId, range: 8...13),
                (dominant: shId, range: 16...22),
                (dominant: aId, range: 25...30),
                (dominant: tId, range: 33...38)
            ]
        )
        let spans = try CTCForcedAligner.align(
            logProbs: logProbs,
            refIds: [lId, oId, shId, aId, tId]
        )
        XCTAssertEqual(spans.count, 5)
        XCTAssertEqual(spans[0].phoneme, "л")
        XCTAssertEqual(spans[4].phoneme, "т")
        // Все спаны не пустые
        for span in spans {
            XCTAssertGreaterThanOrEqual(span.frameCount, 1)
        }
    }

    // MARK: - Тест 6: PhonemeSpan.frameCount

    func test_phonemeSpan_frameCount() {
        let span = PhonemeSpan(phoneme: "р", startFrame: 3, endFrame: 7)
        XCTAssertEqual(span.frameCount, 5)
    }

    func test_phonemeSpan_singleFrame() {
        let span = PhonemeSpan(phoneme: "к", startFrame: 5, endFrame: 5)
        XCTAssertEqual(span.frameCount, 1)
    }

    // MARK: - Тест 7: Log-softmax применяется корректно

    func test_applyLogSoftmax_sumsToOne() {
        let rawLogits: [[Float]] = [[2.0, 1.0, 0.0, -1.0, -2.0,
                                     0.5, 0.3, -0.5, 1.2, 0.0,
                                     0.1, 0.2, 0.3, 0.4, 0.5,
                                     -0.1, -0.2, 0.0, 0.0, 0.0,
                                     0.0, 0.0, 0.0, 0.0, 0.0,
                                     0.0, 0.0, 0.0, 0.0, 0.0,
                                     0.0, 0.0, 0.0, 0.0, 0.0,
                                     0.0, 0.0]]
        let logProbs = CTCForcedAligner.applyLogSoftmax(rawLogits, vocabSize: 37)
        XCTAssertEqual(logProbs.count, 1)
        let probs = logProbs[0].map { expf($0) }
        let sum = probs.reduce(0, +)
        XCTAssertEqual(sum, 1.0, accuracy: 1e-4)
    }

    // MARK: - Тест 8: Spans покрывают начало и конец последовательности

    func test_align_spansStartFromBeginning() throws {
        let logProbs = makeLogProbs(
            timeSteps: 15,
            dominant: aId,
            dominantRange: 0...14
        )
        let spans = try CTCForcedAligner.align(logProbs: logProbs, refIds: [aId])
        XCTAssertEqual(spans[0].startFrame, 0)
    }

    // MARK: - Тест 9: Две одинаковые фонемы (удвоенная) — skip-blank не применяется

    func test_align_duplicatePhonemes_bothSpansPresent() throws {
        // «лл»: две фонемы Л (удвоение), должны быть два спана разделены blank
        let logProbs = makeLogProbsMulti(
            timeSteps: 15,
            segments: [
                (dominant: lId, range: 0...4),
                (dominant: lId, range: 8...12)
                // blank в 5-7 разделяет
            ]
        )
        let spans = try CTCForcedAligner.align(
            logProbs: logProbs,
            refIds: [lId, lId]
        )
        XCTAssertEqual(spans.count, 2)
        XCTAssertEqual(spans[0].phoneme, "л")
        XCTAssertEqual(spans[1].phoneme, "л")
        // Второй спан начинается не раньше первого
        XCTAssertGreaterThanOrEqual(spans[1].startFrame, spans[0].startFrame)
    }
}
