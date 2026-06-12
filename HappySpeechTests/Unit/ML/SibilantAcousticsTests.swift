import XCTest
@testable import HappySpeech

/// Тесты DSP-ядра «Акустического зеркала»: анализатор спектральных моментов
/// и детерминированный классификатор континуума «С ↔ Ш».
/// Все сигналы синтетические и детерминированные (seeded LCG) — без файлов и I/O.
final class SibilantAcousticsTests: XCTestCase {

    private let sampleRate = SibilantAcousticsAnalyzer.expectedSampleRate

    // MARK: - Синтез сигналов

    /// Детерминированный линейный конгруэнтный генератор — воспроизводимый «шум».
    private struct SeededGenerator {
        private var state: UInt64
        init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
        mutating func nextFloat() -> Float {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Float(Double(state >> 33) / Double(UInt32.max)) * 2 - 1
        }
    }

    /// Узкополосный шум вокруг центральной частоты: сумма синусоид с
    /// детерминированными случайными фазами в полосе ±bandwidth/2.
    private func narrowbandNoise(
        centerHz: Double,
        bandwidthHz: Double,
        duration: Double,
        amplitude: Float = 0.4,
        seed: UInt64 = 7
    ) -> [Float] {
        let count = Int(duration * sampleRate)
        var gen = SeededGenerator(seed: seed)
        var partials: [(freq: Double, phase: Double)] = []
        let partialCount = 24
        for idx in 0 ..< partialCount {
            let offset = (Double(idx) / Double(partialCount - 1) - 0.5) * bandwidthHz
            partials.append((centerHz + offset, Double(gen.nextFloat()) * .pi))
        }
        var signal = [Float](repeating: 0, count: count)
        for sampleIdx in 0 ..< count {
            let time = Double(sampleIdx) / sampleRate
            var value = 0.0
            for partial in partials {
                value += sin(2 * .pi * partial.freq * time + partial.phase)
            }
            signal[sampleIdx] = Float(value / Double(partials.count)) * amplitude
        }
        return signal
    }

    /// Тишина (нулевой сигнал).
    private func silence(duration: Double) -> [Float] {
        [Float](repeating: 0, count: Int(duration * sampleRate))
    }

    /// Низкочастотный «гласный» (гармоники 200/400/600 Гц) — НЕ фрикативный.
    private func vowelLike(duration: Double, amplitude: Float = 0.4) -> [Float] {
        let count = Int(duration * sampleRate)
        var signal = [Float](repeating: 0, count: count)
        for idx in 0 ..< count {
            let time = Double(idx) / sampleRate
            let value = sin(2 * .pi * 200 * time) + 0.6 * sin(2 * .pi * 400 * time)
                + 0.4 * sin(2 * .pi * 600 * time)
            signal[idx] = Float(value / 2.0) * amplitude
        }
        return signal
    }

    // MARK: - Analyzer

    func testSilenceYieldsNoMeasurement() {
        let measurement = SibilantAcousticsAnalyzer.analyze(pcm: silence(duration: 1.0))
        XCTAssertNil(measurement, "Тишина не должна давать измерение")
    }

    func testTooShortInputYieldsNil() {
        let short = [Float](repeating: 0.1, count: SibilantAcousticsAnalyzer.frameSize - 1)
        XCTAssertNil(SibilantAcousticsAnalyzer.analyze(pcm: short))
    }

    func testVowelLikeSignalIsNotFricative() {
        // Чистый низкочастотный гласный: ZCR низкий, сибилянтная полоса пустая.
        let measurement = SibilantAcousticsAnalyzer.analyze(pcm: vowelLike(duration: 1.0))
        XCTAssertNil(measurement, "Гласный без шума не должен детектироваться как сибилянт")
    }

    func testHighNoiseMeasuredAsWhistlingRange() throws {
        // «С»: узкополосный шум вокруг 7 кГц, с тишиной по краям.
        let pcm = silence(duration: 0.2)
            + narrowbandNoise(centerHz: 7_000, bandwidthHz: 1_600, duration: 0.8)
            + silence(duration: 0.2)
        let measurement = SibilantAcousticsAnalyzer.analyze(pcm: pcm)
        let unwrapped = try XCTUnwrap(measurement)
        XCTAssertGreaterThan(unwrapped.centroidHz, 5_800)
        XCTAssertLessThan(unwrapped.centroidHz, 8_000)
        XCTAssertGreaterThan(unwrapped.fricationDuration, 0.4)
    }

    func testLowNoiseMeasuredAsHissingRange() throws {
        // «Ш»: шум вокруг 3.6 кГц.
        let pcm = silence(duration: 0.2)
            + narrowbandNoise(centerHz: 3_600, bandwidthHz: 1_400, duration: 0.8)
            + silence(duration: 0.2)
        let measurement = SibilantAcousticsAnalyzer.analyze(pcm: pcm)
        let unwrapped = try XCTUnwrap(measurement)
        XCTAssertGreaterThan(unwrapped.centroidHz, 2_600)
        XCTAssertLessThan(unwrapped.centroidHz, 4_800)
    }

    func testLongestSegmentWins() throws {
        // Короткий высокий шум + длинный низкий: должен победить длинный (Ш-зона).
        let pcm = narrowbandNoise(centerHz: 7_000, bandwidthHz: 1_200, duration: 0.12, seed: 3)
            + silence(duration: 0.3)
            + narrowbandNoise(centerHz: 3_600, bandwidthHz: 1_200, duration: 0.9, seed: 11)
        let measurement = SibilantAcousticsAnalyzer.analyze(pcm: pcm)
        let unwrapped = try XCTUnwrap(measurement)
        XCTAssertLessThan(unwrapped.centroidHz, 5_000, "Длинный сегмент (Ш) должен определять измерение")
    }

    func testLongestTrueRunHelper() {
        XCTAssertNil(SibilantAcousticsAnalyzer.longestTrueRun([false, false]))
        XCTAssertEqual(SibilantAcousticsAnalyzer.longestTrueRun([true, true, false, true]), 0 ..< 2)
        XCTAssertEqual(
            SibilantAcousticsAnalyzer.longestTrueRun([false, true, true, true]),
            1 ..< 4,
            "Хвостовой run должен учитываться"
        )
    }

    func testSpectralMomentsOfSinglePeak() throws {
        // Дельта-подобный спектр: вся энергия в одном бине → центроид = частота бина, разброс ≈ 0.
        var spectrum = [Double](repeating: 0, count: 256)
        spectrum[100] = 5.0
        let hzPerBin = sampleRate / Double(SibilantAcousticsAnalyzer.frameSize)
        let moments = SibilantAcousticsAnalyzer.spectralMoments(
            spectrum: spectrum,
            hzPerBin: hzPerBin,
            band: 1_000 ... 8_000
        )
        let unwrapped = try XCTUnwrap(moments)
        XCTAssertEqual(unwrapped.centroid, 100 * hzPerBin, accuracy: 0.5)
        XCTAssertEqual(unwrapped.spread, 0, accuracy: 0.5)
    }

    // MARK: - Classifier: continuum

    func testContinuumPositionAtAnchors() {
        XCTAssertEqual(
            SibilantContinuumClassifier.continuumPosition(
                centroidHz: SibilantContinuumClassifier.hissingAnchorHz
            ),
            0, accuracy: 0.001
        )
        XCTAssertEqual(
            SibilantContinuumClassifier.continuumPosition(
                centroidHz: SibilantContinuumClassifier.whistlingAnchorHz
            ),
            1, accuracy: 0.001
        )
    }

    func testContinuumPositionMonotonicAndClamped() {
        let low = SibilantContinuumClassifier.continuumPosition(centroidHz: 2_000)
        let mid = SibilantContinuumClassifier.continuumPosition(centroidHz: 5_200)
        let high = SibilantContinuumClassifier.continuumPosition(centroidHz: 9_500)
        XCTAssertEqual(low, 0, "Ниже якоря Ш — кламп в 0")
        XCTAssertEqual(high, 1, "Выше якоря С — кламп в 1")
        XCTAssertGreaterThan(mid, 0)
        XCTAssertLessThan(mid, 1)
    }

    // MARK: - Classifier: verdicts

    private func measurement(
        centroid: Double,
        spread: Double = 1_200,
        rms: Double = 0.2,
        duration: Double = 0.8
    ) -> SibilantMeasurement {
        SibilantMeasurement(
            centroidHz: centroid,
            spreadHz: spread,
            highBandShare: 0.5,
            fricationDuration: duration,
            peakRMS: rms,
            frameCount: Int(duration / 0.016)
        )
    }

    func testOnTargetWhistling() {
        let evaluation = SibilantContinuumClassifier.evaluate(
            measurement: measurement(centroid: 6_900),
            targetPole: .whistling
        )
        XCTAssertEqual(evaluation.verdict, .onTarget)
        XCTAssertEqual(evaluation.stars, 3)
        XCTAssertTrue(evaluation.flags.isEmpty)
    }

    func testOppositePoleSubstitution() {
        // Ребёнок целился в С, а звук на Ш-полюсе — классическая замена.
        let evaluation = SibilantContinuumClassifier.evaluate(
            measurement: measurement(centroid: 3_900),
            targetPole: .whistling
        )
        XCTAssertEqual(evaluation.verdict, .oppositePole)
        XCTAssertEqual(evaluation.stars, 1)
    }

    func testHissingTargetMirrorsLogic() {
        let onTarget = SibilantContinuumClassifier.evaluate(
            measurement: measurement(centroid: 3_900),
            targetPole: .hissing
        )
        XCTAssertEqual(onTarget.verdict, .onTarget)

        let opposite = SibilantContinuumClassifier.evaluate(
            measurement: measurement(centroid: 7_000),
            targetPole: .hissing
        )
        XCTAssertEqual(opposite.verdict, .oppositePole)
    }

    func testNoFricationGivesZeroStars() {
        let evaluation = SibilantContinuumClassifier.evaluate(measurement: nil, targetPole: .whistling)
        XCTAssertEqual(evaluation.verdict, .noFrication)
        XCTAssertEqual(evaluation.stars, 0)
        XCTAssertNil(evaluation.measurement)
    }

    func testDiffuseSpectrumCapsStarsAtTwo() {
        let evaluation = SibilantContinuumClassifier.evaluate(
            measurement: measurement(centroid: 6_900, spread: 2_900),
            targetPole: .whistling
        )
        XCTAssertEqual(evaluation.verdict, .onTarget)
        XCTAssertTrue(evaluation.flags.contains(.diffuseSpectrum))
        XCTAssertEqual(evaluation.stars, 2, "Диффузный спектр снижает 3★ → 2★")
    }

    func testQualityFlags() {
        let evaluation = SibilantContinuumClassifier.evaluate(
            measurement: measurement(centroid: 6_900, rms: 0.01, duration: 0.2),
            targetPole: .whistling
        )
        XCTAssertTrue(evaluation.flags.contains(.weakAirstream))
        XCTAssertTrue(evaluation.flags.contains(.shortSustain))
    }

    // MARK: - Pole resolution

    func testPoleForTargetSound() {
        XCTAssertEqual(SibilantPole.pole(forTargetSound: "С"), .whistling)
        XCTAssertEqual(SibilantPole.pole(forTargetSound: "з"), .whistling)
        XCTAssertEqual(SibilantPole.pole(forTargetSound: "Ц"), .whistling)
        XCTAssertEqual(SibilantPole.pole(forTargetSound: "Ш"), .hissing)
        XCTAssertEqual(SibilantPole.pole(forTargetSound: "ж"), .hissing)
        XCTAssertEqual(SibilantPole.pole(forTargetSound: "Щ"), .hissing)
        XCTAssertEqual(SibilantPole.pole(forTargetSound: "Ч"), .hissing)
        XCTAssertNil(SibilantPole.pole(forTargetSound: "Р"))
        XCTAssertNil(SibilantPole.pole(forTargetSound: ""))
    }

    // MARK: - End-to-end (синтетика → анализатор → классификатор)

    func testEndToEndWhistlingSuccess() {
        let pcm = silence(duration: 0.15)
            + narrowbandNoise(centerHz: 7_100, bandwidthHz: 1_500, duration: 1.0, seed: 21)
            + silence(duration: 0.15)
        let measurement = SibilantAcousticsAnalyzer.analyze(pcm: pcm)
        let evaluation = SibilantContinuumClassifier.evaluate(
            measurement: measurement,
            targetPole: .whistling
        )
        XCTAssertTrue(
            evaluation.verdict == .onTarget || evaluation.verdict == .nearTarget,
            "Высокий узкополосный шум должен распознаваться как С-полюс, got \(evaluation.verdict)"
        )
        XCTAssertGreaterThanOrEqual(evaluation.stars, 2)
    }

    func testEndToEndSubstitutionDetected() {
        // Целились в С, тянули «Ш»-подобный шум → классическая замена видна зеркалу.
        let pcm = narrowbandNoise(centerHz: 3_500, bandwidthHz: 1_400, duration: 1.0, seed: 33)
        let measurement = SibilantAcousticsAnalyzer.analyze(pcm: pcm)
        let evaluation = SibilantContinuumClassifier.evaluate(
            measurement: measurement,
            targetPole: .whistling
        )
        XCTAssertTrue(
            evaluation.verdict == .oppositePole || evaluation.verdict == .middle,
            "Низкий шум при цели С должен уйти к Ш-полюсу, got \(evaluation.verdict)"
        )
    }
}
