import AVFoundation
import Foundation
import OSLog

// MARK: - VoiceJournalInteractor
//
// VIP-Interactor для «Дневника голоса».
//
// Поток:
//   1. `loadEntries(_:)` — забирает все записи ребёнка из Realm через
//      RealmActor (newest first).
//   2. `startRecording(_:)` — запрашивает permission, открывает AVAudioSession
//      .playAndRecord и пишет .m4a во временную папку.
//   3. `stopRecording(_:)` — останавливает рекордер, перемещает файл в
//      Documents/VoiceJournal/, сохраняет запись в Realm, перезагружает
//      список.
//   4. `play(_:)` — воспроизводит запись через AVAudioPlayer (delegate
//      обнуляет ссылку по завершении).
//   5. `delete(_:)` — удаляет файл с диска и запись из Realm.

@MainActor
final class VoiceJournalInteractor: NSObject {

    // MARK: - Dependencies

    private let presenter: VoiceJournalPresenter
    private let router: VoiceJournalRouter
    private let realmActor: RealmActor
    private let childId: String

    // MARK: - Audio state

    private var recorder: AVAudioRecorder?
    private var recordingStartedAt: Date?
    private var temporaryRecordingURL: URL?
    private var player: AVAudioPlayer?

    private static let folderName = "VoiceJournal"
    private static let maxDurationSec: Double = 120

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "VoiceJournal.Interactor"
    )

    // MARK: - Init

    init(
        presenter: VoiceJournalPresenter,
        router: VoiceJournalRouter,
        realmActor: RealmActor,
        childId: String
    ) {
        self.presenter = presenter
        self.router = router
        self.realmActor = realmActor
        self.childId = childId
        super.init()
    }

    // MARK: - Load Entries

    func loadEntries(_ request: VoiceJournalModels.LoadEntries.Request) async {
        let entries = await fetchEntries(childId: request.childId)
        await presenter.presentLoadEntries(response: .init(entries: entries))
    }

    // MARK: - Recording

    func startRecording(_ request: VoiceJournalModels.StartRecording.Request) async {
        let granted = await requestMicrophonePermission()
        guard granted else {
            await presenter.presentRecordingFailed(
                message: String(localized: "voice.journal.error.permission")
            )
            return
        }
        do {
            try configureSession()
            let url = makeTemporaryURL()
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
            ]
            let newRecorder = try AVAudioRecorder(url: url, settings: settings)
            newRecorder.delegate = self
            newRecorder.isMeteringEnabled = true
            let started = newRecorder.record(forDuration: Self.maxDurationSec)
            guard started else {
                await presenter.presentRecordingFailed(
                    message: String(localized: "voice.journal.error.start")
                )
                return
            }
            recorder = newRecorder
            recordingStartedAt = Date()
            temporaryRecordingURL = url
            await presenter.presentRecordingStarted()
        } catch {
            Self.logger.error(
                "startRecording error: \(error.localizedDescription, privacy: .public)"
            )
            await presenter.presentRecordingFailed(message: error.localizedDescription)
        }
    }

    func stopRecording(_ request: VoiceJournalModels.StopRecording.Request) async {
        guard let recorder, let tempURL = temporaryRecordingURL,
              let startedAt = recordingStartedAt else {
            await presenter.presentRecordingFailed(
                message: String(localized: "voice.journal.error.no_active")
            )
            return
        }
        recorder.stop()
        let durationSec = max(1, Int(Date().timeIntervalSince(startedAt).rounded()))
        self.recorder = nil
        self.temporaryRecordingURL = nil
        self.recordingStartedAt = nil
        try? AVAudioSession.sharedInstance().setActive(
            false, options: [.notifyOthersOnDeactivation]
        )

        guard let relativePath = persistRecordingFile(from: tempURL) else {
            await presenter.presentRecordingFailed(
                message: String(localized: "voice.journal.error.persist")
            )
            return
        }
        let entry = VoiceJournalEntry(
            id: UUID().uuidString,
            childId: request.childId,
            date: Date(),
            fileURL: absoluteURL(forRelative: relativePath),
            title: request.title,
            durationSeconds: durationSec,
            transcript: nil
        )
        _ = await realmActor.insertVoiceJournalEntry(
            id: entry.id,
            childId: entry.childId,
            date: entry.date,
            relativePath: relativePath,
            title: entry.title,
            durationSeconds: entry.durationSeconds,
            transcript: entry.transcript
        )
        let allEntries = await fetchEntries(childId: request.childId)
        await presenter.presentRecordingSaved(allEntries: allEntries)
    }

    func cancelRecording() {
        recorder?.stop()
        if let tempURL = temporaryRecordingURL {
            try? FileManager.default.removeItem(at: tempURL)
        }
        recorder = nil
        temporaryRecordingURL = nil
        recordingStartedAt = nil
        try? AVAudioSession.sharedInstance().setActive(
            false, options: [.notifyOthersOnDeactivation]
        )
    }

    // MARK: - Play

    func play(_ request: VoiceJournalModels.Play.Request) async -> VoiceJournalModels.Play.Response {
        let url = request.entry.fileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            Self.logger.warning(
                "Файл не найден: \(url.lastPathComponent, privacy: .public)"
            )
            return .init(success: false)
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true, options: [])
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            newPlayer.prepareToPlay()
            newPlayer.play()
            self.player = newPlayer
            return .init(success: true)
        } catch {
            Self.logger.error(
                "play error: \(error.localizedDescription, privacy: .public)"
            )
            return .init(success: false)
        }
    }

    func stopPlayback() {
        player?.stop()
        player = nil
    }

    // MARK: - Delete

    func delete(_ request: VoiceJournalModels.Delete.Request) async {
        let url = request.entry.fileURL
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        _ = await realmActor.deleteVoiceJournalEntry(id: request.entry.id)
        let allEntries = await fetchEntries(childId: childId)
        await presenter.presentLoadEntries(response: .init(entries: allEntries))
    }

    // MARK: - Private — fetching

    private func fetchEntries(childId: String) async -> [VoiceJournalEntry] {
        guard let documents = documentsBaseURL() else { return [] }
        return await realmActor.fetchVoiceJournalEntries(
            childId: childId,
            documentsBaseURL: documents
        )
    }

    // MARK: - Private — audio session

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.defaultToSpeaker]
        )
        try session.setActive(true, options: [])
    }

    private func requestMicrophonePermission() async -> Bool {
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

    // MARK: - Private — file system

    private func documentsBaseURL() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    private func folderURL() -> URL? {
        guard let documents = documentsBaseURL() else { return nil }
        let folder = documents.appendingPathComponent(
            Self.folderName,
            isDirectory: true
        )
        if !FileManager.default.fileExists(atPath: folder.path) {
            do {
                try FileManager.default.createDirectory(
                    at: folder,
                    withIntermediateDirectories: true
                )
            } catch {
                Self.logger.error(
                    "Не удалось создать папку: \(error.localizedDescription, privacy: .public)"
                )
                return nil
            }
        }
        return folder
    }

    private func makeTemporaryURL() -> URL {
        let temp = FileManager.default.temporaryDirectory
        return temp.appendingPathComponent("vj-\(UUID().uuidString).m4a")
    }

    private func persistRecordingFile(from tempURL: URL) -> String? {
        guard let folder = folderURL() else { return nil }
        let destination = folder.appendingPathComponent(tempURL.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: tempURL, to: destination)
            return relativePath(for: destination)
        } catch {
            Self.logger.error(
                "Не удалось переместить файл: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private func relativePath(for url: URL) -> String {
        guard let base = documentsBaseURL() else { return url.lastPathComponent }
        let basePath = base.path
        if url.path.hasPrefix(basePath) {
            return String(url.path.dropFirst(basePath.count + 1))
        }
        return url.lastPathComponent
    }

    private func absoluteURL(forRelative path: String) -> URL {
        guard let base = documentsBaseURL() else {
            return URL(fileURLWithPath: path)
        }
        return base.appendingPathComponent(path)
    }
}

// MARK: - AVAudioRecorderDelegate

extension VoiceJournalInteractor: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(
        _ recorder: AVAudioRecorder,
        successfully flag: Bool
    ) {
        Task { @MainActor [weak self] in
            // Если запись завершилась автоматически по timeout — UI вызовет
            // stopRecording самостоятельно. Здесь просто гасим recorder.
            guard let self else { return }
            if self.recorder === recorder {
                self.recorder = nil
            }
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension VoiceJournalInteractor: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(
        _ player: AVAudioPlayer,
        successfully flag: Bool
    ) {
        Task { @MainActor [weak self] in
            self?.player = nil
        }
    }
}
