import AVFoundation
import Foundation
import OSLog

// MARK: - FamilyVoiceRecorderWorker

/// Wraps AVAudioRecorder for family recording sessions.
/// Stores recordings in Documents/family_recordings/<id>.m4a (16kHz mono AAC).
/// All file I/O performed on a background task; caller switches to MainActor as needed.
final class FamilyVoiceRecorderWorker: NSObject, Sendable {

    // MARK: - Constants

    static let subfolderName = "family_recordings"
    private static let sampleRate: Double = 16_000
    private static let logger = Logger(subsystem: "com.happyspeech", category: "FamilyVoiceRecorderWorker")

    // MARK: - Mutable state (nonisolated, protected by a dedicated actor)

    private let state = RecorderState()

    // MARK: - Actor for mutable state

    private actor RecorderState {
        var recorder: AVAudioRecorder?
        var player: AVAudioPlayer?
        var currentFileURL: URL?
        var startDate: Date?

        func setRecorder(_ rec: AVAudioRecorder?, url: URL?) {
            recorder = rec
            currentFileURL = url
            startDate = rec != nil ? Date() : nil
        }

        func clearRecorder() {
            recorder = nil
            currentFileURL = nil
            startDate = nil
        }

        /// Stores the new player, starts playback, returns duration.
        func startPlayback(_ p: AVAudioPlayer) -> Double {
            player?.stop()
            player = p
            player?.prepareToPlay()
            player?.play()
            return player?.duration ?? 0
        }

        func stopPlayer() {
            player?.stop()
            player = nil
        }

        var duration: TimeInterval {
            guard let start = startDate else { return 0 }
            return Date().timeIntervalSince(start)
        }
    }

    // MARK: - Recording

    /// Starts recording for the given word. Returns the destination URL.
    func startRecording(word: String) async throws -> URL {
        let fileURL = try Self.makeFileURL(for: UUID().uuidString)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: Self.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement)
        try AVAudioSession.sharedInstance().setActive(true)

        let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
        recorder.isMeteringEnabled = true
        guard recorder.record() else {
            throw FamilyVoiceError.recordingFailed
        }
        await state.setRecorder(recorder, url: fileURL)
        Self.logger.info("Recording started → \(fileURL.lastPathComponent)")
        return fileURL
    }

    /// Stops the active recording. Returns the saved file URL and duration.
    func stopRecording() async throws -> (url: URL, duration: Double) {
        let currentRecorder = await state.recorder
        let fileURL = await state.currentFileURL
        let duration = await state.duration

        guard let recorder = currentRecorder, let url = fileURL else {
            throw FamilyVoiceError.noActiveRecording
        }

        recorder.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        await state.clearRecorder()

        Self.logger.info("Recording stopped. Duration: \(duration)s → \(url.lastPathComponent)")
        return (url, duration)
    }

    /// Returns current RMS level [0..1] for waveform visualization.
    func currentRMSLevel() async -> Float {
        guard let recorder = await state.recorder else { return 0 }
        recorder.updateMeters()
        let db = recorder.averagePower(forChannel: 0)
        // Normalize: -60dB → 0.0, 0dB → 1.0
        let normalized = max(0, (db + 60) / 60)
        return Float(normalized)
    }

    // MARK: - Playback

    /// Plays back a recording by file path (relative to Documents/family_recordings/).
    func playRecording(filePath: String) async throws -> Double {
        let url = try Self.resolveFilePath(filePath)

        // Deactivate current session before switching category (CRITICAL 2 fix)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)

        let player = try AVAudioPlayer(contentsOf: url)
        // CRITICAL 1 fix: retain player in actor state; play() called inside actor to avoid data race
        let duration = await state.startPlayback(player)
        Self.logger.info("Playback started: \(url.lastPathComponent)")
        return duration
    }

    // MARK: - Deletion

    func deleteRecording(filePath: String) async throws {
        let url = try Self.resolveFilePath(filePath)
        try FileManager.default.removeItem(at: url)
        Self.logger.info("Deleted recording: \(url.lastPathComponent)")
    }

    // MARK: - File helpers

    static func makeFileURL(for id: String) throws -> URL {
        let docs = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folder = docs.appendingPathComponent(subfolderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder.appendingPathComponent("\(id).m4a")
    }

    static func resolveFilePath(_ relativePath: String) throws -> URL {
        let docs = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        return docs.appendingPathComponent(relativePath)
    }

    /// Converts an absolute URL to a relative path for storage.
    static func relativeFilePath(from absoluteURL: URL) throws -> String {
        let docs = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let docPath = docs.path
        let absolutePath = absoluteURL.path
        if absolutePath.hasPrefix(docPath) {
            return String(absolutePath.dropFirst(docPath.count + 1))
        }
        return absolutePath
    }
}

// MARK: - FamilyVoiceError

enum FamilyVoiceError: LocalizedError, Sendable {
    case recordingFailed
    case noActiveRecording
    case fileNotFound(String)
    case maxRecordingsReached
    case microphonePermissionDenied

    var errorDescription: String? {
        switch self {
        case .recordingFailed:
            return String(localized: "parent_child.error.recording_failed")
        case .noActiveRecording:
            return String(localized: "parent_child.error.recording_failed")
        case .fileNotFound(let path):
            return String(format: String(localized: "parent_child.error.file_not_found"), path)
        case .maxRecordingsReached:
            return String(localized: "parent_child.recordings.max_warning")
        case .microphonePermissionDenied:
            return String(localized: "parent_child.error.mic_permission")
        }
    }
}
