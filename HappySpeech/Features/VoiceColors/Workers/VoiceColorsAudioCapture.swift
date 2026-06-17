import AVFoundation
import Foundation
import OSLog

// MARK: - VoiceCaptureControlling
//
// Абстракция реального захвата голоса для «Голосовых красок». Реальная
// реализация — `VoiceColorsAudioCapture` (AVAudioEngine tap). Тестовая —
// `MockVoiceCapture` в тестах. Интерактор не знает об AVFoundation.
//
// За одну запись копит:
//   • pitch-контур (YIN, для режима интонации);
//   • амплитудную огибающую (RMS-кадры, для режима ударения);
//   • PCM Float32 16kHz mono Data (для EmotionDetection в режиме эмоции).

@MainActor
protocol VoiceCaptureControlling: AnyObject {
    /// Начать захват. Сбрасывает накопленные данные.
    func start() async throws
    /// Остановить захват.
    func stop()
    /// Текущий снимок live-данных (для UI-стрима).
    func liveSnapshot() async -> VoiceCaptureSnapshot
    /// Итоговый снимок после остановки (контур + огибающая + PCM).
    func finalSnapshot() async -> VoiceCaptureSnapshot
}

// MARK: - VoiceCaptureError

/// Типизированные ошибки захвата «Голосовых красок».
enum VoiceCaptureError: Error, Equatable {
    /// Разрешение на микрофон не выдано (или отозвано в Настройках).
    case microphonePermissionDenied
}

/// Снимок захвата.
struct VoiceCaptureSnapshot: Sendable, Equatable {
    let contour: [PitchPoint]
    let amplitudeEnvelope: [Float]
    let amplitude: Float
    let pcmData: Data

    static let empty = VoiceCaptureSnapshot(
        contour: [], amplitudeEnvelope: [], amplitude: 0, pcmData: Data()
    )
}

// MARK: - VoiceCaptureAccumulator

/// Actor-protected буфер: безопасен из audio-tap (nonisolated) и MainActor.
actor VoiceCaptureAccumulator {
    private var contour: [PitchPoint] = []
    private var envelope: [Float] = []
    private var pcm = Data()
    private var amplitude: Float = 0

    func append(point: PitchPoint, amplitude amp: Float, pcmChunk: Data) {
        contour.append(point)
        envelope.append(amp)
        pcm.append(pcmChunk)
        amplitude = max(amp, amplitude * 0.6)
    }

    func snapshot() -> VoiceCaptureSnapshot {
        VoiceCaptureSnapshot(
            contour: contour, amplitudeEnvelope: envelope,
            amplitude: amplitude, pcmData: pcm
        )
    }

    func clear() {
        contour.removeAll()
        envelope.removeAll()
        pcm.removeAll()
        amplitude = 0
    }
}

// MARK: - VoiceColorsAudioCapture (live)

@MainActor
final class VoiceColorsAudioCapture: VoiceCaptureControlling {

    private let audioEngine = AVAudioEngine()
    private let tracker: YINPitchTracker
    private let accumulator = VoiceCaptureAccumulator()
    private let logger = Logger(subsystem: "ru.happyspeech", category: "VoiceColors.Capture")
    private var isRunning = false

    /// Ожидаемая длительность фразы (сек) — для нормализации времени контура.
    private let expectedDurationSec: Double

    init(tracker: YINPitchTracker = YINPitchTracker(), expectedDurationSec: Double = 2.5) {
        self.tracker = tracker
        self.expectedDurationSec = expectedDurationSec
    }

    func start() async throws {
        guard !isRunning else { return }
        // Без разрешения на запись `installTap` на input с нулевым числом каналов
        // бросает NSException (не ловится Swift try) → краш игры, запускаемой
        // прямо из ChildHome. Проверяем/запрашиваем доступ к микрофону ДО tap
        // (как VoiceStrongman) и при отказе бросаем типизированную ошибку, чтобы
        // UI показал понятное сообщение вместо падения.
        guard await Self.ensureRecordPermission() else {
            logger.info("VoiceColors: микрофон не разрешён")
            throw VoiceCaptureError.microphonePermissionDenied
        }
        await accumulator.clear()
        try configureSession()
        try startTap()
        isRunning = true
        logger.info("VoiceColors capture started")
    }

    /// Возвращает true, если доступ к микрофону есть; при `.undetermined`
    /// запрашивает системно (iOS 17+ `AVAudioApplication`).
    private static func ensureRecordPermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await AVAudioApplication.requestRecordPermission()
        @unknown default:
            return await AVAudioApplication.requestRecordPermission()
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning { audioEngine.stop() }
        logger.info("VoiceColors capture stopped")
    }

    func liveSnapshot() async -> VoiceCaptureSnapshot {
        await accumulator.snapshot()
    }

    func finalSnapshot() async -> VoiceCaptureSnapshot {
        await accumulator.snapshot()
    }

    // MARK: - Private

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
        try session.setActive(true, options: [])
    }

    private func startTap() throws {
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        let bufferSize: AVAudioFrameCount = 2048
        let acc = accumulator
        let trackerRef = tracker
        let duration = expectedDurationSec
        let startedAt = Date()

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: bufferSize, format: format) { buffer, _ in
            guard let channels = buffer.floatChannelData else { return }
            let frameCount = Int(buffer.frameLength)
            let samples = Array(UnsafeBufferPointer(start: channels[0], count: frameCount))
            let amplitude = Self.computeAmplitude(samples)
            let freq = trackerRef.estimateFrequency(in: samples)
            let elapsed = Date().timeIntervalSince(startedAt)
            let normalisedTime = min(1.0, elapsed / duration)
            // Float32 PCM-chunk (для EmotionDetection — копируем ДО async-границы).
            let pcmChunk = Data(bytes: channels[0], count: frameCount * MemoryLayout<Float>.size)
            Task {
                await acc.append(
                    point: PitchPoint(time: normalisedTime, frequencyHz: freq),
                    amplitude: amplitude,
                    pcmChunk: pcmChunk
                )
            }
        }
        audioEngine.prepare()
        try audioEngine.start()
    }

    private static func computeAmplitude(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sum = samples.reduce(Float(0)) { $0 + abs($1) }
        return min(1.0, (sum / Float(samples.count)) * 4)
    }
}
