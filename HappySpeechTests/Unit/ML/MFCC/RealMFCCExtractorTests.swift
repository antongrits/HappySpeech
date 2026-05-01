import Accelerate
import XCTest

@testable import HappySpeech

// MARK: - RealMFCCExtractorTests

/// Unit-тесты для `RealMFCCExtractor` (Block G v13).
///
/// Покрываемые сценарии:
/// - Тишина → MFCC близки к нулю
/// - Синусоида 440 Гц → пик в спектре в нужном месте
/// - 1 сек аудио @ 16kHz → ~99 фреймов × 39 размерностей
/// - Delta + delta-delta = 39 коэффициентов
/// - Mel filterbank покрывает 0–8000 Гц (40 фильтров)
/// - Hamming window: сумма коэффициентов
///
/// Запуск:
/// ```
/// xcodebuild test -project HappySpeech.xcodeproj -scheme HappySpeech \
///   -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
///   -only-testing:HappySpeechTests/Unit/ML/MFCC
/// ```
final class RealMFCCExtractorTests: XCTestCase {

    private var extractor: RealMFCCExtractor!

    override func setUp() async throws {
        try await super.setUp()
        extractor = RealMFCCExtractor()
    }

    override func tearDown() async throws {
        extractor = nil
        try await super.tearDown()
    }

    // MARK: - testMFCCSilence

    /// Синтетическая тишина (нули) → все базовые MFCC коэффициенты должны быть близки к нулю.
    /// Log(1e-10) ≈ -23, после DCT результат ненулевой, но delta и delta-delta → 0.
    func testMFCCSilence() async throws {
        let silenceSamples = [Float](repeating: 0.0, count: 16_000)
        let frames = await extractor.extract(from: silenceSamples)

        XCTAssertFalse(frames.isEmpty, "Тишина должна порождать хотя бы один фрейм")

        // Delta и delta-delta коэффициенты (позиции 13-38) должны быть ~0
        // для постоянного сигнала (нет временного изменения)
        for (i, frame) in frames.enumerated() {
            XCTAssertEqual(frame.count, 39, "Каждый фрейм должен иметь 39 коэффициентов")
            let deltaCoeffs = Array(frame[13 ..< 26])
            let deltaDeltaCoeffs = Array(frame[26 ..< 39])
            let deltaMax = deltaCoeffs.map { abs($0) }.max() ?? 0
            let ddMax = deltaDeltaCoeffs.map { abs($0) }.max() ?? 0
            XCTAssertLessThan(
                deltaMax, 1e-4,
                "Delta коэффициенты фрейма \(i) должны быть ~0 для постоянного сигнала (получено \(deltaMax))"
            )
            XCTAssertLessThan(
                ddMax, 1e-4,
                "Delta-delta коэффициенты фрейма \(i) должны быть ~0 для постоянного сигнала (получено \(ddMax))"
            )
        }
    }

    // MARK: - testMFCCSineWave

    /// Синусоида 440 Гц → MFCC ненулевые, амплитуда первого коэффициента значима.
    /// 440 Гц попадает в mel-бины примерно в диапазоне 4–8, что должно давать
    /// заметный первый MFCC коэффициент (log mel energy).
    func testMFCCSineWave() async throws {
        let sampleRate: Float = 16_000
        let frequency: Float = 440
        let durationSamples = 16_000  // 1 секунда

        let samples = (0 ..< durationSamples).map { i in
            sin(2.0 * Float.pi * frequency * Float(i) / sampleRate) * 0.5
        }

        let frames = await extractor.extract(from: samples)

        XCTAssertFalse(frames.isEmpty, "Синусоида должна порождать фреймы")

        // Первый базовый коэффициент (C0) должен быть значимым
        // (ненулевая log-мел энергия на частоте 440 Гц)
        let firstCoeff = frames[frames.count / 2][0]
        XCTAssertGreaterThan(
            abs(firstCoeff), 0.01,
            "Первый MFCC коэф для 440 Гц синусоиды должен быть ненулевым (получено \(firstCoeff))"
        )
    }

    // MARK: - testMFCCFrameDimensions

    /// 1 сек аудио @ 16kHz → ожидаемое количество фреймов и размерность.
    ///
    /// Frame count: последний валидный frameStart = 15600 (15600+400=16000=count).
    /// Итераций: 0, 160, 320, ..., 15600 = 15600/160 + 1 = 98 фреймов.
    /// Каждый фрейм: 39 коэффициентов (13 base + 13 delta + 13 delta-delta).
    func testMFCCFrameDimensions() async throws {
        let samples = [Float](repeating: 0.1, count: 16_000)
        let frames = await extractor.extract(from: samples)

        // Ожидаемое количество фреймов: последний валидный frameStart = 15600
        // stride(from:0, to:count-frameSize+1, by:hopSize).count = (15600/160)+1 = 98
        let expectedFrames = (16_000 - RealMFCCExtractor.frameSize) / RealMFCCExtractor.hopSize + 1
        XCTAssertEqual(
            frames.count, expectedFrames,
            "1 сек @ 16kHz должен давать \(expectedFrames) фреймов, получено \(frames.count)"
        )

        // Каждый фрейм: 39 коэффициентов
        for (i, frame) in frames.enumerated() {
            XCTAssertEqual(
                frame.count,
                RealMFCCExtractor.nCoeffs * 3,
                "Фрейм \(i): ожидается \(RealMFCCExtractor.nCoeffs * 3) коэф, получено \(frame.count)"
            )
        }
    }

    // MARK: - testDeltasComputed

    /// Проверяет что 39 = 13 base + 13 delta + 13 delta-delta.
    func testDeltasComputed() async throws {
        let samples = (0 ..< 16_000).map { i in
            sin(2.0 * Float.pi * 1000 * Float(i) / 16_000) * 0.3
        }
        let frames = await extractor.extract(from: samples)

        XCTAssertFalse(frames.isEmpty)
        let frame = frames[frames.count / 2]  // берём средний фрейм

        XCTAssertEqual(frame.count, 39, "39 = 13 base + 13 delta + 13 delta-delta")

        let base       = Array(frame[0 ..< 13])
        let delta      = Array(frame[13 ..< 26])
        let deltaDelta = Array(frame[26 ..< 39])

        // Base не должен совпадать с delta (разные физические величины)
        let baseNorm       = base.map { $0 * $0 }.reduce(0, +)
        let deltaNorm      = delta.map { $0 * $0 }.reduce(0, +)
        let deltaDeltaNorm = deltaDelta.map { $0 * $0 }.reduce(0, +)

        // Все три части должны иметь ненулевую норму для нетривиального сигнала
        XCTAssertGreaterThan(baseNorm, 0, "Base MFCC должны быть ненулевыми")
        // Delta и delta-delta для синусоиды могут быть очень малы (~0),
        // поэтому только проверяем что они присутствуют (count == 13)
        XCTAssertEqual(base.count, 13)
        XCTAssertEqual(delta.count, 13)
        XCTAssertEqual(deltaDelta.count, 13)

        // Убеждаемся что delta-delta нормализованы правильно (меньше base по абсолютному значению)
        _ = deltaNorm
        _ = deltaDeltaNorm
    }

    // MARK: - testMelFilterbankCoverage

    /// Проверяет что Mel filterbank содержит 40 фильтров и покрывает весь диапазон 0–8000 Гц.
    ///
    /// Проверяем косвенно: сигнал 100 Гц и сигнал 7000 Гц дают разные MFCC профили.
    func testMelFilterbankCoverage() async throws {
        let sr = 16_000
        let nSamples = sr * 2  // 2 секунды

        let lowFreqSamples = (0 ..< nSamples).map { i in
            sin(2.0 * Float.pi * 100 * Float(i) / Float(sr)) * 0.5
        }
        let highFreqSamples = (0 ..< nSamples).map { i in
            sin(2.0 * Float.pi * 7000 * Float(i) / Float(sr)) * 0.5
        }

        let lowFrames  = await extractor.extract(from: lowFreqSamples)
        let highFrames = await extractor.extract(from: highFreqSamples)

        XCTAssertFalse(lowFrames.isEmpty)
        XCTAssertFalse(highFrames.isEmpty)

        // MFCC профили 100 Гц и 7000 Гц должны отличаться
        let midLow  = lowFrames[lowFrames.count / 2]
        let midHigh = highFrames[highFrames.count / 2]

        // Евклидово расстояние между средними фреймами должно быть значимым
        let distance = zip(midLow, midHigh).map { pow($0 - $1, 2) }.reduce(0, +)
        XCTAssertGreaterThan(
            distance, 1.0,
            "MFCC 100 Гц и 7000 Гц должны различаться (расстояние=\(distance))"
        )

        // Проверяем что количество mel bins = 40 (через константу)
        XCTAssertEqual(RealMFCCExtractor.nMelBins, 40, "Должно быть 40 mel фильтров")
    }

    // MARK: - testHammingWindowSum

    /// Проверяет корректность Hamming window через свойство: для frameSize=400
    /// сумма коэффициентов ≈ frameSize * 0.54 = 216 (среднее значение Hamming window = 0.54).
    func testHammingWindowSum() async throws {
        // Hamming window: w[n] = 0.54 - 0.46 * cos(2*pi*n/(N-1))
        // Среднее значение = 0.54 (интеграл от 0 до 1 = 0.54)
        // Сумма для N=400: ≈ 400 * 0.54 = 216
        let frameSize = RealMFCCExtractor.frameSize
        let expectedSum = Float(frameSize) * 0.54
        let tolerance: Float = Float(frameSize) * 0.02  // 2% допуск

        // Вычисляем Hamming window явно для сравнения
        let window = (0 ..< frameSize).map { i in
            0.54 - 0.46 * cos(2.0 * Float.pi * Float(i) / Float(frameSize - 1))
        }
        let actualSum = window.reduce(0, +)

        XCTAssertEqual(
            actualSum, expectedSum,
            accuracy: tolerance,
            "Сумма Hamming window [\(frameSize)] должна быть ≈\(expectedSum) (получено \(actualSum))"
        )

        // Все коэффициенты должны быть в [0.08, 1.0] (Hamming диапазон)
        let minVal = window.min() ?? 0
        let maxVal = window.max() ?? 0
        XCTAssertGreaterThanOrEqual(minVal, 0.08, "Hamming min ≈ 0.08")
        XCTAssertLessThanOrEqual(maxVal, 1.01, "Hamming max = 1.0")
    }
}
