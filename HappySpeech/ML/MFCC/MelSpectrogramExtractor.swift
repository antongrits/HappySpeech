import Accelerate
import Foundation
import OSLog

// MARK: - MelSpectrogramExtractor

/// Извлекает log-mel spectrogram из 16 kHz mono PCM без DCT-преобразования.
///
/// Делит общий vDSP-пайплайн с ``RealMFCCExtractor`` (pre-emphasis → framing →
/// Hamming window → FFT → Mel filterbank → log), но останавливается **перед** DCT,
/// чтобы получить плотное частотно-временное представление.
///
/// ### Зачем отдельный экстрактор
///
/// `RealMFCCExtractor` оптимизирован под классификаторы фонем (39-dim вектор +
/// delta + delta-delta). Для:
/// - визуализации спектрограммы в `SpeechVisualizationView`
/// - cross-correlation с эталоном (rule-based детектор шипящих/свистящих)
/// - акустического сравнения «ребёнок vs эталон»
///
/// нужны именно log-mel энергии без DCT, так как DCT декорелирует и теряет
/// частотную локализацию.
///
/// ### Параметры (унифицированы с RealMFCCExtractor)
///
/// - SR: 16 kHz
/// - Frame: 400 сэмплов (25 мс)
/// - Hop: 160 сэмплов (10 мс)
/// - nFFT: 512
/// - nMelBins: 40
///
/// ### Производительность
///
/// 1 сек аудио @ 16 kHz: ~3-7 мс на iPhone 17 Pro (чисто vDSP, общая setup
/// кэшируется в `init`).
///
/// ## See Also
/// - ``RealMFCCExtractor`` (DCT-вариант для классификации)
/// - ``MelSpectrogram`` (структура результата)
/// - ``SpectrogramCrossCorrelator`` (сравнение с эталоном)
public actor MelSpectrogramExtractor {

    // MARK: - Constants (общие с RealMFCCExtractor)

    public static let sampleRate: Double = 16_000
    public static let frameSize: Int = 400
    public static let hopSize: Int = 160
    public static let nFFT: Int = 512
    public static let nMelBins: Int = 40

    // MARK: - Cached Setup

    nonisolated(unsafe) private let fftSetup: OpaquePointer
    private let fftLog2n: vDSP_Length
    private let hammingWindow: [Float]
    private let melFilterbank: [[Float]]

    private let logger = Logger(subsystem: "ru.happyspeech", category: "MelSpectrogram")

    // MARK: - Init

    public init() {
        // FFT setup для nFFT = 512 → log2 = 9
        let log2n = vDSP_Length(9)
        fftLog2n = log2n
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            fatalError("MelSpectrogramExtractor: не удалось создать vDSP FFT setup")
        }
        fftSetup = setup

        // Hamming window
        let frameN = Self.frameSize
        hammingWindow = (0 ..< frameN).map { i in
            0.54 - 0.46 * cos(2.0 * Float.pi * Float(i) / Float(frameN - 1))
        }

        // Mel filterbank (тождественный RealMFCCExtractor)
        let halfFFT = Self.nFFT / 2 + 1
        let melBins = Self.nMelBins
        let sr = Self.sampleRate

        func hzToMel(_ hz: Double) -> Double { 2595.0 * log10(1.0 + hz / 700.0) }
        func melToHz(_ mel: Double) -> Double { 700.0 * (pow(10.0, mel / 2595.0) - 1.0) }

        let lowMel = hzToMel(0.0)
        let highMel = hzToMel(sr / 2.0)
        let melPoints = (0 ... melBins + 1).map { i in
            lowMel + (highMel - lowMel) * Double(i) / Double(melBins + 1)
        }
        let hzPoints = melPoints.map { melToHz($0) }
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
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    // MARK: - Public API

    /// Извлекает log-mel spectrogram из Float32 PCM.
    ///
    /// - Parameter audio: 16 kHz mono Float32 сэмплы
    /// - Returns: ``MelSpectrogram`` с временными кадрами `[time][40]`
    public func extract(from audio: [Float]) -> MelSpectrogram {
        let emphasized = applyPreEmphasis(audio, alpha: 0.97)

        var frames: [[Float]] = []
        var frameStart = 0
        while frameStart + Self.frameSize <= emphasized.count {
            let frame = Array(emphasized[frameStart ..< frameStart + Self.frameSize])
            let windowed = applyHammingWindow(frame)
            let magnitude = computeMagnitudeSpectrum(windowed)
            let melEnergies = applyMelFilterbank(magnitude)
            let logMel = melEnergies.map { log(max($0, 1e-10)) }
            frames.append(logMel)
            frameStart += Self.hopSize
        }

        let duration = Double(audio.count) / Self.sampleRate
        return MelSpectrogram(
            frames: frames,
            sampleRate: Self.sampleRate,
            duration: duration
        )
    }

    /// Извлекает log-mel spectrogram из сырого PCM `Data`.
    public func extract(from audio: Data) async throws -> MelSpectrogram {
        let floatCount = audio.count / MemoryLayout<Float>.size
        guard floatCount > 0 else {
            throw MelSpectrogramError.emptyAudio
        }
        let samples = audio.withUnsafeBytes { rawBytes -> [Float] in
            let floatPtr = rawBytes.bindMemory(to: Float.self)
            return Array(floatPtr)
        }
        return extract(from: samples)
    }

    // MARK: - DSP Steps (внутренние, унифицированы с RealMFCCExtractor)

    private func applyPreEmphasis(_ audio: [Float], alpha: Float) -> [Float] {
        guard audio.count > 1 else { return audio }
        var result = [Float](repeating: 0, count: audio.count)
        result[0] = audio[0]
        for i in 1 ..< audio.count {
            result[i] = audio[i] - alpha * audio[i - 1]
        }
        return result
    }

    private func applyHammingWindow(_ frame: [Float]) -> [Float] {
        var result = [Float](repeating: 0, count: frame.count)
        vDSP_vmul(frame, 1, hammingWindow, 1, &result, 1, vDSP_Length(frame.count))
        return result
    }

    // swiftlint:disable function_body_length
    private func computeMagnitudeSpectrum(_ frame: [Float]) -> [Float] {
        let halfN = Self.nFFT / 2
        let halfFFT = Self.nFFT / 2 + 1

        var padded = [Float](repeating: 0, count: Self.nFFT)
        let copyLen = min(frame.count, Self.nFFT)
        for i in 0 ..< copyLen { padded[i] = frame[i] }

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

                vDSP_fft_zrip(fftSetup, &split, 1, fftLog2n, FFTDirection(FFT_FORWARD))

                magnitudes.withUnsafeMutableBufferPointer { magBuf in
                    guard let mPtr = magBuf.baseAddress else { return }
                    vDSP_zvabs(&split, 1, mPtr, 1, vDSP_Length(halfN))
                    mPtr[halfN] = abs(iPtr[0])
                }
            }
        }

        var scale: Float = 1.0 / Float(Self.nFFT)
        var normalized = [Float](repeating: 0, count: halfFFT)
        vDSP_vsmul(magnitudes, 1, &scale, &normalized, 1, vDSP_Length(halfFFT))

        return normalized
    }
    // swiftlint:enable function_body_length

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
}

// MARK: - MelSpectrogram

/// Иммутабельный результат извлечения log-mel спектрограммы.
///
/// Совместим по структуре с ``Spectrogram`` (40 mel-бинов на кадр), но содержит
/// логарифмированные энергии (не нормализованные), что лучше подходит для
/// акустического сравнения через cross-correlation.
public struct MelSpectrogram: Sendable, Equatable {

    /// Временные кадры: `[time][40]`, log-mel энергии.
    public let frames: [[Float]]

    /// Частота дискретизации источника.
    public let sampleRate: Double

    /// Длительность аудио в секундах.
    public let duration: TimeInterval

    public init(frames: [[Float]], sampleRate: Double, duration: TimeInterval) {
        self.frames = frames
        self.sampleRate = sampleRate
        self.duration = duration
    }

    /// Число mel-бинов (всегда 40, унифицировано с пайплайном).
    public static let melBinCount: Int = 40

    /// Пустая спектрограмма — безопасный дефолт.
    public static let empty = MelSpectrogram(frames: [], sampleRate: 16_000, duration: 0)

    /// Конвертирует в ``Spectrogram`` (структура для UI-рендера).
    ///
    /// При необходимости нормализуем log-mel в диапазон, ожидаемый
    /// `SpectrogramRenderConfig` (логMin -3, логMax 3).
    public var asUISpectrogram: Spectrogram {
        Spectrogram(frames: frames, sampleRate: sampleRate, duration: duration)
    }
}

// MARK: - MelSpectrogramError

public enum MelSpectrogramError: LocalizedError, Sendable {
    case emptyAudio

    public var errorDescription: String? {
        switch self {
        case .emptyAudio:
            return String(localized: "Аудио буфер пустой")
        }
    }
}
