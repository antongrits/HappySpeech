import Accelerate
import Foundation

// MARK: - RealMFCCExtractor

/// Реальный MFCC-экстрактор на Apple Accelerate vDSP без сторонних зависимостей.
///
/// Полный pipeline (39-мерный вектор = 13 base + 13 delta + 13 delta-delta):
/// 1. Pre-emphasis filter (alpha = 0.97)
/// 2. Framing: 25ms окна (400 сэмплов) с 10ms hop (160 сэмплов)
/// 3. Hamming window
/// 4. vDSP FFT (radix-2, nFFT = 512) → magnitude spectrum
/// 5. Mel filterbank (40 треугольных фильтров, 0 – 8000 Гц)
/// 6. Log mel energies (log с floor 1e-10)
/// 7. DCT-II → 13 cepstral коэффициентов
/// 8. Delta + delta-delta (конечные разности окна N=2)
///
/// ### Параметры
/// - SR: 16 kHz
/// - Frame: 400 сэмплов (25 ms)
/// - Hop: 160 сэмплов (10 ms)
/// - nFFT: 512 (ближайшая степень двойки ≥ 400)
/// - nMelBins: 40
/// - nCoeffs: 13 (base) → 39 (+ delta + delta-delta)
///
/// ### Производительность
/// - Setup кэшируется в `init` (FFT, Hamming, filterbank, DCT-матрица)
/// - 1 сек аудио @ 16 kHz: ~5–10 ms на iPhone 17 Pro (pure vDSP)
/// - Actor обеспечивает thread-safety без data races
///
/// ## See Also
/// - ``MFCCExtractor`` (legacy enum, 40 коэф без delta)
/// - ``MFCCExtractorProtocol``
public actor RealMFCCExtractor {

    // MARK: - Constants

    static let sampleRate: Double = 16_000
    static let frameSize: Int = 400     // 25 ms @ 16 kHz
    static let hopSize: Int = 160       // 10 ms @ 16 kHz
    static let nFFT: Int = 512          // ближайшая степень двойки ≥ 400
    static let nMelBins: Int = 40
    static let nCoeffs: Int = 13        // base MFCC коэффициентов (итого 39 с delta)
    static let deltaWindow: Int = 2     // N для конечных разностей

    // MARK: - Cached Setup

    nonisolated(unsafe) private let fftSetup: OpaquePointer
    private let fftLog2n: vDSP_Length    // = 9 (log2 512)
    private let hammingWindow: [Float]
    private let melFilterbank: [[Float]] // [nMelBins][nFFT/2 + 1]
    private let dctMatrix: [[Float]]     // [nCoeffs][nMelBins]

    // MARK: - Init

    /// Инициализирует экстрактор и кэширует все вычислительные структуры.
    /// Вызывать один раз — повторное создание не даёт выигрыша в скорости.
    public init() {
        // --- FFT setup (log2(512) = 9) ---
        let log2n = vDSP_Length(9)
        fftLog2n = log2n
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            fatalError("RealMFCCExtractor: не удалось создать vDSP FFT setup (log2n=9)")
        }
        fftSetup = setup

        // --- Hamming window [frameSize = 400] ---
        let frameN = Self.frameSize
        hammingWindow = (0 ..< frameN).map { i in
            0.54 - 0.46 * cos(2.0 * Float.pi * Float(i) / Float(frameN - 1))
        }

        // --- Mel filterbank [nMelBins][nFFT/2 + 1] ---
        let halfFFT = Self.nFFT / 2 + 1  // 257
        let melBins = Self.nMelBins       // 40
        let sr = Self.sampleRate          // 16000.0

        func hzToMel(_ hz: Double) -> Double { 2595.0 * log10(1.0 + hz / 700.0) }
        func melToHz(_ mel: Double) -> Double { 700.0 * (pow(10.0, mel / 2595.0) - 1.0) }

        let lowMel  = hzToMel(0.0)
        let highMel = hzToMel(sr / 2.0)

        // melBins + 2 точки (включая границы 0 и Nyquist)
        let melPoints = (0 ... melBins + 1).map { i in
            lowMel + (highMel - lowMel) * Double(i) / Double(melBins + 1)
        }
        let hzPoints = melPoints.map { melToHz($0) }
        // Бин FFT для каждой Hz-точки: bin = hz / (sr/2) * (nFFT/2)
        let binPoints = hzPoints.map { hz in
            min(Int(hz / (sr / 2.0) * Double(Self.nFFT / 2)), Self.nFFT / 2)
        }

        var filterbank = [[Float]](
            repeating: [Float](repeating: 0, count: halfFFT),
            count: melBins
        )
        for m in 0 ..< melBins {
            let lower  = binPoints[m]
            let center = binPoints[m + 1]
            let upper  = binPoints[m + 2]
            let leftWidth  = max(center - lower, 1)
            let rightWidth = max(upper - center, 1)
            for k in lower ..< center where k < halfFFT {
                filterbank[m][k] = Float(k - lower) / Float(leftWidth)
            }
            if center < halfFFT {
                filterbank[m][center] = 1.0
            }
            for k in (center + 1) ..< upper where k < halfFFT {
                filterbank[m][k] = Float(upper - k) / Float(rightWidth)
            }
        }
        melFilterbank = filterbank

        // --- DCT-II матрица [nCoeffs][nMelBins] ---
        let nC = Self.nCoeffs  // 13
        let nM = Self.nMelBins // 40
        let dctScale = Float(sqrt(2.0 / Double(nM)))
        dctMatrix = (0 ..< nC).map { k in
            (0 ..< nM).map { n in
                dctScale * cos(Float.pi * Float(k) * (Float(n) + 0.5) / Float(nM))
            }
        }
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    // MARK: - Public API

    /// Извлекает 39-мерный MFCC (13 base + 13 delta + 13 delta-delta) из сырого Float32 PCM.
    ///
    /// - Parameter audio: Float32 сэмплы @ 16 kHz mono
    /// - Returns: массив фреймов [[Float]], каждый — 39 коэффициентов
    public func extract(from audio: [Float]) -> [[Float]] {
        // 1. Pre-emphasis
        let emphasized = applyPreEmphasis(audio, alpha: 0.97)

        // 2-7. Framing → Hamming → FFT → Mel → Log → DCT
        var baseFrames: [[Float]] = []
        var frameStart = 0
        while frameStart + Self.frameSize <= emphasized.count {
            let frame = Array(emphasized[frameStart ..< frameStart + Self.frameSize])
            let windowed  = applyHammingWindow(frame)
            let magnitude = computeMagnitudeSpectrum(windowed)
            let melEnergies = applyMelFilterbank(magnitude)
            let logMel = melEnergies.map { log(max($0, 1e-10)) }
            let mfcc   = applyDCT(logMel)
            baseFrames.append(mfcc)
            frameStart += Self.hopSize
        }

        guard !baseFrames.isEmpty else { return [] }

        // 8. Delta + delta-delta → 39-мерный вектор
        return appendDeltas(baseFrames)
    }

    // MARK: - Pre-emphasis

    /// Применяет фильтр pre-emphasis: y[i] = x[i] - alpha * x[i-1].
    private func applyPreEmphasis(_ audio: [Float], alpha: Float) -> [Float] {
        guard audio.count > 1 else { return audio }
        var result = [Float](repeating: 0, count: audio.count)
        result[0] = audio[0]
        // Скалярный цикл: компилятор vectorize, корректнее чем vDSP_vsma для этого паттерна
        for i in 1 ..< audio.count {
            result[i] = audio[i] - alpha * audio[i - 1]
        }
        return result
    }

    // MARK: - Hamming Window

    private func applyHammingWindow(_ frame: [Float]) -> [Float] {
        var result = [Float](repeating: 0, count: frame.count)
        vDSP_vmul(frame, 1, hammingWindow, 1, &result, 1, vDSP_Length(frame.count))
        return result
    }

    // MARK: - FFT → Magnitude Spectrum

    /// Вычисляет амплитудный спектр через vDSP FFT (radix-2).
    /// - Returns: массив nFFT/2 + 1 значений амплитуды (257 бинов для nFFT=512)
    private func computeMagnitudeSpectrum(_ frame: [Float]) -> [Float] {
        let halfN   = Self.nFFT / 2      // 256
        let halfFFT = Self.nFFT / 2 + 1 // 257

        // Pad frame до nFFT=512 нулями
        var padded = [Float](repeating: 0, count: Self.nFFT)
        let copyLen = min(frame.count, Self.nFFT)
        for i in 0 ..< copyLen { padded[i] = frame[i] }

        // Разделяем на real/imag части (чётные индексы → real, нечётные → imag)
        var realPart = [Float](repeating: 0, count: halfN)
        var imagPart = [Float](repeating: 0, count: halfN)
        var magnitudes = [Float](repeating: 0, count: halfFFT)

        realPart.withUnsafeMutableBufferPointer { realBuf in
            imagPart.withUnsafeMutableBufferPointer { imagBuf in
                guard let rPtr = realBuf.baseAddress,
                      let iPtr = imagBuf.baseAddress else { return }

                var split = DSPSplitComplex(realp: rPtr, imagp: iPtr)

                padded.withUnsafeBufferPointer { paddedBuf in
                    guard let pPtr = paddedBuf.baseAddress else { return }
                    pPtr.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &split, 1, vDSP_Length(halfN))
                    }
                }

                // Forward FFT (результат в split-complex формате)
                vDSP_fft_zrip(fftSetup, &split, 1, fftLog2n, FFTDirection(FFT_FORWARD))

                // Амплитуды для бинов 0..<halfN через отдельный указатель
                magnitudes.withUnsafeMutableBufferPointer { magBuf in
                    guard let mPtr = magBuf.baseAddress else { return }
                    vDSP_zvabs(&split, 1, mPtr, 1, vDSP_Length(halfN))
                    // Бин Nyquist (halfN) хранится в imagp[0] по соглашению vDSP_fft_zrip
                    mPtr[halfN] = abs(iPtr[0])
                }
            }
        }

        // Нормализация: используем отдельный буфер (избегает overlapping access в vDSP_vsmul)
        var scale: Float = 1.0 / Float(Self.nFFT)
        var normalized = [Float](repeating: 0, count: halfFFT)
        vDSP_vsmul(magnitudes, 1, &scale, &normalized, 1, vDSP_Length(halfFFT))

        return normalized
    }

    // MARK: - Mel Filterbank

    private func applyMelFilterbank(_ magnitude: [Float]) -> [Float] {
        let halfFFT = Self.nFFT / 2 + 1
        let effectiveLen = min(magnitude.count, halfFFT)
        var energies = [Float](repeating: 0, count: Self.nMelBins)
        for m in 0 ..< Self.nMelBins {
            var energy: Float = 0
            vDSP_dotpr(magnitude, 1, melFilterbank[m], 1, &energy, vDSP_Length(effectiveLen))
            energies[m] = energy
        }
        return energies
    }

    // MARK: - DCT-II

    private func applyDCT(_ logMel: [Float]) -> [Float] {
        var coeffs = [Float](repeating: 0, count: Self.nCoeffs)
        for k in 0 ..< Self.nCoeffs {
            var sum: Float = 0
            vDSP_dotpr(logMel, 1, dctMatrix[k], 1, &sum, vDSP_Length(Self.nMelBins))
            coeffs[k] = sum
        }
        return coeffs
    }

    // MARK: - Delta + Delta-Delta

    /// Добавляет первую и вторую производные к базовым MFCC коэффициентам.
    /// Итоговый вектор: 13 base + 13 delta + 13 delta-delta = 39 коэффициентов.
    ///
    /// Формула (ETSI стандарт):
    ///   delta[t][c] = Σ(n=1..N) n * (frames[t+n][c] - frames[t-n][c]) / (2 * Σ(n=1..N) n²)
    private func appendDeltas(_ frames: [[Float]]) -> [[Float]] {
        let nFrames = frames.count
        let nC      = frames[0].count  // 13

        // Знаменатель: 2 * (1² + 2²) = 10 для deltaWindow=2
        var denom: Float = 0
        for n in 1 ... Self.deltaWindow { denom += Float(n * n) }
        denom *= 2.0

        // Delta фреймы
        var deltaFrames = [[Float]](
            repeating: [Float](repeating: 0, count: nC),
            count: nFrames
        )
        for t in 0 ..< nFrames {
            for n in 1 ... Self.deltaWindow {
                let prevIdx = max(0, t - n)
                let nextIdx = min(nFrames - 1, t + n)
                let weight  = Float(n) / denom
                for c in 0 ..< nC {
                    deltaFrames[t][c] += weight * (frames[nextIdx][c] - frames[prevIdx][c])
                }
            }
        }

        // Delta-delta фреймы (вторая производная по delta)
        var deltaDeltaFrames = [[Float]](
            repeating: [Float](repeating: 0, count: nC),
            count: nFrames
        )
        for t in 0 ..< nFrames {
            for n in 1 ... Self.deltaWindow {
                let prevIdx = max(0, t - n)
                let nextIdx = min(nFrames - 1, t + n)
                let weight  = Float(n) / denom
                for c in 0 ..< nC {
                    deltaDeltaFrames[t][c] += weight * (deltaFrames[nextIdx][c] - deltaFrames[prevIdx][c])
                }
            }
        }

        // Конкатенируем: [base(13) | delta(13) | delta-delta(13)] = 39
        return (0 ..< nFrames).map { t in
            frames[t] + deltaFrames[t] + deltaDeltaFrames[t]
        }
    }
}

// MARK: - RealMFCCExtractor + MFCCExtractorProtocol

extension RealMFCCExtractor: MFCCExtractorProtocol {

    /// Реализация протокола: извлекает 39-мерные MFCC фреймы из сырого Float32 PCM Data.
    /// - Parameter audio: сырой Float32 PCM Data, 16 kHz mono
    /// - Returns: массив фреймов [[Float]], каждый — 39 коэффициентов
    public func extract(from audio: Data) async throws -> [[Float]] {
        let floatCount = audio.count / MemoryLayout<Float>.size
        guard floatCount > 0 else {
            throw RealMFCCExtractorError.emptyAudio
        }

        let samples = audio.withUnsafeBytes { rawBytes -> [Float] in
            let floatPtr = rawBytes.bindMemory(to: Float.self)
            return Array(floatPtr)
        }

        let result = extract(from: samples)
        guard !result.isEmpty else {
            throw RealMFCCExtractorError.tooShort(sampleCount: floatCount)
        }
        return result
    }
}

// MARK: - RealMFCCExtractorError

/// Ошибки RealMFCCExtractor.
public enum RealMFCCExtractorError: LocalizedError, Sendable {
    case emptyAudio
    case tooShort(sampleCount: Int)

    public var errorDescription: String? {
        switch self {
        case .emptyAudio:
            return String(localized: "Аудио буфер пустой")
        case .tooShort(let count):
            return String(localized: "Аудио слишком короткое: \(count) сэмплов (минимум \(RealMFCCExtractor.frameSize))")
        }
    }
}
