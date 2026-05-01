import AVFoundation
import Combine
import OSLog
import SwiftUI

// MARK: - LyalyaLipSyncCoordinator

/// Координирует real-time lip-sync маскота через `AVAudioPlayer.averagePower`.
///
/// Поток данных:
///   `AVAudioPlayer.averagePower` (dB) → нормализация (-50..0 dB → 0..1) →
///   low-pass фильтр (α = 0.25) → `mouthOpen` →
///   опциональный phoneme-timing lookup → `viseme`
///
/// Использование:
/// ```swift
/// let lipSync = LyalyaLipSyncCoordinator()
///
/// // Воспроизведение с автоматическим lip-sync
/// try lipSync.playSpeech(audio: audioURL)
///
/// // Передача в LyalyaRealityKitView
/// LyalyaRealityKitView(
///     state: .explaining,
///     mouthOpen: lipSync.mouthOpen,
///     viseme: lipSync.viseme
/// )
/// ```
///
/// ## See Also
/// - ``LyalyaRealityKitView``
/// - ``LyalyaViseme``
@MainActor
public final class LyalyaLipSyncCoordinator: ObservableObject {

    // MARK: - Published state

    /// Открытость рта 0.0–1.0 (сглаженное через low-pass фильтр).
    @Published public private(set) var mouthOpen: Float = 0

    /// Текущая визема — рассчитывается из phoneme timings или из амплитуды.
    @Published public private(set) var viseme: LyalyaViseme = .rest

    // MARK: - Private state

    private var audioPlayer: AVAudioPlayer?
    private var displayLink: CADisplayLink?
    private var phonemeTimings: [PhonemeTimestamp] = []

    private let logger = Logger(subsystem: "ru.happyspeech", category: "LyalyaLipSyncCoordinator")

    // MARK: - Types

    /// Таймкод-привязанная визема для точного фонемного lip-sync.
    public struct PhonemeTimestamp: Sendable {
        public let time: TimeInterval
        public let viseme: LyalyaViseme

        public init(time: TimeInterval, viseme: LyalyaViseme) {
            self.time = time
            self.viseme = viseme
        }
    }

    // MARK: - Init

    public init() {}

    // MARK: - Public API

    /// Начать воспроизведение аудио с синхронизацией рта.
    ///
    /// - Parameters:
    ///   - url: URL аудио-файла (m4a, wav, caf из Bundle или Documents).
    ///   - phonemeTimings: Опциональные тайм-коды визем. Если пусто — визема
    ///     определяется автоматически из амплитуды через `autoViseme(from:)`.
    /// - Throws: Ошибка инициализации `AVAudioPlayer` если файл недоступен.
    public func playSpeech(audio url: URL, phonemeTimings: [PhonemeTimestamp] = []) throws {
        stopSpeech()

        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.isMeteringEnabled = true
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()

        self.phonemeTimings = phonemeTimings

        startDisplayLink()
        logger.info("LipSync начат: \(url.lastPathComponent, privacy: .public), phonemes=\(phonemeTimings.count)")
    }

    /// Остановить воспроизведение и сбросить lip-sync в нейтраль.
    public func stopSpeech() {
        audioPlayer?.stop()
        audioPlayer = nil
        displayLink?.invalidate()
        displayLink = nil
        phonemeTimings = []
        mouthOpen = 0
        viseme = .rest
    }

    // MARK: - Display link

    private func startDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateLipSync))
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func updateLipSync() {
        guard let player = audioPlayer else {
            stopSpeech()
            return
        }

        guard player.isPlaying else {
            // Воспроизведение завершено
            mouthOpen = 0
            viseme = .rest
            displayLink?.invalidate()
            displayLink = nil
            return
        }

        player.updateMeters()
        let avgPower = player.averagePower(forChannel: 0)

        // Нормализация: -50 dB (тишина) .. 0 dB (максимум) → 0.0 .. 1.0
        let raw = max(0, min(1, (avgPower + 50) / 50))

        // Low-pass фильтр α = 0.25 (согласован с HSMascotView.applyLipSync α=0.17)
        let alpha: Float = 0.25
        mouthOpen += alpha * (raw - mouthOpen)

        // Визема из тайм-кодов (приоритет) или из амплитуды (fallback)
        if !phonemeTimings.isEmpty {
            let currentTime = player.currentTime
            let active = phonemeTimings.last(where: { $0.time <= currentTime })
            viseme = active?.viseme ?? .rest
        } else {
            viseme = autoViseme(from: mouthOpen)
        }
    }

    // MARK: - Auto viseme from amplitude

    /// Автоматически определяет визему из нормализованной амплитуды.
    /// Используется как fallback когда phoneme timings не предоставлены.
    private func autoViseme(from amplitude: Float) -> LyalyaViseme {
        switch amplitude {
        case 0.0..<0.08:
            return .rest
        case 0.08..<0.25:
            return .consonantOpen
        case 0.25..<0.55:
            return .a
        default:
            return .a
        }
    }
}
