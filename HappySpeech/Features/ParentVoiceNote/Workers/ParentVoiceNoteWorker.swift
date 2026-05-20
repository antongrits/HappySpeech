import AVFoundation
import Foundation
import OSLog

// MARK: - ParentVoiceNoteWorkerProtocol

@MainActor
protocol ParentVoiceNoteWorkerProtocol: AnyObject {
    /// Текущие записи для ребёнка.
    func fetchClips(childId: String) async -> [ParentVoiceClipData]
    /// Перемещает временный файл в Documents/ParentVoiceNotes и
    /// сохраняет запись в Realm.
    func saveClip(
        childId: String,
        lessonTemplate: String,
        tempFileURL: URL,
        durationSec: Double
    ) async -> ParentVoiceClipData?
    /// Удаляет запись (Realm + файл).
    @discardableResult
    func deleteClip(_ data: ParentVoiceClipData) async -> Bool
    /// Включает / выключает все записи для ребёнка (Settings opt-in).
    func setEnabledForChild(_ childId: String, isEnabled: Bool) async
    /// Активная запись для (childId, lessonTemplate), если есть.
    func activeClip(childId: String, lessonTemplate: String) async -> ParentVoiceClipData?
    /// Воспроизводит запись (использует AVAudioPlayer внутри).
    func play(_ data: ParentVoiceClipData) async
    /// Останавливает текущее воспроизведение.
    func stopPlayback()
}

// MARK: - ParentVoiceNoteWorker

@MainActor
final class ParentVoiceNoteWorker: NSObject, ParentVoiceNoteWorkerProtocol {

    private let realmActor: RealmActor
    private var player: AVAudioPlayer?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ParentVoiceNote.Worker"
    )

    init(realmActor: RealmActor) {
        self.realmActor = realmActor
        super.init()
    }

    // MARK: - Fetch / Save / Delete

    func fetchClips(childId: String) async -> [ParentVoiceClipData] {
        await realmActor.fetchParentVoiceClips(childId: childId)
    }

    func activeClip(childId: String, lessonTemplate: String) async -> ParentVoiceClipData? {
        await realmActor.fetchActiveParentVoiceClip(
            childId: childId,
            lessonTemplate: lessonTemplate
        )
    }

    func saveClip(
        childId: String,
        lessonTemplate: String,
        tempFileURL: URL,
        durationSec: Double
    ) async -> ParentVoiceClipData? {
        guard let storedURL = persistTempFile(tempFileURL) else {
            Self.logger.error("Не удалось сохранить временный файл записи")
            return nil
        }
        let relativePath = relativeDocumentsPath(for: storedURL)

        // Удаляем предыдущий клип для (childId, template), чтобы держать
        // ровно одну активную запись на шаблон.
        let existing = await activeClip(childId: childId, lessonTemplate: lessonTemplate)
        if let existing {
            _ = await deleteClip(existing)
        }

        let data = ParentVoiceClipData(
            id: UUID().uuidString,
            childId: childId,
            lessonTemplate: lessonTemplate,
            fileURL: relativePath,
            durationSec: durationSec,
            recordedAt: Date(),
            isEnabled: true
        )
        await realmActor.persistParentVoiceClip(data)
        return data
    }

    @discardableResult
    func deleteClip(_ data: ParentVoiceClipData) async -> Bool {
        let removedFromDisk = removeFileIfExists(relativePath: data.fileURL)
        let removedFromRealm = await realmActor.deleteParentVoiceClip(id: data.id)
        return removedFromDisk || removedFromRealm
    }

    func setEnabledForChild(_ childId: String, isEnabled: Bool) async {
        await realmActor.setParentVoiceClipsEnabled(childId: childId, isEnabled: isEnabled)
    }

    // MARK: - Playback

    func play(_ data: ParentVoiceClipData) async {
        let absoluteURL = absoluteDocumentsURL(relativePath: data.fileURL)
        guard FileManager.default.fileExists(atPath: absoluteURL.path) else {
            Self.logger.warning("Воспроизведение: файл не найден \(absoluteURL.lastPathComponent, privacy: .public)")
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true, options: [])
            let newPlayer = try AVAudioPlayer(contentsOf: absoluteURL)
            newPlayer.prepareToPlay()
            newPlayer.delegate = self
            newPlayer.play()
            self.player = newPlayer
        } catch {
            Self.logger.error("Не удалось воспроизвести: \(error.localizedDescription, privacy: .public)")
        }
    }

    func stopPlayback() {
        player?.stop()
        player = nil
    }

    // MARK: - File system

    private static let folderName = "ParentVoiceNotes"

    private func documentsFolderURL() -> URL? {
        guard let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else { return nil }
        let folder = documents.appendingPathComponent(Self.folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            do {
                try FileManager.default.createDirectory(
                    at: folder,
                    withIntermediateDirectories: true
                )
            } catch {
                Self.logger.error("create folder failed: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }
        return folder
    }

    private func persistTempFile(_ tempURL: URL) -> URL? {
        guard let folder = documentsFolderURL() else { return nil }
        let target = folder.appendingPathComponent(tempURL.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: target.path) {
                try FileManager.default.removeItem(at: target)
            }
            try FileManager.default.moveItem(at: tempURL, to: target)
            return target
        } catch {
            Self.logger.error("move temp file failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    @discardableResult
    private func removeFileIfExists(relativePath: String) -> Bool {
        let absolute = absoluteDocumentsURL(relativePath: relativePath)
        guard FileManager.default.fileExists(atPath: absolute.path) else { return false }
        do {
            try FileManager.default.removeItem(at: absolute)
            return true
        } catch {
            Self.logger.error("remove file failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Возвращает путь относительно Documents (без префикса), чтобы при
    /// переименовании bundleId / переустановке приложения не потерять записи.
    private func relativeDocumentsPath(for url: URL) -> String {
        guard let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else { return url.lastPathComponent }
        let documentsPath = documents.path
        if url.path.hasPrefix(documentsPath) {
            return String(url.path.dropFirst(documentsPath.count + 1)) // +1 за слеш
        }
        return url.lastPathComponent
    }

    private func absoluteDocumentsURL(relativePath: String) -> URL {
        guard let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            return URL(fileURLWithPath: relativePath)
        }
        return documents.appendingPathComponent(relativePath)
    }
}

// MARK: - AVAudioPlayerDelegate

extension ParentVoiceNoteWorker: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(
        _ player: AVAudioPlayer,
        successfully flag: Bool
    ) {
        Task { @MainActor [weak self] in
            self?.player = nil
        }
    }
}
