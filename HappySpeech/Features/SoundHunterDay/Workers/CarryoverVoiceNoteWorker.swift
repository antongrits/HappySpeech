import AVFoundation
import Foundation
import OSLog

// MARK: - CarryoverVoiceNoteWorking
//
// Запись короткой родительской «заметки-перла» для подтверждения переноса.
// Записывает .m4a во временный файл, затем по запросу переносит его в
// постоянную папку `Documents/CarryoverNotes/` и возвращает ОТНОСИТЕЛЬНЫЙ путь
// (для хранения в CarryoverLog — устойчив к смене контейнера приложения).
//
// Контур: ТОЛЬКО родительский (за parental gate). COPPA: запись локальна,
// on-device, не выгружается без явного действия родителя.

@MainActor
protocol CarryoverVoiceNoteWorking: AnyObject {
    var isRecording: Bool { get }
    var currentDurationSec: Double { get }
    var maxDurationSec: Double { get }

    func requestPermission() async -> Bool
    /// Начинает запись. Бросает, если микрофон запрещён или сессию не открыть.
    func startRecording() async throws
    /// Останавливает запись, переносит файл в Documents/CarryoverNotes и
    /// возвращает (относительный путь, длительность). nil — записи не было.
    func finishAndPersist(childId: String) -> (relativePath: String, durationSec: Double)?
    /// Сбрасывает активную запись без сохранения (отмена).
    func cancel()
}

// MARK: - LiveCarryoverVoiceNoteWorker

@MainActor
final class CarryoverVoiceNoteWorker: NSObject, CarryoverVoiceNoteWorking {

    let maxDurationSec: Double = 30.0
    private(set) var isRecording = false

    private var recorder: AVAudioRecorder?
    private var startTime: Date?
    private var tempURL: URL?

    private static let folderName = "CarryoverNotes"
    private static let logger = Logger(subsystem: "ru.happyspeech", category: "CarryoverVoiceNote")

    var currentDurationSec: Double {
        guard let startTime else { return 0 }
        return min(maxDurationSec, Date().timeIntervalSince(startTime))
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
    }

    // MARK: - Recording

    func startRecording() async throws {
        let granted = await requestPermission()
        guard granted else {
            throw AppError.audioPermissionDenied
        }
        try configureSession()

        let temp = makeTempURL()
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        let newRecorder = try AVAudioRecorder(url: temp, settings: settings)
        newRecorder.delegate = self
        newRecorder.isMeteringEnabled = true
        guard newRecorder.record(forDuration: maxDurationSec) else {
            throw AppError.audioRecordingFailed("recorder.record returned false")
        }
        recorder = newRecorder
        tempURL = temp
        startTime = Date()
        isRecording = true
    }

    func finishAndPersist(childId: String) -> (relativePath: String, durationSec: Double)? {
        guard let recorder, let startTime, let tempURL else { return nil }
        let durationSec = min(maxDurationSec, Date().timeIntervalSince(startTime))
        recorder.stop()
        self.recorder = nil
        self.startTime = nil
        self.tempURL = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])

        guard let relativePath = persist(tempURL: tempURL, childId: childId) else {
            return nil
        }
        return (relativePath, durationSec)
    }

    func cancel() {
        recorder?.stop()
        if let tempURL { try? FileManager.default.removeItem(at: tempURL) }
        recorder = nil
        startTime = nil
        tempURL = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    // MARK: - Helpers

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true, options: [])
    }

    private func makeTempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("carryover-note-\(UUID().uuidString).m4a")
    }

    /// Переносит временный файл в Documents/CarryoverNotes и возвращает путь
    /// относительно Documents (для устойчивого хранения в Realm).
    private func persist(tempURL: URL, childId: String) -> String? {
        let fm = FileManager.default
        guard let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let folder = documents.appendingPathComponent(Self.folderName, isDirectory: true)
        do {
            if !fm.fileExists(atPath: folder.path) {
                try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            }
            let safeChild = childId.replacingOccurrences(of: "/", with: "_")
            let filename = "\(safeChild)-\(UUID().uuidString).m4a"
            let destination = folder.appendingPathComponent(filename)
            try fm.moveItem(at: tempURL, to: destination)
            return "\(Self.folderName)/\(filename)"
        } catch {
            Self.logger.error("persist failed: \(error.localizedDescription, privacy: .public)")
            try? fm.removeItem(at: tempURL)
            return nil
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension CarryoverVoiceNoteWorker: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(
        _ recorder: AVAudioRecorder,
        successfully flag: Bool
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.isRecording { self.isRecording = false }
        }
    }
}
