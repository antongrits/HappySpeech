import XCTest
@testable import HappySpeech

/// Тесты DSP-ядра «Скороговорки-ракеты»: детектор слоговых ядер по огибающей
/// энергии + классификатор темпа/ритма диадохокинеза.
/// Все сигналы синтетические и детерминированные — без файлов и I/O.
final class SyllableRateAnalyzerTests: XCTestCase {

    private let sampleRate = SyllableRateAnalyzer.expectedSampleRate

    // MARK: - Синтез слоговых рядов

    /// Синтезирует ряд из `count` слоговых импульсов с заданным периодом.
    /// Каждый слог — короткий «всплеск» (синус 600 Гц под колоколом Ханна),
    /// между всплесками — тишина (паузы между слогами).
    /// - jitter: относительный разброс периода (0 — идеально ровно).
    private func syllableTrain(
        count: Int,
        periodSec: Double,
        burstSec: Double = 0.10,
        amplitude: Float = 0.5,
        jitter: Double = 0,
        seed: UInt64 = 11
    ) -> [Float] {
        var state = seed == 0 ? UInt64(1) : seed
        func nextUnit() -> Double { // [-1, 1] детерминированно
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 33) / Double(UInt32.max) * 2 - 1
        }

        // Времена начала слогов.
        var onsets: [Double] = []
        var t = 0.05
        for _ in 0 ..< count {
            onsets.append(t)
            let jitteredPeriod = periodSec * (1 + jitter * nextUnit())
            t += max(0.02, jitteredPeriod)
        }
        let totalSec = (onsets.last ?? 0) + burstSec + 0.1
        let totalSamples = Int(totalSec * sampleRate)
        var signal = [Float](repeating: 0, count: totalSamples)

        let burstSamples = Int(burstSec * sampleRate)
        for onset in onsets {
            let start = Int(onset * sampleRate)
            for i in 0 ..< burstSamples {
                let idx = start + i
                guard idx < totalSamples else { break }
                // Колокол Ханна по всплеску + несущая 600 Гц.
                let env = 0.5 * (1 - cos(2 * .pi * Double(i) / Double(burstSamples - 1)))
                let carrier = sin(2 * .pi * 600 * Double(idx) / sampleRate)
                signal[idx] += Float(env * carrier) * amplitude
            }
        }
        return signal
    }

    private func silence(duration: Double) -> [Float] {
        [Float](repeating: 0, count: Int(duration * sampleRate))
    }

    // MARK: - Envelope / peak picking

    func testSilenceYieldsNoMeasurement() {
        XCTAssertNil(SyllableRateAnalyzer.analyze(pcm: silence(duration: 1.5)),
                     "Тишина не должна давать измерение")
    }

    func testTooShortYieldsNil() {
        let tiny = [Float](repeating: 0.3, count: SyllableRateAnalyzer.frameSize)
        XCTAssertNil(SyllableRateAnalyzer.analyze(pcm: tiny),
                     "Слишком короткая запись → nil")
    }

    func testCountsEightEvenSyllables() {
        // 8 слогов с периодом 0.25 с (4 слога/с).
        let pcm = syllableTrain(count: 8, periodSec: 0.25)
        guard let m = SyllableRateAnalyzer.analyze(pcm: pcm) else {
            return XCTFail("Ряд из 8 слогов должен распознаться")
        }
        // Детектор допускает ±1 на границах.
        XCTAssertTrue((7...9).contains(m.syllableCount),
                      "Ожидалось ~8 слогов, получено \(m.syllableCount)")
    }

    func testRateMatchesPeriod() {
        // Период 0.20 с → ~5 слог/с.
        let pcm = syllableTrain(count: 10, periodSec: 0.20)
        guard let m = SyllableRateAnalyzer.analyze(pcm: pcm) else {
            return XCTFail("Ряд должен распознаться")
        }
        XCTAssertEqual(m.syllablesPerSecond, 5.0, accuracy: 1.2,
                       "Темп должен примерно соответствовать периоду (~5/с)")
    }

    func testEvenTrainHasLowCV() {
        let pcm = syllableTrain(count: 9, periodSec: 0.22, jitter: 0)
        guard let m = SyllableRateAnalyzer.analyze(pcm: pcm), let cv = m.intervalCV else {
            return XCTFail("Ровный ряд должен дать CV")
        }
        XCTAssertLessThan(cv, 0.20, "Ровный ряд → малый коэффициент вариации")
    }

    func testJitteryTrainHasHigherCV() {
        let even = syllableTrain(count: 9, periodSec: 0.22, jitter: 0, seed: 3)
        let jittery = syllableTrain(count: 9, periodSec: 0.22, jitter: 0.6, seed: 3)
        guard let mEven = SyllableRateAnalyzer.analyze(pcm: even), let cvEven = mEven.intervalCV,
              let mJit = SyllableRateAnalyzer.analyze(pcm: jittery), let cvJit = mJit.intervalCV else {
            return XCTFail("Оба ряда должны дать CV")
        }
        XCTAssertGreaterThan(cvJit, cvEven,
                             "Рваный ряд должен иметь больший CV, чем ровный")
    }

    func testSingleBurstNotEnoughForSequence() {
        // Один слог — не ряд диадохокинеза.
        let pcm = syllableTrain(count: 1, periodSec: 0.25)
        XCTAssertNil(SyllableRateAnalyzer.analyze(pcm: pcm),
                     "Один слог не образует ряд → nil")
    }

    func testLongestPlateauNotSplitIntoMany() {
        // Непрерывный громкий «гласный» 1 с — это одно плато, не много слогов.
        let count = Int(1.0 * sampleRate)
        var pcm = [Float](repeating: 0, count: count)
        for idx in 0 ..< count {
            pcm[idx] = Float(sin(2 * .pi * 500 * Double(idx) / sampleRate)) * 0.4
        }
        let m = SyllableRateAnalyzer.analyze(pcm: pcm)
        // Допускается nil (одно плато не даёт ≥2 раздельных ядра) или малое число.
        if let m {
            XCTAssertLessThanOrEqual(m.syllableCount, 3,
                                     "Сплошное плато не должно дробиться на много слогов")
        }
    }

    // MARK: - peakPicking unit (без синтеза сигнала)

    func testPickPeaksRespectsRefractoryGap() {
        // Две вершины ближе minGap → должна остаться одна (более громкая).
        let env: [Double] = [0.0, 0.1, 0.9, 0.1, 0.95, 0.1, 0.0]
        let peaks = SyllableRateAnalyzer.pickPeaks(env, threshold: 0.3, minGapFrames: 4)
        XCTAssertEqual(peaks.count, 1, "Близкие вершины подавляются рефрактером")
        XCTAssertEqual(peaks.first, 4, "Остаётся более громкая вершина")
    }

    func testPickPeaksSeparatesByValley() {
        // Две вершины с глубокой долиной между ними → две вершины.
        let env: [Double] = [0.0, 0.9, 0.05, 0.05, 0.05, 0.9, 0.0]
        let peaks = SyllableRateAnalyzer.pickPeaks(env, threshold: 0.3, minGapFrames: 2)
        XCTAssertEqual(peaks.count, 2, "Глубокая долина разделяет вершины")
    }

    // MARK: - Classifier

    func testNotDetectedWhenMeasurementNil() {
        let seq = DDKCatalog.sequence(id: "ddk-pa")
        let eval = SyllableRateClassifier.evaluate(measurement: nil, sequence: seq, childAge: 6)
        XCTAssertEqual(eval.verdict, .notDetected)
        XCTAssertEqual(eval.stars, 0)
    }

    func testFastSteadyEarnsThreeStars() {
        let seq = DDKCatalog.sequence(id: "ddk-pa") // моно, target 8
        let m = SyllableRateMeasurement(
            syllableCount: 8,
            syllablesPerSecond: 6.0, // выше floor*1.25 для 6 лет (≈3.8*1.25≈4.75)
            voicedDurationSec: 1.16,
            intervalCV: 0.08,
            meanIntervalSec: 0.166,
            peakRMS: 0.2
        )
        let eval = SyllableRateClassifier.evaluate(measurement: m, sequence: seq, childAge: 6)
        XCTAssertEqual(eval.verdict, .fastSteady)
        XCTAssertEqual(eval.stars, 3)
    }

    func testUnevenRhythmFlagged() {
        let seq = DDKCatalog.sequence(id: "ddk-pa")
        let m = SyllableRateMeasurement(
            syllableCount: 8,
            syllablesPerSecond: 5.0,
            voicedDurationSec: 1.4,
            intervalCV: 0.5, // выше unevenCVThreshold
            meanIntervalSec: 0.2,
            peakRMS: 0.2
        )
        let eval = SyllableRateClassifier.evaluate(measurement: m, sequence: seq, childAge: 6)
        XCTAssertTrue(eval.flags.contains(.unevenRhythm))
        XCTAssertEqual(eval.verdict, .uneven)
    }

    func testSlowVerdictForLowRate() {
        let seq = DDKCatalog.sequence(id: "ddk-pa")
        let m = SyllableRateMeasurement(
            syllableCount: 6,
            syllablesPerSecond: 1.5, // явно ниже floor
            voicedDurationSec: 3.3,
            intervalCV: 0.1,
            meanIntervalSec: 0.66,
            peakRMS: 0.2
        )
        let eval = SyllableRateClassifier.evaluate(measurement: m, sequence: seq, childAge: 6)
        XCTAssertEqual(eval.verdict, .slow)
        XCTAssertEqual(eval.stars, 1)
    }

    func testIncompleteSequenceFlagged() {
        let seq = DDKCatalog.sequence(id: "ddk-pa") // target 8
        let m = SyllableRateMeasurement(
            syllableCount: 4, // < target - tolerance
            syllablesPerSecond: 5.0,
            voicedDurationSec: 0.6,
            intervalCV: 0.1,
            meanIntervalSec: 0.2,
            peakRMS: 0.2
        )
        let eval = SyllableRateClassifier.evaluate(measurement: m, sequence: seq, childAge: 6)
        XCTAssertTrue(eval.flags.contains(.incompleteSequence))
    }

    func testAlternatingSequenceHasLowerFloor() {
        let mono = SyllableRateClassifier.steadyRateFloor(age: 6, isAlternating: false)
        let alt = SyllableRateClassifier.steadyRateFloor(age: 6, isAlternating: true)
        XCTAssertLessThan(alt, mono,
                          "Переключательный ряд (па-та-ка) ожидаемо медленнее моно")
    }

    func testFloorGrowsWithAge() {
        let five = SyllableRateClassifier.steadyRateFloor(age: 5, isAlternating: false)
        let eight = SyllableRateClassifier.steadyRateFloor(age: 8, isAlternating: false)
        XCTAssertGreaterThan(eight, five, "Ориентир темпа растёт с возрастом")
    }

    func testSteadinessMapping() {
        XCTAssertEqual(SyllableRateClassifier.steadiness(intervalCV: 0)!, 1.0, accuracy: 0.001)
        XCTAssertNil(SyllableRateClassifier.steadiness(intervalCV: nil))
        let mid = SyllableRateClassifier.steadiness(intervalCV: SyllableRateClassifier.unevenCVThreshold)!
        XCTAssertEqual(mid, 0.5, accuracy: 0.05, "CV на пороге → ровность ~0.5")
    }

    func testCatalogHasMonoAndAlternating() {
        let seqs = DDKCatalog.sequences
        XCTAssertTrue(seqs.contains { $0.cycleLength == 1 }, "Есть моносиллабический ряд")
        XCTAssertTrue(seqs.contains { $0.cycleLength == 3 }, "Есть па-та-ка")
        let pataka = DDKCatalog.sequence(id: "ddk-pataka")
        XCTAssertEqual(pataka.targetSyllableCount, 12, "па-та-ка ×4 = 12 слогов")
        XCTAssertEqual(pataka.displayString, "па-та-ка")
    }

    // MARK: - End-to-end (синтез → анализ → классификация)

    func testEndToEndFastEvenTrainScoresWell() {
        // 8 слогов, период 0.18 с (~5.5/с) ровно → должен быть хороший результат.
        let pcm = syllableTrain(count: 8, periodSec: 0.18, jitter: 0)
        let seq = DDKCatalog.sequence(id: "ddk-pa")
        guard let m = SyllableRateAnalyzer.analyze(pcm: pcm) else {
            return XCTFail("Ряд должен распознаться")
        }
        let eval = SyllableRateClassifier.evaluate(measurement: m, sequence: seq, childAge: 6)
        XCTAssertGreaterThanOrEqual(eval.stars, 2,
                                    "Быстрый ровный ряд → минимум 2 звезды (получено \(eval.stars), темп \(m.syllablesPerSecond))")
        XCTAssertNotEqual(eval.verdict, .notDetected)
    }
}
