import Accelerate
import Foundation

// MARK: - SibilantMeasurement

/// Акустическое измерение фрикативного (свистяще-шипящего) сегмента записи.
///
/// Получается классическим спектрально-моментным анализом (Forrest et al. 1988;
/// Jongman, Wayland & Wong 2000): центр тяжести спектра фрикативного шума —
/// устойчивый акустический коррелят места артикуляции сибилянта. У [с] энергия
/// сконцентрирована высоко (узкий зубной желобок → высокочастотный шум), у [ш] —
/// заметно ниже (широкая «чашечка», большая передняя полость).
///
/// ## Честные границы
/// Это ИЗМЕРЕНИЕ акустики записи, а не диагноз и не клиническая оценка речи.
/// Пороговые значения подобраны эвристически по данным акустической фонетики
/// детской речи и НЕ валидированы на клиническом корпусе. Использовать только
/// для игровой биообратной связи («куда смещается твой звук»), сравнения попыток
/// одного ребёнка между собой и мотивации — не для заключений (project guide §11).
public struct SibilantMeasurement: Sendable, Equatable {

    /// Спектральный центр тяжести фрикативного сегмента, Гц (в полосе анализа).
    public let centroidHz: Double

    /// Спектральное стандартное отклонение, Гц — «компактность» шума.
    /// Узкий пик (малое значение) типичен для чистого [с]; большое значение —
    /// диффузный, «размытый» шум (часто при межзубном/боковом искажении).
    public let spreadHz: Double

    /// Доля энергии верхней полосы (5–8 кГц) внутри сибилянтной полосы (2.5–8 кГц).
    /// Дополнительный дискриминатор «свистящий ↔ шипящий» полюсов.
    public let highBandShare: Double

    /// Длительность найденного фрикативного сегмента, секунды.
    public let fricationDuration: Double

    /// Пиковая RMS-амплитуда сегмента (0…1) — «сила струи».
    public let peakRMS: Double

    /// Число кадров анализа, вошедших в сегмент.
    public let frameCount: Int

    public init(
        centroidHz: Double,
        spreadHz: Double,
        highBandShare: Double,
        fricationDuration: Double,
        peakRMS: Double,
        frameCount: Int
    ) {
        self.centroidHz = centroidHz
        self.spreadHz = spreadHz
        self.highBandShare = highBandShare
        self.fricationDuration = fricationDuration
        self.peakRMS = peakRMS
        self.frameCount = frameCount
    }
}

// MARK: - SibilantAcousticsAnalyzer

/// Детерминированный DSP-анализатор сибилянтов: PCM → спектральные моменты
/// фрикативного сегмента. Чистый vDSP/Accelerate, без ML-моделей и без сети —
/// работает мгновенно на любом устройстве (COPPA-safe by construction).
///
/// ## Алгоритм
/// 1. Кадрирование: окна по 512 сэмплов (32 мс @ 16 кГц), шаг 256 (50 % overlap),
///    окно Ханна.
/// 2. По кадру: RMS, zero-crossing rate, спектр мощности (vDSP FFT 512).
/// 3. Детекция фрикативных кадров: высокий ZCR + энергия сибилянтной полосы
///    (2.5–8 кГц) доминирует над низкочастотной (0.1–1.2 кГц) + RMS выше
///    адаптивного шумового порога.
/// 4. Выбирается ДЛИННЕЙШИЙ непрерывный фрикативный сегмент (≥ `minFricationFrames`
///    кадров): ребёнок «тянет» звук, короткие щелчки/шумы отбрасываются.
/// 5. По усреднённому спектру сегмента (полоса 1–8 кГц) считаются центроид,
///    разброс и доля верхней полосы.
///
/// Возвращает `nil`, если фрикативный сегмент не найден (тишина / голый гласный /
/// слишком короткая попытка) — честное «не расслышала», без фабрикации значения.
public enum SibilantAcousticsAnalyzer {

    // MARK: - Tunables (документированные эвристики)

    /// Размер кадра анализа в сэмплах (32 мс @ 16 кГц). Степень двойки для FFT.
    public static let frameSize = 512

    /// Шаг кадра (50 % перекрытие).
    public static let hopSize = 256

    /// Частота дискретизации, на которую рассчитан анализ.
    public static let expectedSampleRate: Double = 16_000

    /// Минимальное число подряд фрикативных кадров (4 × 16 мс ≈ 64 мс) —
    /// короче устойчивый сибилянт не бывает даже у детей.
    public static let minFricationFrames = 4

    /// Минимальный ZCR кадра (доля знакопеременных переходов, 0…1), чтобы
    /// считать его шумным/фрикативным. Гласные дают ~0.02–0.12, сибилянты > 0.25.
    static let zcrThreshold: Double = 0.22

    /// Во сколько раз энергия сибилянтной полосы (2.5–8 кГц) должна превышать
    /// низкочастотную (0.1–1.2 кГц), чтобы кадр считался фрикативным.
    static let sibilantBandDominance: Double = 1.5

    /// Адаптивный амплитудный гейт: кадр должен иметь RMS ≥ доля от пикового
    /// RMS записи (отсечение фонового шума пауз).
    static let rmsGateShare: Double = 0.18

    /// Абсолютный пол RMS — совсем тихие записи (микрофон прикрыт) не анализируем.
    static let rmsFloor: Double = 0.004

    /// Полоса вычисления спектральных моментов, Гц. Ниже 1 кГц — голос/гласный
    /// (не место артикуляции сибилянта), выше 8 кГц возможен алиасинг-резерв.
    static let momentBand: ClosedRange<Double> = 1_000 ... 8_000

    /// Сибилянтная полоса для детекции, Гц.
    static let sibilantBand: ClosedRange<Double> = 2_500 ... 8_000

    /// Низкочастотная (вокализованная) полоса для контраста, Гц.
    static let lowBand: ClosedRange<Double> = 100 ... 1_200

    /// Верхняя подполоса для `highBandShare`, Гц.
    static let highSubBand: ClosedRange<Double> = 5_000 ... 8_000

    // MARK: - Public API

    /// Анализирует моно-PCM (Float32) и возвращает измерение лучшего
    /// фрикативного сегмента, либо `nil`, если сибилянтного шума нет.
    ///
    /// - Parameters:
    ///   - pcm: сэмплы −1…1, mono.
    ///   - sampleRate: частота дискретизации входа (ожидается 16 кГц; другие
    ///     значения корректно пересчитывают частотную сетку бинов).
    public static func analyze(pcm: [Float], sampleRate: Double = expectedSampleRate) -> SibilantMeasurement? {
        guard sampleRate > 0, pcm.count >= frameSize else { return nil }

        let frames = frameFeatures(pcm: pcm, sampleRate: sampleRate)
        guard !frames.isEmpty else { return nil }

        let peakRMS = frames.map(\.rms).max() ?? 0
        guard peakRMS > rmsFloor else { return nil }

        let gate = max(rmsFloor, peakRMS * rmsGateShare)
        let fricative = frames.map { frame in
            frame.rms >= gate
                && frame.zcr >= zcrThreshold
                && frame.sibilantPower > frame.lowPower * sibilantBandDominance
        }

        guard let run = longestTrueRun(fricative), run.count >= minFricationFrames else {
            return nil
        }

        // Усреднённый спектр сегмента.
        let binCount = frames[run.lowerBound].spectrum.count
        var avgSpectrum = [Double](repeating: 0, count: binCount)
        var segmentPeakRMS: Double = 0
        for idx in run {
            let frame = frames[idx]
            segmentPeakRMS = max(segmentPeakRMS, frame.rms)
            for bin in 0 ..< binCount {
                avgSpectrum[bin] += frame.spectrum[bin]
            }
        }
        let runLength = Double(run.count)
        for bin in 0 ..< binCount { avgSpectrum[bin] /= runLength }

        let hzPerBin = sampleRate / Double(frameSize)
        guard let moments = spectralMoments(
            spectrum: avgSpectrum,
            hzPerBin: hzPerBin,
            band: momentBand
        ) else { return nil }

        let high = bandPower(avgSpectrum, hzPerBin: hzPerBin, band: highSubBand)
        let sib = bandPower(avgSpectrum, hzPerBin: hzPerBin, band: sibilantBand)
        let highShare = sib > 0 ? min(1, max(0, high / sib)) : 0

        let duration = Double(run.count) * Double(hopSize) / sampleRate

        return SibilantMeasurement(
            centroidHz: moments.centroid,
            spreadHz: moments.spread,
            highBandShare: highShare,
            fricationDuration: duration,
            peakRMS: segmentPeakRMS,
            frameCount: run.count
        )
    }

    // MARK: - Frame features

    /// Признаки одного кадра анализа.
    struct FrameFeatures {
        let rms: Double
        let zcr: Double
        /// Спектр мощности (половина FFT, `frameSize/2` бинов).
        let spectrum: [Double]
        let sibilantPower: Double
        let lowPower: Double
    }

    /// Кадрирует сигнал и считает признаки каждого кадра.
    static func frameFeatures(pcm: [Float], sampleRate: Double) -> [FrameFeatures] {
        let n = frameSize
        guard pcm.count >= n else { return [] }

        // Окно Ханна — один раз на все кадры.
        var window = [Float](repeating: 0, count: n)
        vDSP_hann_window(&window, vDSP_Length(n), Int32(vDSP_HANN_NORM))

        // FFT setup — log2(512) = 9.
        let log2n = vDSP_Length(log2(Double(n)).rounded())
        guard let fft = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return [] }
        defer { vDSP_destroy_fftsetup(fft) }

        let hzPerBin = sampleRate / Double(n)
        var result: [FrameFeatures] = []
        result.reserveCapacity((pcm.count - n) / hopSize + 1)

        var offset = 0
        while offset + n <= pcm.count {
            let frame = Array(pcm[offset ..< offset + n])
            offset += hopSize

            // RMS.
            var rms: Float = 0
            vDSP_rmsqv(frame, 1, &rms, vDSP_Length(n))

            // Zero-crossing rate.
            var crossings = 0
            for i in 1 ..< n where (frame[i - 1] < 0) != (frame[i] < 0) {
                crossings += 1
            }
            let zcr = Double(crossings) / Double(n - 1)

            // Спектр мощности через vDSP real FFT.
            var windowed = [Float](repeating: 0, count: n)
            vDSP_vmul(frame, 1, window, 1, &windowed, 1, vDSP_Length(n))

            var spectrum = [Double](repeating: 0, count: n / 2)
            var real = [Float](repeating: 0, count: n / 2)
            var imag = [Float](repeating: 0, count: n / 2)
            real.withUnsafeMutableBufferPointer { realPtr in
                imag.withUnsafeMutableBufferPointer { imagPtr in
                    guard let realBase = realPtr.baseAddress,
                          let imagBase = imagPtr.baseAddress else { return }
                    var split = DSPSplitComplex(realp: realBase, imagp: imagBase)
                    windowed.withUnsafeBufferPointer { src in
                        guard let srcBase = src.baseAddress else { return }
                        srcBase.withMemoryRebound(to: DSPComplex.self, capacity: n / 2) { complexPtr in
                            vDSP_ctoz(complexPtr, 2, &split, 1, vDSP_Length(n / 2))
                        }
                    }
                    vDSP_fft_zrip(fft, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                    var power = [Float](repeating: 0, count: n / 2)
                    vDSP_zvmags(&split, 1, &power, 1, vDSP_Length(n / 2))
                    for bin in 0 ..< n / 2 { spectrum[bin] = Double(power[bin]) }
                }
            }
            // DC-бин не информативен для фрикативного анализа.
            if !spectrum.isEmpty { spectrum[0] = 0 }

            let sibPower = bandPower(spectrum, hzPerBin: hzPerBin, band: sibilantBand)
            let lowPower = bandPower(spectrum, hzPerBin: hzPerBin, band: lowBand)

            result.append(
                FrameFeatures(
                    rms: Double(rms),
                    zcr: zcr,
                    spectrum: spectrum,
                    sibilantPower: sibPower,
                    lowPower: lowPower
                )
            )
        }
        return result
    }

    // MARK: - Helpers

    /// Суммарная мощность спектра в полосе частот.
    static func bandPower(_ spectrum: [Double], hzPerBin: Double, band: ClosedRange<Double>) -> Double {
        guard hzPerBin > 0 else { return 0 }
        let lowBin = max(0, Int((band.lowerBound / hzPerBin).rounded(.down)))
        let highBin = min(spectrum.count - 1, Int((band.upperBound / hzPerBin).rounded(.up)))
        guard lowBin <= highBin else { return 0 }
        var sum: Double = 0
        for bin in lowBin ... highBin { sum += spectrum[bin] }
        return sum
    }

    /// Центроид и разброс спектра в заданной полосе. `nil`, если энергии нет.
    static func spectralMoments(
        spectrum: [Double],
        hzPerBin: Double,
        band: ClosedRange<Double>
    ) -> (centroid: Double, spread: Double)? {
        guard hzPerBin > 0 else { return nil }
        let lowBin = max(1, Int((band.lowerBound / hzPerBin).rounded(.down)))
        let highBin = min(spectrum.count - 1, Int((band.upperBound / hzPerBin).rounded(.up)))
        guard lowBin <= highBin else { return nil }

        var total: Double = 0
        var weighted: Double = 0
        for bin in lowBin ... highBin {
            let freq = Double(bin) * hzPerBin
            total += spectrum[bin]
            weighted += spectrum[bin] * freq
        }
        guard total > 0 else { return nil }
        let centroid = weighted / total

        var variance: Double = 0
        for bin in lowBin ... highBin {
            let freq = Double(bin) * hzPerBin
            let dev = freq - centroid
            variance += spectrum[bin] * dev * dev
        }
        let spread = (variance / total).squareRoot()
        return (centroid, spread)
    }

    /// Самый длинный непрерывный диапазон `true` в булевом массиве.
    static func longestTrueRun(_ flags: [Bool]) -> Range<Int>? {
        var best: Range<Int>?
        var runStart: Int?
        for (idx, flag) in flags.enumerated() {
            if flag {
                if runStart == nil { runStart = idx }
            } else if let start = runStart {
                let run = start ..< idx
                if run.count > (best?.count ?? 0) { best = run }
                runStart = nil
            }
        }
        if let start = runStart {
            let run = start ..< flags.count
            if run.count > (best?.count ?? 0) { best = run }
        }
        return best
    }
}
