import AVFoundation
import Foundation

// MARK: - AudioFilePlaying

/// Минимальный протокол воспроизведения аудиофайла.
///
/// `AudioFilePlaying` извлекает прямую зависимость от `AVAudioPlayer` из
/// Interactor'ов в тонкий seam, который можно мокать в unit-тестах.
///
/// Производственная реализация — ``LiveAudioFilePlayer`` (поверх `AVAudioPlayer`);
/// тестовый дубль — `MockAudioFilePlayer` в test-таргете.
///
/// > Note: Реализации не обязаны быть thread-safe — все вызовы из
/// > `@MainActor`-изолированных Interactor'ов.
public protocol AudioFilePlaying: AnyObject {
    /// `true`, если в данный момент идёт воспроизведение.
    var isPlaying: Bool { get }

    /// Длительность последнего подготовленного файла (секунды).
    var duration: TimeInterval { get }

    /// Подготавливает и запускает воспроизведение файла по URL.
    /// - Throws: ошибку, если файл не удаётся открыть.
    func play(contentsOf url: URL) throws

    /// Останавливает воспроизведение и освобождает плеер.
    func stop()
}

// MARK: - LiveAudioFilePlayer

/// Производственная реализация ``AudioFilePlaying`` поверх `AVAudioPlayer`.
public final class LiveAudioFilePlayer: AudioFilePlaying {

    private var player: AVAudioPlayer?

    /// Категория `AVAudioSession`, активируемая перед воспроизведением.
    private let activatesPlaybackSession: Bool

    public init(activatesPlaybackSession: Bool = false) {
        self.activatesPlaybackSession = activatesPlaybackSession
    }

    public var isPlaying: Bool { player?.isPlaying ?? false }

    public var duration: TimeInterval { player?.duration ?? 0 }

    public func play(contentsOf url: URL) throws {
        if activatesPlaybackSession {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true, options: [])
        }
        let newPlayer = try AVAudioPlayer(contentsOf: url)
        newPlayer.volume = 1.0
        newPlayer.prepareToPlay()
        newPlayer.play()
        player = newPlayer
    }

    public func stop() {
        player?.stop()
        player = nil
    }
}

// MARK: - AudioFileRecording

/// Минимальный протокол записи аудио в файл.
///
/// `AudioFileRecording` извлекает прямую зависимость от `AVAudioRecorder` из
/// Interactor'ов, оставляя бизнес-логику (анализ дисфлюенций, длительность,
/// сохранение) полностью unit-тестируемой.
///
/// Производственная реализация — ``LiveAudioFileRecorder``; тестовый дубль —
/// `MockAudioFileRecorder` в test-таргете.
public protocol AudioFileRecording: AnyObject {
    /// `true`, если в данный момент идёт запись.
    var isRecording: Bool { get }

    /// URL текущего/последнего файла записи (если запись стартовала успешно).
    var fileURL: URL? { get }

    /// Стартует запись в формате M4A AAC 16 kHz mono по указанному URL.
    /// - Returns: `true`, если запись успешно запущена.
    @discardableResult
    func startRecording(to url: URL) -> Bool

    /// Останавливает запись и освобождает рекордер.
    func stopRecording()
}

// MARK: - LiveAudioFileRecorder

/// Производственная реализация ``AudioFileRecording`` поверх `AVAudioRecorder`.
///
/// Параметры записи фиксированы под ASR-конвейер: M4A AAC, 16 kHz, mono.
public final class LiveAudioFileRecorder: AudioFileRecording {

    private var recorder: AVAudioRecorder?
    public private(set) var fileURL: URL?

    public init() {}

    public var isRecording: Bool { recorder?.isRecording ?? false }

    @discardableResult
    public func startRecording(to url: URL) -> Bool {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        do {
            let newRecorder = try AVAudioRecorder(url: url, settings: settings)
            newRecorder.record()
            recorder = newRecorder
            fileURL = url
            return true
        } catch {
            recorder = nil
            fileURL = nil
            return false
        }
    }

    public func stopRecording() {
        recorder?.stop()
        recorder = nil
    }
}
