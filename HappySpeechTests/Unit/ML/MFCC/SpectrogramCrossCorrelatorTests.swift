@testable import HappySpeech
import XCTest

// MARK: - SpectrogramCrossCorrelatorTests
//
// Phase 2.6c v25 — покрытие SpectrogramCrossCorrelator.
//
// Тестируется чистая вычислительная логика:
//   - cosineSimilarity идентичных спектрограмм
//   - DTW score: идентичная vs. нулевая vs. разная длина
//   - perBinCorrelation: идеальная корреляция, антикорреляция
//   - compare: пустые входы → .empty
//   - problematicBins: корректная фильтрация по порогу
//   - quickCosineScore: быстрый путь без DTW
//   - compositeScore: формула 0.4·cosine + 0.6·dtw

final class SpectrogramCrossCorrelatorTests: XCTestCase {

    // MARK: - Вспомогательные фабрики

    /// Синтетическая спектрограмма: `frames` фреймов × `bins` бинов, все значения = `value`.
    private func makeFlatSpec(frames: Int, bins: Int = MelSpectrogram.melBinCount, value: Float = 1.0) -> MelSpectrogram {
        MelSpectrogram(
            frames: Array(repeating: Array(repeating: value, count: bins), count: frames),
            sampleRate: 16000,
            duration: Double(frames) * 0.01
        )
    }

    /// Синтетическая спектрограмма: `frames` фреймов × `bins` бинов.
    ///
    /// Значение каждой ячейки = `bin + frame`, то есть варьируется И по бинам,
    /// И по времени. Ненулевая дисперсия по времени обязательна для корректной
    /// per-bin корреляции Пирсона (для константного по времени бина Pearson
    /// не определён → `0`).
    private func makeRampSpec(frames: Int, bins: Int = MelSpectrogram.melBinCount) -> MelSpectrogram {
        let frameRows = (0..<frames).map { frameIndex in
            (0..<bins).map { Float($0 + frameIndex) }
        }
        return MelSpectrogram(
            frames: frameRows,
            sampleRate: 16000,
            duration: Double(frames) * 0.01
        )
    }

    private var sut: SpectrogramCrossCorrelator!

    override func setUp() {
        sut = SpectrogramCrossCorrelator()
    }

    // MARK: - 1. Пустые входы → .empty

    func testCompare_emptyChild_returnsEmpty() async {
        let empty = MelSpectrogram(frames: [], sampleRate: 16000, duration: 0)
        let ref = makeFlatSpec(frames: 10)
        let result = await sut.compare(child: empty, reference: ref)
        XCTAssertEqual(result.cosineSimilarity, SpectrogramSimilarityResult.empty.cosineSimilarity)
        XCTAssertEqual(result.dtwScore, SpectrogramSimilarityResult.empty.dtwScore)
        XCTAssertEqual(result.compositeScore, SpectrogramSimilarityResult.empty.compositeScore)
    }

    func testCompare_emptyReference_returnsEmpty() async {
        let child = makeFlatSpec(frames: 10)
        let empty = MelSpectrogram(frames: [], sampleRate: 16000, duration: 0)
        let result = await sut.compare(child: child, reference: empty)
        XCTAssertEqual(result.compositeScore, 0.0)
    }

    // MARK: - 2. Cosine similarity: идентичные спектрограммы

    func testCompare_identicalSpecs_cosine1() async {
        let spec = makeFlatSpec(frames: 8, value: 2.0)
        let result = await sut.compare(child: spec, reference: spec)
        // cosine(a, a) = 1.0 → масштабированный в [0,1] = 1.0
        XCTAssertEqual(result.cosineSimilarity, 1.0, accuracy: 0.001)
    }

    // MARK: - 3. Cosine similarity: нулевые векторы (denom → 0)

    func testCompare_zeroVectors_cosineZero() async {
        let zero = makeFlatSpec(frames: 5, value: 0.0)
        let result = await sut.compare(child: zero, reference: zero)
        // denom = 0 → guarded return 0
        XCTAssertEqual(result.cosineSimilarity, 0.0, accuracy: 0.001)
    }

    // MARK: - 4. DTW score: идентичные фреймы → высокая оценка

    func testCompare_identicalSpecs_dtwHigh() async {
        let spec = makeRampSpec(frames: 10)
        let result = await sut.compare(child: spec, reference: spec)
        // DTW distance = 0 → score = 1/(1+0/8) = 1.0
        XCTAssertGreaterThan(result.dtwScore, 0.9)
    }

    // MARK: - 5. DTW score: очень разные спектрограммы → низкая оценка

    func testCompare_oppositeSpecs_dtwLow() async {
        let low = makeFlatSpec(frames: 10, value: -10.0)
        let high = makeFlatSpec(frames: 10, value: 10.0)
        let result = await sut.compare(child: low, reference: high)
        // Большой Euclidean distance → score < 0.5
        XCTAssertLessThan(result.dtwScore, 0.5)
    }

    // MARK: - 6. Composite score: формула 0.4·cosine + 0.6·DTW

    func testCompare_compositeFormula_correct() async {
        let spec = makeFlatSpec(frames: 10, value: 1.5)
        let result = await sut.compare(child: spec, reference: spec)
        let expected = 0.4 * result.cosineSimilarity + 0.6 * result.dtwScore
        XCTAssertEqual(result.compositeScore, expected, accuracy: 0.001)
    }

    // MARK: - 7. Per-bin correlation: идентичные → ~1.0

    func testCompare_identicalRamp_perBinNearOne() async {
        let spec = makeRampSpec(frames: 20)
        let result = await sut.compare(child: spec, reference: spec)
        // Pearson(a, a) = 1.0 для всех бинов с ненулевой дисперсией
        let meanCorr = result.perBinCorrelation.reduce(0.0, +) / Float(result.perBinCorrelation.count)
        XCTAssertGreaterThan(meanCorr, 0.9)
    }

    // MARK: - 8. Per-bin correlation: длина 1 → нет дисперсии → zeros

    func testCompare_singleFrame_perBinAllZero() async {
        let spec = makeFlatSpec(frames: 1, value: 1.0)
        let result = await sut.compare(child: spec, reference: spec)
        for corr in result.perBinCorrelation {
            XCTAssertEqual(corr, 0.0, accuracy: 0.001)
        }
    }

    // MARK: - 9. perBinCorrelation длина = melBinCount

    func testCompare_perBinLength_equalsMelBinCount() async {
        let spec = makeFlatSpec(frames: 5)
        let result = await sut.compare(child: spec, reference: spec)
        XCTAssertEqual(result.perBinCorrelation.count, MelSpectrogram.melBinCount)
    }

    // MARK: - 10. quickCosineScore: пустые входы → 0

    func testQuickCosine_emptyInputs_returnsZero() async {
        let empty = MelSpectrogram(frames: [], sampleRate: 16000, duration: 0)
        let ref = makeFlatSpec(frames: 5)
        let score = await sut.quickCosineScore(child: empty, reference: ref)
        XCTAssertEqual(score, 0.0)
    }

    // MARK: - 11. quickCosineScore: идентичные → 1.0

    func testQuickCosine_identical_returnsOne() async {
        let spec = makeFlatSpec(frames: 6, value: 0.5)
        let score = await sut.quickCosineScore(child: spec, reference: spec)
        XCTAssertEqual(score, 1.0, accuracy: 0.001)
    }

    // MARK: - 12. problematicBins: все корреляции ниже порога

    func testProblematicBins_allLow_returnsAll() {
        let corr = [Float](repeating: 0.3, count: MelSpectrogram.melBinCount)
        let result = SpectrogramSimilarityResult(
            cosineSimilarity: 0.5,
            dtwScore: 0.5,
            perBinCorrelation: corr,
            compositeScore: 0.5
        )
        let problematic = result.problematicBins(threshold: 0.5)
        XCTAssertEqual(problematic.count, MelSpectrogram.melBinCount)
    }

    // MARK: - 13. problematicBins: все корреляции выше порога → empty

    func testProblematicBins_allHigh_returnsEmpty() {
        let corr = [Float](repeating: 0.9, count: MelSpectrogram.melBinCount)
        let result = SpectrogramSimilarityResult(
            cosineSimilarity: 0.9,
            dtwScore: 0.9,
            perBinCorrelation: corr,
            compositeScore: 0.9
        )
        let problematic = result.problematicBins(threshold: 0.5)
        XCTAssertTrue(problematic.isEmpty)
    }

    // MARK: - 14. problematicBins: смешанный случай, порог 0.5

    func testProblematicBins_mixed_selectsLow() {
        var corr = [Float](repeating: 0.8, count: MelSpectrogram.melBinCount)
        corr[0] = 0.2
        corr[5] = 0.4
        let result = SpectrogramSimilarityResult(
            cosineSimilarity: 0.7,
            dtwScore: 0.7,
            perBinCorrelation: corr,
            compositeScore: 0.7
        )
        let problematic = result.problematicBins(threshold: 0.5)
        XCTAssertTrue(problematic.contains(0))
        XCTAssertTrue(problematic.contains(5))
        XCTAssertEqual(problematic.count, 2)
    }

    // MARK: - 15. SpectrogramSimilarityResult.empty

    func testSimilarityResult_emptyStatic() {
        let e = SpectrogramSimilarityResult.empty
        XCTAssertEqual(e.cosineSimilarity, 0.0)
        XCTAssertEqual(e.dtwScore, 0.0)
        XCTAssertEqual(e.compositeScore, 0.0)
        XCTAssertEqual(e.perBinCorrelation.count, MelSpectrogram.melBinCount)
    }

    // MARK: - 16. SpectrogramSimilarityResult: Equatable

    func testSimilarityResult_equatable_sameValues() {
        let a = SpectrogramSimilarityResult(cosineSimilarity: 0.8, dtwScore: 0.7,
                                            perBinCorrelation: [Float](repeating: 0.5, count: MelSpectrogram.melBinCount),
                                            compositeScore: 0.74)
        let b = SpectrogramSimilarityResult(cosineSimilarity: 0.8, dtwScore: 0.7,
                                            perBinCorrelation: [Float](repeating: 0.5, count: MelSpectrogram.melBinCount),
                                            compositeScore: 0.74)
        XCTAssertEqual(a, b)
    }

    // MARK: - 17. Разная длина спектрограмм — не краш

    func testCompare_differentLengths_noCrash() async {
        let child = makeFlatSpec(frames: 5, value: 1.0)
        let ref = makeFlatSpec(frames: 15, value: 1.0)
        let result = await sut.compare(child: child, reference: ref)
        XCTAssertGreaterThanOrEqual(result.compositeScore, 0.0)
        XCTAssertLessThanOrEqual(result.compositeScore, 1.0)
    }
}
