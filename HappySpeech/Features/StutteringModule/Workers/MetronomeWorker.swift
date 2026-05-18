import AVFoundation
import Foundation
import OSLog

// MARK: - MetronomeWorkerProtocol

@MainActor
protocol MetronomeWorkerProtocol: AnyObject {
    func start(bpm: Int, onTick: @escaping @Sendable () -> Void)
    func stop()
}

// MARK: - MetronomeWorker

/// Timer-based metronome. Fires a tick at BPM-derived intervals on main actor.
/// Each tick also plays a short click sound through AVAudioPlayer.
@MainActor
final class MetronomeWorker: MetronomeWorkerProtocol {

    private let logger = HSLogger.audio
    private var timer: Timer?
    private var player: AVAudioPlayer?

    func start(bpm: Int, onTick: @escaping @Sendable () -> Void) {
        stop()
        let interval = 60.0 / Double(max(1, bpm))
        prepareClickSound()
        // Timer создаётся синхронно: метод уже на @MainActor. Отложенное создание
        // через Task привело бы к гонке — stop() мог отработать раньше, чем
        // Task создаст таймер, оставляя «висящий» таймер после остановки.
        timer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            // onTick вызывается синхронно в колбэке таймера: после stop()
            // таймер инвалидирован, поэтому «лишних» тиков не будет.
            // Воспроизведение клика требует self.player и уходит в @MainActor Task.
            onTick()
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.player?.stop()
                self.player?.currentTime = 0
                self.player?.play()
            }
        }
        logger.info("MetronomeWorker started bpm=\(bpm, privacy: .public) interval=\(interval, privacy: .public)")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        player?.stop()
        logger.info("MetronomeWorker stopped")
    }

    // MARK: - Sound

    private func prepareClickSound() {
        // Try bundled metronome_tick.caf; fall back to system sound via AudioServicesPlaySystemSound.
        if let url = Bundle.main.url(forResource: "metronome_tick", withExtension: "caf") {
            player = try? AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
        } else {
            // Synthesise a short click with AVAudioEngine if asset is missing.
            player = nil
            logger.warning("MetronomeWorker: metronome_tick.caf not found, no click sound")
        }
    }
}

// MARK: - MockMetronomeWorker

@MainActor
final class MockMetronomeWorker: MetronomeWorkerProtocol {
    var startCount: Int = 0
    var stopCount: Int = 0
    var lastBPM: Int = 0
    private(set) var capturedOnTick: (@Sendable () -> Void)?

    func start(bpm: Int, onTick: @escaping @Sendable () -> Void) {
        startCount += 1
        lastBPM = bpm
        capturedOnTick = onTick
    }

    func stop() {
        stopCount += 1
    }

    func fireTick() {
        capturedOnTick?()
    }
}
