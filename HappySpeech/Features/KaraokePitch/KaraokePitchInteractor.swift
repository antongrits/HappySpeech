import AVFoundation
import Foundation
import OSLog

// MARK: - KaraokePitchInteractor
//
// Бизнес-логика караоке-сессии:
//   • буферизация микрофона через AVAudioEngine (separate engine, не AudioService,
//     потому что AudioService используется для записи файла, а нам нужен
//     real-time tap без файла);
//   • разрезание потока на окна 2048 семплов (≈128 мс), оценка F0 через
//     `YINPitchTracker`;
//   • публикация point'а в live-контур через presenter;
//   • при остановке — сравнение с эталоном через `ContourComparator`,
//     генерация Score-Response.
//
// Концурренси: класс — @MainActor (Interactor живёт в View), но microphone
// callback — отдельный nonisolated блок (AVAudioEngine tap callback). Поэтому
// внутренний sample-аккумулятор — actor-protected.

@MainActor
final class KaraokePitchInteractor {

    private let presenter: KaraokePitchPresenter
    private let pitchAccumulator: PitchAccumulator
    private let audioEngine = AVAudioEngine()
    private let tracker: YINPitchTracker
    private let comparator: ContourComparator
    private let logger = Logger(subsystem: "ru.happyspeech", category: "Karaoke.Interactor")

    private var phrases: [KaraokePhrase] = []
    private var currentIndex: Int = 0
    private var currentPhrase: KaraokePhrase?
    private var currentModelContour: [PitchPoint] = []
    private var isRecording: Bool = false
    private var liveSampleTask: Task<Void, Never>?

    /// Количество фраз в одной сессии.
    let sessionPhraseCount: Int

    // MARK: - Init

    init(
        presenter: KaraokePitchPresenter,
        sessionPhraseCount: Int = 5,
        tracker: YINPitchTracker = YINPitchTracker(),
        comparator: ContourComparator = ContourComparator()
    ) {
        self.presenter = presenter
        self.sessionPhraseCount = sessionPhraseCount
        self.tracker = tracker
        self.comparator = comparator
        self.pitchAccumulator = PitchAccumulator()
    }

    // Останов AVAudioEngine выполняется явно через `stopRecording()` —
    // в Swift 6 deinit @MainActor-класса nonisolated, поэтому трогать
    // AVAudioEngine (non-Sendable) оттуда нельзя.

    // MARK: - Lifecycle

    /// Начать сессию: выбрать первые `sessionPhraseCount` фраз из корпуса.
    func startSession() async {
        let pool = KaraokePitchCorpus.phrases
        phrases = Array(pool.shuffled().prefix(sessionPhraseCount))
        if phrases.isEmpty {
            logger.error("KaraokePitchCorpus empty — falling back to seed.")
            phrases = [
                .init(id: "kr-fallback",
                      text: "Сегодня хорошая погода.",
                      intonation: "statement",
                      intonationSymbol: "minus")
            ]
        }
        currentIndex = 0
        await presentCurrentPhrase()
    }

    /// Запустить запись и реальный pitch-трекер.
    func startRecording() async {
        guard !isRecording, currentPhrase != nil else { return }
        await pitchAccumulator.clear()
        do {
            try configureAudioSession()
            try startAudioTap()
            isRecording = true
            startLiveStream()
            logger.info("Karaoke recording started.")
        } catch {
            logger.error("Failed to start audio tap: \(error.localizedDescription)")
        }
    }

    /// Остановить запись и посчитать score.
    func stopRecording() async {
        guard isRecording else { return }
        isRecording = false
        liveSampleTask?.cancel()
        liveSampleTask = nil
        stopAudioTap()
        await emitScore()
    }

    /// Перейти к следующей фразе. Возвращает `true` если сессия не окончена.
    @discardableResult
    func advanceToNext() async -> Bool {
        guard currentIndex + 1 < phrases.count else { return false }
        currentIndex += 1
        await presentCurrentPhrase()
        return true
    }

    /// Состояние записи (для view).
    func recordingState() -> Bool { isRecording }

    // MARK: - Private

    private func presentCurrentPhrase() async {
        guard currentIndex < phrases.count else { return }
        let phrase = phrases[currentIndex]
        let model = KaraokePitchCorpus.modelContour(for: phrase)
        currentPhrase = phrase
        currentModelContour = model
        await presenter.presentStart(
            response: .init(phrase: phrase, modelContour: model, totalPhrases: phrases.count)
        )
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
        try session.setActive(true, options: [])
    }

    private func startAudioTap() throws {
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        let bufferSize: AVAudioFrameCount = 2048
        let accumulator = pitchAccumulator
        let trackerRef = tracker
        let sampleRate = format.sampleRate
        let startedAt = Date()

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: bufferSize, format: format) { buffer, _ in
            guard let channels = buffer.floatChannelData else { return }
            let samples = Array(UnsafeBufferPointer(start: channels[0],
                                                    count: Int(buffer.frameLength)))
            let amplitude = computeAmplitude(samples)
            let freq = trackerRef.estimateFrequency(in: samples)
            let elapsed = Date().timeIntervalSince(startedAt)
            // Нормализуем по 2.5 сек — длительность ожидаемой фразы.
            let normalisedTime = min(1.0, elapsed / 2.5)
            Task {
                await accumulator.append(
                    point: PitchPoint(time: normalisedTime, frequencyHz: freq),
                    amplitude: amplitude,
                    sampleRate: sampleRate
                )
            }
        }
        audioEngine.prepare()
        try audioEngine.start()
    }

    private func stopAudioTap() {
        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning { audioEngine.stop() }
    }

    private func startLiveStream() {
        liveSampleTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled, await self.isStillRecording() {
                let snapshot = await self.pitchAccumulator.snapshot()
                await self.presenter.presentLiveSample(
                    response: .init(liveContour: snapshot.points,
                                    amplitude: snapshot.amplitude)
                )
                try? await Task.sleep(nanoseconds: 80_000_000)
            }
        }
    }

    private func isStillRecording() async -> Bool { isRecording }

    private func emitScore() async {
        guard let phrase = currentPhrase else { return }
        let snapshot = await pitchAccumulator.snapshot()
        let similarity = comparator.similarity(model: currentModelContour, live: snapshot.points)
        let stars = comparator.stars(for: similarity)
        await presenter.presentScore(
            response: .init(
                phrase: phrase,
                modelContour: currentModelContour,
                liveContour: snapshot.points,
                similarity: similarity,
                starsEarned: stars
            )
        )
    }
}

// MARK: - PitchAccumulator

/// Actor-protected буфер pitch-точек. Безопасен из audio-tap (nonisolated)
/// и из MainActor.
actor PitchAccumulator {

    private var points: [PitchPoint] = []
    private var amplitude: Float = 0

    func append(point: PitchPoint, amplitude amp: Float, sampleRate _: Double) {
        points.append(point)
        amplitude = max(amp, amplitude * 0.6)  // плавный спад
    }

    func snapshot() -> (points: [PitchPoint], amplitude: Float) {
        (points, amplitude)
    }

    func clear() {
        points.removeAll()
        amplitude = 0
    }
}

// MARK: - Helpers (nonisolated)

private func computeAmplitude(_ samples: [Float]) -> Float {
    guard !samples.isEmpty else { return 0 }
    let sum = samples.reduce(Float(0)) { $0 + abs($1) }
    return min(1.0, (sum / Float(samples.count)) * 4)
}
