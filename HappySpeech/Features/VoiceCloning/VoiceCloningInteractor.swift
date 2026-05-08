import AVFoundation
import Foundation
import OSLog

// MARK: - VoiceCloningInteractor
//
// Бизнес-логика голосового архива:
//   1. Загрузка существующих записей из Realm (RealmActor через VoiceSampleObject).
//   2. Запись 5-секундного сэмпла через AudioService → AVAudioRecorder.
//   3. Хранение файла в Documents/VoiceArchive/<childId>/<timestamp>.m4a.
//   4. Воспроизведение записи (self-comparison) через AVAudioPlayer.
//   5. Удаление файла + строки из Realm.
//
// Все обращения к диску идут через FileManager.default. Realm — через RealmActor.
// AudioService — через AVAudioEngine + AVAudioRecorder (16 kHz mono, m4a).

@MainActor
final class VoiceCloningInteractor {

    // MARK: - VIP wiring

    private static let logger = Logger(subsystem: "ru.happyspeech", category: "VoiceCloningInteractor")
    weak var presenter: VoiceCloningPresenter?

    // MARK: - Dependencies

    private let audioService: any AudioService
    private let realmActor: RealmActor

    // MARK: - State

    private var loadedSamples: [VoiceSampleData] = []
    private var currentChildId: String = ""
    private var pendingTargetSound: String = "С"
    private var pendingWord: String = ""
    private var recordingStartedAt: Date?
    private var recordingTimer: Task<Void, Never>?
    private var playbackPlayer: AVAudioPlayer?

    // MARK: - Constants

    private let archiveSubdirectory = "VoiceArchive"
    private let maxRecordingSeconds: Double = 6.0      // soft cap, чуть больше 5 сек
    private let recordingTickInterval: TimeInterval = 0.1

    // MARK: - Init

    init(audioService: any AudioService, realmActor: RealmActor) {
        self.audioService = audioService
        self.realmActor = realmActor
    }

    // Note: no deinit cleanup — Task auto-cancels when its parent is deallocated,
    // AVAudioPlayer stops at dealloc; non-Sendable touches in nonisolated deinit
    // would violate Swift 6 strict concurrency.

    // MARK: - Load

    func load(_ request: VoiceCloning.LoadRequest) async {
        currentChildId = request.childId
        Self.logger.info("VoiceCloning: load childId=\(request.childId, privacy: .private)")

        let samples = await realmActor.fetchVoiceSamples(childId: request.childId)
        loadedSamples = samples

        // Подсказка по слову — берём первый таргетный звук ребёнка (или "С" дефолт).
        let suggestedSound = pendingTargetSound
        let suggestedWord = VoiceCloning.SuggestedWordCatalog.defaultWord(forSound: suggestedSound)
        pendingWord = suggestedWord

        presenter?.presentLoad(VoiceCloning.LoadResponse(
            samples: samples,
            suggestedWord: suggestedWord,
            targetSound: suggestedSound
        ))
    }

    // MARK: - Recording

    func startRecording(_ request: VoiceCloning.StartRecordingRequest) async {
        guard !audioService.isRecording else {
            Self.logger.warning("VoiceCloning: startRecording ignored, already recording")
            return
        }

        // Permission check.
        let granted = audioService.isPermissionGranted
            ? true
            : await audioService.requestPermission()
        guard granted else {
            presenter?.presentRecordingResult(VoiceCloning.RecordingResultResponse(
                success: false,
                savedSampleId: nil,
                errorMessage: String(localized: "voice_cloning.error.permission")
            ))
            return
        }

        pendingTargetSound = request.targetSound
        pendingWord = request.word

        do {
            try await audioService.startRecording()
            recordingStartedAt = Date()
            startRecordingTimer()
            Self.logger.debug("VoiceCloning: recording started word=\(request.word, privacy: .public)")
        } catch {
            Self.logger.error("VoiceCloning: startRecording failed \(error.localizedDescription, privacy: .public)")
            presenter?.presentRecordingResult(VoiceCloning.RecordingResultResponse(
                success: false,
                savedSampleId: nil,
                errorMessage: error.localizedDescription
            ))
        }
    }

    func stopRecording(_ request: VoiceCloning.StopRecordingRequest) async {
        guard audioService.isRecording else {
            Self.logger.warning("VoiceCloning: stopRecording ignored, not recording")
            return
        }

        recordingTimer?.cancel()
        recordingTimer = nil
        let elapsed = recordingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        recordingStartedAt = nil

        do {
            let recordedURL = try await audioService.stopRecording()
            let savedPath = try copyRecordingToArchive(
                recordedURL: recordedURL,
                childId: request.childId
            )

            let sample = VoiceSampleData(
                id: UUID().uuidString,
                childId: request.childId,
                word: pendingWord,
                targetSound: pendingTargetSound,
                audioFilePath: savedPath,
                durationSeconds: max(0.5, elapsed),
                recordedAt: Date(),
                note: ""
            )
            await realmActor.persistVoiceSample(sample)
            loadedSamples.insert(sample, at: 0)

            Self.logger.info(
                "VoiceCloning: saved sample id=\(sample.id, privacy: .public) duration=\(elapsed, privacy: .public)"
            )

            presenter?.presentRecordingResult(VoiceCloning.RecordingResultResponse(
                success: true,
                savedSampleId: sample.id,
                errorMessage: nil
            ))

            // Перезагружаем список.
            await load(VoiceCloning.LoadRequest(childId: request.childId))
        } catch {
            Self.logger.error("VoiceCloning: stopRecording failed \(error.localizedDescription, privacy: .public)")
            presenter?.presentRecordingResult(VoiceCloning.RecordingResultResponse(
                success: false,
                savedSampleId: nil,
                errorMessage: error.localizedDescription
            ))
        }
    }

    // MARK: - Playback

    func playSample(_ request: VoiceCloning.PlaySampleRequest) async {
        guard let sample = loadedSamples.first(where: { $0.id == request.sampleId }) else {
            Self.logger.warning("VoiceCloning: playSample id=\(request.sampleId, privacy: .public) not found")
            return
        }

        playbackPlayer?.stop()

        let absoluteURL = absoluteURL(forRelativePath: sample.audioFilePath)
        guard FileManager.default.fileExists(atPath: absoluteURL.path) else {
            Self.logger.warning("VoiceCloning: file missing at \(absoluteURL.path, privacy: .public)")
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true, options: [])
            let player = try AVAudioPlayer(contentsOf: absoluteURL)
            player.prepareToPlay()
            player.play()
            playbackPlayer = player
            presenter?.presentPlayback(VoiceCloning.PlaybackResponse(
                isPlaying: true,
                currentSampleId: request.sampleId
            ))
            // Авто-завершение по длительности.
            Task { [weak self] in
                let waitFor = max(0.3, player.duration)
                try? await Task.sleep(for: .seconds(waitFor + 0.1))
                await MainActor.run {
                    self?.presenter?.presentPlayback(VoiceCloning.PlaybackResponse(
                        isPlaying: false,
                        currentSampleId: nil
                    ))
                }
            }
        } catch {
            Self.logger.error("VoiceCloning: playback failed \(error.localizedDescription, privacy: .public)")
        }
    }

    func stopPlayback() {
        playbackPlayer?.stop()
        playbackPlayer = nil
        presenter?.presentPlayback(VoiceCloning.PlaybackResponse(
            isPlaying: false,
            currentSampleId: nil
        ))
    }

    // MARK: - Delete

    func delete(_ request: VoiceCloning.DeleteSampleRequest) async {
        guard let sample = loadedSamples.first(where: { $0.id == request.sampleId }) else {
            return
        }

        // Удалим файл (soft — игнорируем ошибки).
        let absURL = absoluteURL(forRelativePath: sample.audioFilePath)
        try? FileManager.default.removeItem(at: absURL)

        let removed = await realmActor.deleteVoiceSample(id: request.sampleId)
        loadedSamples.removeAll { $0.id == request.sampleId }
        Self.logger.info(
            "VoiceCloning: delete sample id=\(request.sampleId, privacy: .public) removedFromRealm=\(removed, privacy: .public)"
        )

        presenter?.presentDelete(VoiceCloning.DeleteResponse(
            success: removed,
            deletedSampleId: request.sampleId
        ))
    }

    // MARK: - Helpers

    /// Запускает таймер тиков прогресса записи. Останавливается через max или при stopRecording.
    private func startRecordingTimer() {
        recordingTimer?.cancel()
        recordingTimer = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(recordingTickInterval))
                if Task.isCancelled { return }
                let elapsed = self.recordingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
                let amplitude = self.audioService.amplitude
                self.presenter?.presentRecordingState(VoiceCloning.RecordingStateResponse(
                    isRecording: self.audioService.isRecording,
                    elapsedSeconds: elapsed,
                    amplitude: amplitude
                ))
                if elapsed >= self.maxRecordingSeconds {
                    // Авто-стоп.
                    await self.stopRecording(VoiceCloning.StopRecordingRequest(childId: self.currentChildId))
                    return
                }
            }
        }
    }

    /// Копирует записанный временный файл в Documents/VoiceArchive/<childId>/<timestamp>.m4a
    /// и возвращает путь относительно Documents (для хранения в Realm).
    private func copyRecordingToArchive(recordedURL: URL, childId: String) throws -> String {
        let fileManager = FileManager.default
        let documents = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let archiveDir = documents
            .appendingPathComponent(archiveSubdirectory, isDirectory: true)
            .appendingPathComponent(childId, isDirectory: true)

        if !fileManager.fileExists(atPath: archiveDir.path) {
            try fileManager.createDirectory(at: archiveDir, withIntermediateDirectories: true)
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let dest = archiveDir.appendingPathComponent("sample_\(timestamp).m4a")

        // Если файл уже существует (один и тот же timestamp) — добавим UUID-суффикс.
        let finalDest: URL
        if fileManager.fileExists(atPath: dest.path) {
            finalDest = archiveDir
                .appendingPathComponent("sample_\(timestamp)_\(UUID().uuidString.prefix(6)).m4a")
        } else {
            finalDest = dest
        }

        try fileManager.copyItem(at: recordedURL, to: finalDest)

        // Относительный путь — Documents/<archive>/<childId>/sample_xxx.m4a
        let relative = "\(archiveSubdirectory)/\(childId)/\(finalDest.lastPathComponent)"
        return relative
    }

    /// Преобразует относительный путь обратно в абсолютный URL.
    private func absoluteURL(forRelativePath relative: String) -> URL {
        let documents = (try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return documents.appendingPathComponent(relative)
    }
}
