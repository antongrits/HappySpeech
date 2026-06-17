import AVFoundation
import Foundation
import OSLog

// MARK: - VoiceStrongmanCapturing
//
// Абстракция реального захвата голоса для «Силача-голоса». Реальная
// реализация — `VoiceStrongmanAudioCapture` (AVAudioEngine tap). Тестовая —
// `MockVoiceStrongmanCapture` в тестах. Интерактор не знает об AVFoundation.
//
// За одну запись копит:
//   • RMS-кадры громкости (нормализованные 0…1) — для «звукового шара» и зоны;
//   • питч-контур (YIN, нормализованная высота) — для климбера на лесенке.

@MainActor
protocol VoiceStrongmanCapturing: AnyObject {
    /// Начать захват. Сбрасывает накопленные данные.
    func start() async throws
    /// Остановить захват.
    func stop()
    /// Текущий снимок live-данных (для UI-стрима).
    func liveSnapshot() async -> VoiceStrongmanSnapshot
    /// Итоговый снимок после остановки (все кадры громкости + контур).
    func finalSnapshot() async -> VoiceStrongmanSnapshot
}

// MARK: - VoiceStrongmanCaptureError

/// Типизированные ошибки захвата «Силача-голоса».
enum VoiceStrongmanCaptureError: Error, Equatable {
    /// Разрешение на микрофон не выдано (или отозвано в Настройках).
    case microphonePermissionDenied
}

/// Снимок захвата.
struct VoiceStrongmanSnapshot: Sendable, Equatable {
    /// Все нормализованные кадры громкости 0…1 за запись.
    let loudnessFrames: [Float]
    /// Сглаженная мгновенная громкость 0…1 (для live-шара).
    let loudness: Float
    /// Питч-контур (нормализованное время → частота).
    let contour: [PitchPoint]
    /// Сглаженная мгновенная нормализованная высота 0…1 (для live-климбера).
    let pitchNorm: Float

    static let empty = VoiceStrongmanSnapshot(
        loudnessFrames: [], loudness: 0, contour: [], pitchNorm: 0
    )
}

// MARK: - VoiceStrongmanAccumulator

/// Actor-protected буфер: безопасен из audio-tap (nonisolated) и MainActor.
actor VoiceStrongmanAccumulator {
    private var loudnessFrames: [Float] = []
    private var contour: [PitchPoint] = []
    private var smoothedLoudness: Float = 0
    private var smoothedPitchNorm: Float = 0

    private let pitchFloor: Double
    private let pitchCeil: Double

    init(pitchFloor: Double, pitchCeil: Double) {
        self.pitchFloor = pitchFloor
        self.pitchCeil = pitchCeil
    }

    func append(loudness: Float, frequencyHz: Double?, normalisedTime: Double) {
        loudnessFrames.append(loudness)
        // Экспоненциальное сглаживание для приятного движения шара.
        smoothedLoudness = max(loudness, smoothedLoudness * 0.55)
        contour.append(PitchPoint(time: normalisedTime, frequencyHz: frequencyHz))
        if let freq = frequencyHz, freq >= pitchFloor, freq <= pitchCeil {
            let norm = Float((freq - pitchFloor) / (pitchCeil - pitchFloor))
            smoothedPitchNorm = smoothedPitchNorm * 0.4 + min(max(norm, 0), 1) * 0.6
        }
    }

    func snapshot() -> VoiceStrongmanSnapshot {
        VoiceStrongmanSnapshot(
            loudnessFrames: loudnessFrames,
            loudness: smoothedLoudness,
            contour: contour,
            pitchNorm: smoothedPitchNorm
        )
    }

    func clear() {
        loudnessFrames.removeAll()
        contour.removeAll()
        smoothedLoudness = 0
        smoothedPitchNorm = 0
    }
}

// MARK: - VoiceStrongmanAudioCapture (live)

@MainActor
final class VoiceStrongmanAudioCapture: VoiceStrongmanCapturing {

    private let audioEngine = AVAudioEngine()
    private let tracker: YINPitchTracker
    private let accumulator: VoiceStrongmanAccumulator
    private let logger = Logger(subsystem: "ru.happyspeech", category: "VoiceStrongman.Capture")
    private var isRunning = false

    /// Ожидаемая длительность тянущегося гласного (сек) — для нормализации
    /// времени контура и доли глиссандо.
    private let expectedDurationSec: Double

    init(
        tracker: YINPitchTracker = YINPitchTracker(),
        expectedDurationSec: Double = 3.0,
        pitchFloor: Double = VoiceStrongmanScoring.pitchFloorHz,
        pitchCeil: Double = VoiceStrongmanScoring.pitchCeilHz
    ) {
        self.tracker = tracker
        self.expectedDurationSec = expectedDurationSec
        self.accumulator = VoiceStrongmanAccumulator(pitchFloor: pitchFloor, pitchCeil: pitchCeil)
    }

    func start() async throws {
        guard !isRunning else { return }
        // Без разрешения на запись tap отдаёт тишину → шар/лесенка не двигаются и
        // ребёнок молча получает 1★ без объяснения. Запрашиваем/проверяем доступ
        // к микрофону (как TongueTwisters/CarryoverVoiceNote) и при отказе бросаем
        // типизированную ошибку, чтобы UI показал понятное сообщение.
        guard await Self.ensureRecordPermission() else {
            logger.info("VoiceStrongman: микрофон не разрешён")
            throw VoiceStrongmanCaptureError.microphonePermissionDenied
        }
        await accumulator.clear()
        try configureSession()
        try startTap()
        isRunning = true
        logger.info("VoiceStrongman capture started")
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
        logger.info("VoiceStrongman capture stopped")
    }

    func liveSnapshot() async -> VoiceStrongmanSnapshot {
        await accumulator.snapshot()
    }

    func finalSnapshot() async -> VoiceStrongmanSnapshot {
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
            let loudness = Self.computeLoudness(samples)
            let freq = trackerRef.estimateFrequency(in: samples)
            let elapsed = Date().timeIntervalSince(startedAt)
            let normalisedTime = min(1.0, elapsed / duration)
            Task {
                await acc.append(loudness: loudness, frequencyHz: freq, normalisedTime: normalisedTime)
            }
        }
        audioEngine.prepare()
        try audioEngine.start()
    }

    /// RMS-громкость кадра, нормализованная в 0…1 с мягким усилением.
    /// Использует среднеквадратичное значение (RMS), а не среднее abs — это
    /// корректная метрика силы голоса (методика силы голоса по интенсивности).
    private static func computeLoudness(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sumSquares = samples.reduce(Float(0)) { $0 + $1 * $1 }
        let rms = (sumSquares / Float(samples.count)).squareRoot()
        // Перцептивное усиление: типичный детский тянущийся гласный даёт RMS
        // ~0.05…0.3; масштабируем так, чтобы средняя речь была в зоне.
        return min(1.0, rms * 6.0)
    }
}
