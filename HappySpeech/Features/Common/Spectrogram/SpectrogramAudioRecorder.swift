import AVFoundation
import Accelerate
import Combine
import OSLog

// MARK: - SpectrogramAudioRecorder

/// Сервис записи аудио с микрофона, публикующий спектрограммы в реальном времени.
///
/// Использует AVAudioEngine для захвата 16 kHz mono PCM, затем
/// применяет vDSP FFT-пайплайн (Hamming window + magnitude spectrum + Mel filterbank)
/// с целевой частотой 60 fps (frameSize=512, hopSize=256).
///
/// Класс помечен `@unchecked Sendable` т.к. AVAudioEngine не имеет
/// формального Sendable-conformance; мутации всегда происходят в async-контексте,
/// tap-замыкание работает только с Sendable-типами.
///
/// ## Использование
/// ```swift
/// let recorder = SpectrogramAudioRecorder()
/// let cancellable = recorder.spectrogramPublisher
///     .receive(on: DispatchQueue.main)
///     .sink { spectrogram in /* обновить UI */ }
/// try await recorder.startRecording()
/// await recorder.stopRecording()
/// ```
///
/// ## Безопасность
/// - Запрашивает доступ к микрофону перед стартом.
/// - Аудио не сохраняется на диск.
/// - Kid-circuit совместим (нет внешних сетевых вызовов).
///
/// ## See Also
/// - ``Spectrogram``
/// - ``SpectrogramVisualizerView``
public final class SpectrogramAudioRecorder: @unchecked Sendable {

    // MARK: - Public Publisher

    /// Публикует обновлённую спектрограмму по мере поступления аудио-кадров.
    public let spectrogramPublisher = PassthroughSubject<Spectrogram, Never>()

    // MARK: - Private: Audio Engine

    nonisolated(unsafe) private let audioEngine = AVAudioEngine()
    nonisolated(unsafe) private var isRecording = false

    // MARK: - Private: DSP Constants

    private let frameSize: Int = 512
    private let hopSize: Int = 256
    private let nMelBins: Int = 40
    private let targetSampleRate: Double = 16_000

    // MARK: - Private: DSP State

    nonisolated(unsafe) private var hammingWindow: [Float] = []
    nonisolated(unsafe) private var melFilterbank: [[Float]] = []
    nonisolated(unsafe) private var fftSetup: vDSP.FFT<DSPSplitComplex>?
    nonisolated(unsafe) private var realBuffer: [Float] = []
    nonisolated(unsafe) private var imagBuffer: [Float] = []

    // MARK: - Private: Accumulation

    nonisolated(unsafe) private var accumulatedSamples: [Float] = []
    nonisolated(unsafe) private var totalSamplesRecorded: Int = 0

    // MARK: - Logger

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SpectrogramAudioRecorder")

    // MARK: - Init

    public init() {
        setupDSP()
    }

    // MARK: - Public API

    /// Запускает запись с микрофона.
    /// - Throws: `SpectrogramError` если доступ к микрофону запрещён или движок не стартует.
    public func startRecording() async throws {
        guard !isRecording else { return }

        let granted = await requestMicrophonePermission()
        guard granted else {
            throw SpectrogramError.microphonePermissionDenied
        }

        try configureAudioSession()
        try configureInputTap()
        try audioEngine.start()
        isRecording = true
        accumulatedSamples = []
        totalSamplesRecorded = 0
        logger.info("SpectrogramAudioRecorder: запись запущена")
    }

    /// Останавливает запись и возвращает итоговую спектрограмму.
    @discardableResult
    public func stopRecording() -> Spectrogram {
        guard isRecording else { return .empty }
        isRecording = false

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        let finalSpectrogram = buildSpectrogram(from: accumulatedSamples)
        accumulatedSamples = []
        logger.info("SpectrogramAudioRecorder: запись остановлена, кадров=\(finalSpectrogram.frames.count)")
        return finalSpectrogram
    }

    // MARK: - Private: Setup

    private func setupDSP() {
        hammingWindow = makeHammingWindow(size: frameSize)
        melFilterbank = makeMelFilterbank(nMels: nMelBins, nFFT: frameSize, sampleRate: targetSampleRate)

        let log2n = vDSP_Length(log2(Double(frameSize)))
        fftSetup = vDSP.FFT(log2n: log2n, radix: .radix2, ofType: DSPSplitComplex.self)

        realBuffer = [Float](repeating: 0, count: frameSize / 2)
        imagBuffer = [Float](repeating: 0, count: frameSize / 2)
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setPreferredSampleRate(targetSampleRate)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func configureInputTap() throws {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        )
        guard let tapFormat = format else {
            throw SpectrogramError.audioFormatUnsupported
        }

        let hopCount = AVAudioFrameCount(hopSize)
        audioEngine.inputNode.installTap(
            onBus: 0,
            bufferSize: hopCount,
            format: tapFormat
        ) { [weak self] buffer, _ in
            guard let self else { return }
            let samples = self.extractSamples(from: buffer)
            self.processSamples(samples)
        }
    }

    // MARK: - Private: Processing

    private func processSamples(_ samples: [Float]) {
        accumulatedSamples.append(contentsOf: samples)
        totalSamplesRecorded += samples.count

        let spectrogram = buildSpectrogram(from: accumulatedSamples)
        spectrogramPublisher.send(spectrogram)
    }

    private func buildSpectrogram(from samples: [Float]) -> Spectrogram {
        var frames: [[Float]] = []
        let count = samples.count

        guard count >= frameSize else {
            return Spectrogram(frames: [], sampleRate: targetSampleRate, duration: 0)
        }

        var pos = 0
        while pos + frameSize <= count {
            let frameSlice = Array(samples[pos..<pos + frameSize])
            let melFrame = extractMelFrame(from: frameSlice)
            frames.append(melFrame)
            pos += hopSize
        }

        let duration = Double(count) / targetSampleRate
        return Spectrogram(frames: frames, sampleRate: targetSampleRate, duration: duration)
    }

    private func extractMelFrame(from frame: [Float]) -> [Float] {
        var windowed = applyHamming(frame)
        let magnitude = computeMagnitudeSpectrum(&windowed)
        let melEnergies = applyMelFilterbank(magnitude)
        return melEnergies.map { log10(max($0, 1e-10)) }
    }

    // MARK: - Private: DSP Primitives

    private func applyHamming(_ frame: [Float]) -> [Float] {
        var result = [Float](repeating: 0, count: frameSize)
        vDSP_vmul(frame, 1, hammingWindow, 1, &result, 1, vDSP_Length(frameSize))
        return result
    }

    private func computeMagnitudeSpectrum(_ windowed: inout [Float]) -> [Float] {
        guard let fft = fftSetup else { return [Float](repeating: 0, count: frameSize / 2) }

        var real = [Float](repeating: 0, count: frameSize / 2)
        var imag = [Float](repeating: 0, count: frameSize / 2)

        windowed.withUnsafeMutableBufferPointer { ptr in
            real.withUnsafeMutableBufferPointer { realPtr in
                imag.withUnsafeMutableBufferPointer { imagPtr in
                    var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                    ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: frameSize / 2) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &split, 1, vDSP_Length(frameSize / 2))
                    }
                    fft.forward(input: split, output: &split)
                }
            }
        }

        var magnitudes = [Float](repeating: 0, count: frameSize / 2)
        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(frameSize / 2))
            }
        }

        var scale = Float(1.0 / Float(frameSize))
        vDSP_vsmul(magnitudes, 1, &scale, &magnitudes, 1, vDSP_Length(frameSize / 2))

        return magnitudes
    }

    private func applyMelFilterbank(_ magnitudes: [Float]) -> [Float] {
        var melEnergies = [Float](repeating: 0, count: nMelBins)
        let fftBins = magnitudes.count

        for (melIdx, filterWeights) in melFilterbank.enumerated() {
            var energy: Float = 0
            let binsToProcess = min(filterWeights.count, fftBins)
            vDSP_dotpr(magnitudes, 1, filterWeights, 1, &energy, vDSP_Length(binsToProcess))
            melEnergies[melIdx] = energy
        }
        return melEnergies
    }

    // MARK: - Private: Filterbank Construction

    private func makeHammingWindow(size: Int) -> [Float] {
        var window = [Float](repeating: 0, count: size)
        vDSP_hamm_window(&window, vDSP_Length(size), 0)
        return window
    }

    private func makeMelFilterbank(nMels: Int, nFFT: Int, sampleRate: Double) -> [[Float]] {
        let fftBins = nFFT / 2
        let minMel = hzToMel(0)
        let maxMel = hzToMel(sampleRate / 2)
        let stepCount = nMels + 2

        let melPoints = (0..<stepCount).map { i -> Double in
            minMel + Double(i) * (maxMel - minMel) / Double(stepCount - 1)
        }
        let hzPoints = melPoints.map { melToHz($0) }
        let binPoints = hzPoints.map { Int(($0 / (sampleRate / 2)) * Double(fftBins)) }

        var filterbank = [[Float]](repeating: [Float](repeating: 0, count: fftBins), count: nMels)

        for m in 1...nMels {
            let left   = binPoints[m - 1]
            let center = binPoints[m]
            let right  = binPoints[m + 1]

            if center > left {
                for k in left..<center where k < fftBins {
                    filterbank[m - 1][k] = Float(Double(k - left) / Double(center - left))
                }
            }
            if right > center {
                for k in center..<right where k < fftBins {
                    filterbank[m - 1][k] = Float(Double(right - k) / Double(right - center))
                }
            }
        }
        return filterbank
    }

    private func hzToMel(_ hz: Double) -> Double {
        2595 * log10(1 + hz / 700)
    }

    private func melToHz(_ mel: Double) -> Double {
        700 * (pow(10, mel / 2595) - 1)
    }

    // MARK: - Private: Helpers

    private func extractSamples(from buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData else { return [] }
        let frameLength = Int(buffer.frameLength)
        return Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
    }

    private func requestMicrophonePermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }
}

// MARK: - SpectrogramError

/// Ошибки записи спектрограммы.
public enum SpectrogramError: LocalizedError {

    case microphonePermissionDenied
    case audioFormatUnsupported
    case engineStartFailed(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return String(localized: "spectrogram.error.mic_denied",
                          defaultValue: "Нет доступа к микрофону. Разреши доступ в Настройках.")
        case .audioFormatUnsupported:
            return String(localized: "spectrogram.error.format",
                          defaultValue: "Формат аудио не поддерживается на этом устройстве.")
        case .engineStartFailed(let err):
            return String(localized: "spectrogram.error.engine",
                          defaultValue: "Не удалось запустить микрофон: \(err.localizedDescription)")
        }
    }
}
