import AVFoundation
import Foundation
import OSLog

// MARK: - LogorhythmicsClock
//
// Абстракция над `ContinuousClock` для тестируемости. В production —
// `LogorhythmicsContinuousClock`. В тестах — `MockClock` (см.
// LogorhythmicsTests). Имя префиксное, чтобы не конфликтовать с другими
// «Clock»-типами в проекте.

protocol LogorhythmicsClock: Sendable {
    /// Текущее время в секундах от условного нуля.
    func now() -> Double
    /// Подождать `seconds` секунд (или меньше, если прервалось).
    func sleep(seconds: Double) async throws
}

struct LogorhythmicsContinuousClock: LogorhythmicsClock {
    func now() -> Double {
        let nanos = DispatchTime.now().uptimeNanoseconds
        return Double(nanos) / 1_000_000_000
    }

    func sleep(seconds: Double) async throws {
        let nanos = UInt64(max(0, seconds) * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanos)
    }
}

// MARK: - LogorhythmicsMetronomeWorker
//
// Воспроизводит клик-track для chant-упражнения. Программная генерация
// синусоидального burst'а (sin-burst 1 кГц для сильной доли, 800 Гц для
// слабой, длительность 30 мс, экспоненциальный envelope).
//
// Поднимает AVAudioSession `.playback` на время сессии и деактивирует
// при stop — не модифицирует общий `AudioService` (CTO-decision-default
// Wave F Ф.7).
//
// Каждый beat-старт публикует `BeatEvent` через AsyncStream — это даёт
// View пульсацию и Interactor — событие для timeline сравнения с tap'ами.
//
// Имя префиксное, чтобы не конфликтовать с `MetronomeWorker` из
// `Features/StutteringModule`.

@MainActor
final class LogorhythmicsMetronomeWorker {

    // MARK: - Types

    struct BeatEvent: Sendable {
        let beatIndex: Int
        let isStrong: Bool
        /// Время старта beat'а (секунды от начала упражнения).
        let timeSeconds: Double
    }

    // MARK: - Dependencies

    private let clock: any LogorhythmicsClock
    private let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "Logorhythmics.Metronome"
    )

    // MARK: - State

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var strongClickBuffer: AVAudioPCMBuffer?
    private var weakClickBuffer: AVAudioPCMBuffer?
    private var streamContinuation: AsyncStream<BeatEvent>.Continuation?
    private var beatStream: AsyncStream<BeatEvent>?
    private var sessionTask: Task<Void, Never>?
    private var didActivateSession: Bool = false
    /// Время старта упражнения (от clock.now()).
    private var startTime: Double = 0

    // MARK: - Init

    init(clock: any LogorhythmicsClock = LogorhythmicsContinuousClock()) {
        self.clock = clock
    }

    // MARK: - Public

    /// Возвращает stream beat-событий. Один stream на жизнь воркера.
    func beatEvents() -> AsyncStream<BeatEvent> {
        if let existing = beatStream { return existing }
        let stream = AsyncStream<BeatEvent> { continuation in
            self.streamContinuation = continuation
        }
        self.beatStream = stream
        return stream
    }

    /// Запускает метроном по паттерну упражнения. Каждый beat:
    ///   1) пушит BeatEvent в stream,
    ///   2) играет клик (sin-burst).
    ///
    /// Возвращает после завершения последнего beat'а или до отмены.
    func start(exercise: LogorhythmicsExercise) {
        stop() // safety — отменим предыдущую сессию.
        prepareAudioIfNeeded(for: exercise.bpm)
        startTime = clock.now()
        let strongSet = Set(exercise.strongBeats)
        let beatDuration = exercise.beatDurationSeconds

        sessionTask = Task { [weak self] in
            guard let self else { return }
            for (i, dur) in exercise.pattern.enumerated() {
                if Task.isCancelled { return }
                let isStrong = strongSet.contains(i)
                let timeFromStart = await self.elapsed()
                let event = BeatEvent(
                    beatIndex: i,
                    isStrong: isStrong,
                    timeSeconds: timeFromStart
                )
                await self.emit(event: event, strong: isStrong)
                let sleepDuration = Double(dur) * beatDuration
                do {
                    try await self.clock.sleep(seconds: sleepDuration)
                } catch {
                    return
                }
            }
            await self.streamContinuation?.finish()
        }
    }

    /// Останов метронома и деактивация AVAudioSession.
    func stop() {
        sessionTask?.cancel()
        sessionTask = nil
        if engine.isRunning {
            player.stop()
            engine.stop()
        }
        if didActivateSession {
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            } catch {
                logger.error("AVAudioSession deactivate failed: \(error.localizedDescription)")
            }
            didActivateSession = false
        }
    }

    /// Только для тестов — текущее время от старта упражнения.
    func elapsed() -> Double {
        clock.now() - startTime
    }

    // MARK: - Private

    private func emit(event: BeatEvent, strong: Bool) {
        streamContinuation?.yield(event)
        playClick(strong: strong)
    }

    private func prepareAudioIfNeeded(for bpm: Int) {
        // 1. Активируем AVAudioSession (.playback).
        if !didActivateSession {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try session.setActive(true)
                didActivateSession = true
            } catch {
                logger.error("AVAudioSession activate failed: \(error.localizedDescription)")
                return
            }
        }
        // 2. Готовим буферы (один раз).
        if strongClickBuffer == nil {
            strongClickBuffer = makeClickBuffer(frequency: 1000, durationSeconds: 0.030)
        }
        if weakClickBuffer == nil {
            weakClickBuffer = makeClickBuffer(frequency: 800, durationSeconds: 0.030)
        }
        // 3. Подключаем player → mixer.
        guard let buf = strongClickBuffer else { return }
        if !engine.attachedNodes.contains(player) {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: buf.format)
        }
        // 4. Стартуем engine.
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                logger.error("AVAudioEngine start failed: \(error.localizedDescription)")
            }
        }
        _ = bpm // bpm-knob для будущей подстройки громкости
    }

    private func playClick(strong: Bool) {
        guard engine.isRunning else { return }
        let buffer = strong ? strongClickBuffer : weakClickBuffer
        guard let buffer else { return }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !player.isPlaying {
            player.play()
        }
    }

    /// Программная генерация sin-burst клика с экспоненциальным envelope.
    private func makeClickBuffer(frequency: Double, durationSeconds: Double) -> AVAudioPCMBuffer? {
        let sampleRate: Double = 44_100
        let frameCount = AVAudioFrameCount(sampleRate * durationSeconds)
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        ) else {
            return nil
        }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        buffer.frameLength = frameCount
        guard let channel = buffer.floatChannelData?[0] else { return nil }
        let omega = 2.0 * Double.pi * frequency / sampleRate
        // Exponential envelope: amp(t) = exp(-k * t / duration), k=6.
        let kDecay: Double = 6
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let envelope = exp(-kDecay * t / durationSeconds)
            let sample = sin(omega * Double(i)) * envelope
            channel[i] = Float(sample * 0.55) // громкость 55%
        }
        return buffer
    }
}
