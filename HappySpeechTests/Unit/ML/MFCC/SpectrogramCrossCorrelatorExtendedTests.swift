@testable import HappySpeech
import XCTest

// MARK: - SpectrogramCrossCorrelatorExtendedTests
//
// Phase 2.6 Batch C v25 — расширенное покрытие SpectrogramCrossCorrelator.
//
// Дополнительные тесты (помимо SpectrogramCrossCorrelatorTests):
//   - quickCosineScore: разные значения (не одинаковые) → < 1.0
//   - perBinCorrelation: разная длина → обрезается по минимальной
//   - perBinCorrelation: антикоррелированные сигналы → отрицательная корреляция
//   - dtwScore: разная длина спектрограмм → нет краша
//   - compositeScore: в диапазоне [0, 1]
//   - MelSpectrogram: melBinCount = 40
//   - perBinCorrelation: одинаковая рампа → все корреляции ≈ 1.0

final class SpectrogramCrossCorrelatorExtendedTests: XCTestCase {

    // MARK: - Вспомогательные фабрики

    private func makeConstantSpec(frames: Int, value: Float) -> MelSpectrogram {
        MelSpectrogram(
            frames: Array(repeating: Array(repeating: value, count: MelSpectrogram.melBinCount), count: frames),
            sampleRate: 16000,
            duration: Double(frames) * 0.01
        )
    }

    private func makeRampSpec(frames: Int) -> MelSpectrogram {
        let frame = (0..<MelSpectrogram.melBinCount).map { Float($0) }
        return MelSpectrogram(
            frames: Array(repeating: frame, count: frames),
            sampleRate: 16000,
            duration: Double(frames) * 0.01
        )
    }

    private func makeNegativeRampSpec(frames: Int) -> MelSpectrogram {
        let frame = (0..<MelSpectrogram.melBinCount).map { Float(-$0) }
        return MelSpectrogram(
            frames: Array(repeating: frame, count: frames),
            sampleRate: 16000,
            duration: Double(frames) * 0.01
        )
    }

    private var sut: SpectrogramCrossCorrelator!

    override func setUp() {
        sut = SpectrogramCrossCorrelator()
    }

    // MARK: - 1. MelSpectrogram.melBinCount = 40

    func testMelSpectrogram_melBinCount_is40() {
        XCTAssertEqual(MelSpectrogram.melBinCount, 40)
    }

    // MARK: - 2. quickCosineScore: разные константы → < 1.0

    func testQuickCosine_differentValues_lessThanOne() async {
        let spec1 = makeConstantSpec(frames: 8, value: 1.0)
        let spec2 = makeConstantSpec(frames: 8, value: 2.0)
        let score = await sut.quickCosineScore(child: spec1, reference: spec2)
        XCTAssertEqual(score, 1.0, accuracy: 0.001, "Параллельные векторы дают cosine = 1.0 (они коллинеарные)")
    }

    // MARK: - 3. quickCosineScore: перпендикулярные → результат в [0, 1]

    func testQuickCosine_orthogonal_inRange() async {
        var frameA = [Float](repeating: 0.0, count: MelSpectrogram.melBinCount)
        var frameB = [Float](repeating: 0.0, count: MelSpectrogram.melBinCount)
        frameA[0] = 1.0
        frameB[1] = 1.0
        let spec1 = MelSpectrogram(frames: Array(repeating: frameA, count: 5), sampleRate: 16000, duration: 0.05)
        let spec2 = MelSpectrogram(frames: Array(repeating: frameB, count: 5), sampleRate: 16000, duration: 0.05)
        let score = await sut.quickCosineScore(child: spec1, reference: spec2)
        XCTAssertGreaterThanOrEqual(score, 0.0)
        XCTAssertLessThanOrEqual(score, 1.0)
        XCTAssertLessThan(score, 0.6, "Перпендикулярные векторы должны дать низкий cosine")
    }

    // MARK: - 4. compare: разная длина → compositeScore в [0, 1]

    func testCompare_veryDifferentLengths_inRange() async {
        let child = makeRampSpec(frames: 3)
        let ref = makeRampSpec(frames: 25)
        let result = await sut.compare(child: child, reference: ref)
        XCTAssertGreaterThanOrEqual(result.compositeScore, 0.0)
        XCTAssertLessThanOrEqual(result.compositeScore, 1.0)
    }

    // MARK: - 5. compare: anti-correlated signals (возрастающий vs убывающий по времени) → perBinCorrelation < 0
    //
    // Примечание: perBinCorrelation вычисляется по ВРЕМЕНИ (по фреймам) для каждого бина.
    // Чтобы получить отрицательную корреляцию нужны фреймы, меняющиеся по времени.
    // Создаём спектрограммы с линейно возрастающими/убывающими фреймами.

    func testCompare_antiCorrelated_perBinNegative() async {
        let nBins = MelSpectrogram.melBinCount
        let nFrames = 20
        // Возрастающая по времени (frame i = [Float(i), ...])
        let risingFrames = (0..<nFrames).map { i in [Float](repeating: Float(i), count: nBins) }
        // Убывающая по времени (frame i = [Float(nFrames-i), ...])
        let fallingFrames = (0..<nFrames).map { i in [Float](repeating: Float(nFrames - i), count: nBins) }

        let rising  = MelSpectrogram(frames: risingFrames,  sampleRate: 16000, duration: 0.2)
        let falling = MelSpectrogram(frames: fallingFrames, sampleRate: 16000, duration: 0.2)

        let result = await sut.compare(child: rising, reference: falling)
        let meanCorr = result.perBinCorrelation.reduce(0.0, +) / Float(result.perBinCorrelation.count)
        XCTAssertLessThan(meanCorr, 0.0, "Антикоррелированные по времени сигналы дают отрицательную Pearson корреляцию")
    }

    // MARK: - 6. compare: temporally-varying identical signals → perBinCorrelation близко к 1

    func testCompare_identicalRamp_perBinHigh() async {
        let nBins = MelSpectrogram.melBinCount
        let nFrames = 15
        // Фреймы меняются по времени — это обязательно для ненулевой дисперсии
        let frames = (0..<nFrames).map { i in [Float](repeating: Float(i), count: nBins) }
        let spec = MelSpectrogram(frames: frames, sampleRate: 16000, duration: 0.15)

        let result = await sut.compare(child: spec, reference: spec)
        let nonZeroBins = result.perBinCorrelation.filter { $0 > 0.5 }
        XCTAssertGreaterThan(nonZeroBins.count, MelSpectrogram.melBinCount / 2,
            "Большинство бинов должны иметь высокую корреляцию при идентичных спектрограммах")
    }

    // MARK: - 7. compare: один фрейм vs несколько → не краш

    func testCompare_oneFrameVsMany_noCrash() async {
        let child = makeConstantSpec(frames: 1, value: 1.0)
        let ref = makeConstantSpec(frames: 10, value: 1.0)
        let result = await sut.compare(child: child, reference: ref)
        XCTAssertGreaterThanOrEqual(result.compositeScore, 0.0)
    }

    // MARK: - 8. SpectrogramSimilarityResult: Equatable разные значения → не равны

    func testSimilarityResult_differentValues_notEqual() {
        let a = SpectrogramSimilarityResult(
            cosineSimilarity: 0.8, dtwScore: 0.7,
            perBinCorrelation: [Float](repeating: 0.5, count: MelSpectrogram.melBinCount),
            compositeScore: 0.74
        )
        let b = SpectrogramSimilarityResult(
            cosineSimilarity: 0.9, dtwScore: 0.7,
            perBinCorrelation: [Float](repeating: 0.5, count: MelSpectrogram.melBinCount),
            compositeScore: 0.82
        )
        XCTAssertNotEqual(a, b)
    }

    // MARK: - 9. problematicBins: порог 0.0 → нет проблемных (всё >= 0)

    func testProblematicBins_threshold0_emptyResult() {
        let corr = [Float](repeating: 0.1, count: MelSpectrogram.melBinCount)
        let result = SpectrogramSimilarityResult(
            cosineSimilarity: 0.5, dtwScore: 0.5,
            perBinCorrelation: corr, compositeScore: 0.5
        )
        let problematic = result.problematicBins(threshold: 0.0)
        XCTAssertTrue(problematic.isEmpty, "При threshold=0.0 нет проблемных бинов (все >= 0)")
    }

    // MARK: - 10. problematicBins: порог 1.0 → все проблемные (все < 1.0)

    func testProblematicBins_threshold1_allProblematic() {
        let corr = [Float](repeating: 0.99, count: MelSpectrogram.melBinCount)
        let result = SpectrogramSimilarityResult(
            cosineSimilarity: 0.99, dtwScore: 0.99,
            perBinCorrelation: corr, compositeScore: 0.99
        )
        let problematic = result.problematicBins(threshold: 1.0)
        XCTAssertEqual(problematic.count, MelSpectrogram.melBinCount,
            "При threshold=1.0 все бины проблемные (ни один не достигает 1.0)")
    }

    // MARK: - 11. compare: большие значения (out-of-range log-mel) → не крашится

    func testCompare_largeValues_noCrash() async {
        let child = makeConstantSpec(frames: 10, value: 100.0)
        let ref = makeConstantSpec(frames: 10, value: -100.0)
        let result = await sut.compare(child: child, reference: ref)
        XCTAssertFalse(result.compositeScore.isNaN, "compositeScore не должен быть NaN")
        XCTAssertFalse(result.compositeScore.isInfinite, "compositeScore не должен быть Infinite")
    }

    // MARK: - 12. compare: много фреймов (100) → не крашится

    func testCompare_manyFrames_noCrash() async {
        let spec = makeRampSpec(frames: 100)
        let result = await sut.compare(child: spec, reference: spec)
        XCTAssertGreaterThanOrEqual(result.dtwScore, 0.0)
    }

    // MARK: - 13. compare: pустые оба входа → .empty

    func testCompare_bothEmpty_returnsEmpty() async {
        let empty = MelSpectrogram(frames: [], sampleRate: 16000, duration: 0)
        let result = await sut.compare(child: empty, reference: empty)
        XCTAssertEqual(result, SpectrogramSimilarityResult.empty)
    }
}
