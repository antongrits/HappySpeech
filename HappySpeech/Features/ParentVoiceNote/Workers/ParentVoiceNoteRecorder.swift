import AVFoundation
import Foundation
import OSLog

// MARK: - ParentVoiceNoteRecorderProtocol

@MainActor
protocol ParentVoiceNoteRecorderProtocol: AnyObject {
    /// Запрашивает разрешение на запись микрофона (idempotent).
    func requestPermission() async -> Bool

    /// Начинает запись; возвращает временный файл .m4a.
    /// Возвращает nil, если permission denied или не удалось открыть session.
    func startRecording() async throws -> URL

    /// Останавливает запись и возвращает (длительность сек, file URL).
    @discardableResult
    func stopRecording() -> (durationSec: Double, fileURL: URL)?

    /// Текущая длительность активной записи (в реальном времени).
    var currentDurationSec: Double { get }

    /// Лимит на длительность одной записи (по умолчанию 30 секунд).
    var maxDurationSec: Double { get }

    /// Активна ли запись.
    var isRecording: Bool { get }
}

// MARK: - ParentVoiceNoteRecorder (Live)

@MainActor
final class ParentVoiceNoteRecorder: NSObject, ParentVoiceNoteRecorderProtocol {

    let maxDurationSec: Double = 30.0
    private(set) var isRecording: Bool = false
    private var recorder: AVAudioRecorder?
    private var startTime: Date?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ParentVoiceNote.Recorder"
    )

    var currentDurationSec: Double {
        guard let startTime else { return 0 }
        return min(maxDurationSec, Date().timeIntervalSince(startTime))
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        // iOS 17+ : AVAudioApplication.requestRecordPermission
        if #available(iOS 17.0, *) {
            return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                AVAudioApplication.requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
        } else {
            return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
        }
    }

    // MARK: - Recording

    func startRecording() async throws -> URL {
        let granted = await requestPermission()
        guard granted else {
            throw NSError(
                domain: "ParentVoiceNote",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Микрофон запрещён"]
            )
        }
        try configureSession()

        let tempURL = makeTempURL()
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        let newRecorder = try AVAudioRecorder(url: tempURL, settings: settings)
        newRecorder.delegate = self
        newRecorder.isMeteringEnabled = true
        let started = newRecorder.record(forDuration: maxDurationSec)
        guard started else {
            throw NSError(
                domain: "ParentVoiceNote",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Не удалось начать запись"]
            )
        }
        recorder = newRecorder
        startTime = Date()
        isRecording = true
        return tempURL
    }

    @discardableResult
    func stopRecording() -> (durationSec: Double, fileURL: URL)? {
        guard let recorder, let startTime else { return nil }
        let durationSec = min(maxDurationSec, Date().timeIntervalSince(startTime))
        recorder.stop()
        let url = recorder.url
        self.recorder = nil
        self.startTime = nil
        isRecording = false
        // Деактивируем сессию: чтобы не блокировать другую аудио-логику.
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        return (durationSec, url)
    }

    // MARK: - Helpers

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true, options: [])
    }

    private func makeTempURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "parent-voice-\(UUID().uuidString).m4a"
        return tempDir.appendingPathComponent(filename)
    }
}

// MARK: - AVAudioRecorderDelegate

extension ParentVoiceNoteRecorder: AVAudioRecorderDelegate {

    nonisolated func audioRecorderDidFinishRecording(
        _ recorder: AVAudioRecorder,
        successfully flag: Bool
    ) {
        Task { @MainActor [weak self] in
            // Если запись окончилась автоматически (по таймауту forDuration),
            // фиксируем состояние и оставляем файл на диске.
            guard let self else { return }
            if self.isRecording {
                self.isRecording = false
            }
        }
    }
}
