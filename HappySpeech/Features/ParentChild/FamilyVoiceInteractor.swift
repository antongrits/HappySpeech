import AVFoundation
import Foundation
import OSLog
import RealmSwift

// MARK: - FamilyVoiceInteractor

@MainActor
final class FamilyVoiceInteractor {

    // MARK: - VIP wiring

    var presenter: FamilyVoicePresenter?

    // MARK: - Workers

    private let recorderWorker: FamilyVoiceRecorderWorker
    private let scoringWorker: FamilyVoiceScoringWorker
    private let realmActor: RealmActor

    // MARK: - State

    private var parentId: String = ""
    private var recordings: [RecordingDTO] = []
    private var selectedWord: String = FamilyVoiceModels.targetWordsRaw.first ?? "мяч"
    private var childAudioFilePath: String?
    private var isChildRecording: Bool = false

    // Waveform polling task
    private var waveformTask: Task<Void, Never>?

    // Playback finish observation
    private var playbackTask: Task<Void, Never>?

    // Auto-dismiss feedback task
    private var feedbackTask: Task<Void, Never>?

    private let logger = Logger(subsystem: "com.happyspeech", category: "FamilyVoiceInteractor")

    // MARK: - Init

    init(
        realmActor: RealmActor,
        pronunciationScorer: (any PronunciationScorerService)? = nil
    ) {
        self.realmActor = realmActor
        self.recorderWorker = FamilyVoiceRecorderWorker()
        self.scoringWorker = FamilyVoiceScoringWorker(pronunciationScorer: pronunciationScorer)
    }

    // MARK: - Fetch recordings

    func fetchRecordings(_ request: FamilyVoiceModels.FetchRecordingsRequest) async {
        parentId = request.parentId
        let dtos = await loadRecordingsFromRealm(parentId: parentId)
        recordings = dtos
        presenter?.presentRecordings(.init(recordings: dtos))
    }

    // MARK: - Recording (parent)

    func startRecording(_ request: FamilyVoiceModels.StartRecordingRequest) async {
        // NIT 2 fix: cancel any ongoing playback before starting a new recording
        playbackTask?.cancel()
        playbackTask = nil
        guard await checkMicPermission() else {
            presenter?.presentError(.init(message: String(localized: "parent_child.error.mic_permission")))
            return
        }

        guard recordings.filter({ $0.word == request.word }).count < FamilyVoiceModels.maxRecordings else {
            presenter?.presentError(.init(message: String(localized: "parent_child.recordings.max_warning")))
            return
        }

        selectedWord = request.word
        do {
            _ = try await recorderWorker.startRecording(word: request.word)
            presenter?.presentRecordingStarted(.init(word: request.word))
            startWaveformPolling()
        } catch {
            logger.error("Start recording failed: \(error)")
            presenter?.presentError(.init(message: String(localized: "parent_child.error.recording_failed")))
        }
    }

    func stopRecording(_ request: FamilyVoiceModels.StopRecordingRequest) async {
        stopWaveformPolling()
        do {
            let (url, duration) = try await recorderWorker.stopRecording()
            let relativePath = try FamilyVoiceRecorderWorker.relativeFilePath(from: url)

            // Check existing for same word — delete old if present
            let existingId = recordings.first(where: { $0.word == request.word })?.id

            let dto = RecordingDTO(
                id: UUID().uuidString,
                word: request.word,
                audioFilePath: relativePath,
                recordedAt: Date(),
                durationSeconds: duration,
                parentProfileId: request.parentId
            )

            // Persist to Realm
            await saveRecordingToRealm(dto: dto, replacingId: existingId)

            // Update in-memory list
            if let existingId {
                recordings.removeAll { $0.id == existingId }
            }
            recordings.append(dto)

            presenter?.presentRecordingStopped(.init(recording: dto, isNew: true))
        } catch {
            logger.error("Stop recording failed: \(error)")
            presenter?.presentError(.init(message: String(localized: "parent_child.error.recording_failed")))
        }
    }

    // MARK: - Playback

    func playRecording(_ request: FamilyVoiceModels.PlayRecordingRequest) async {
        guard let dto = recordings.first(where: { $0.id == request.recordingId }) else { return }
        do {
            let duration = try await recorderWorker.playRecording(filePath: dto.audioFilePath)
            presenter?.presentPlayback(.init(success: true, errorMessage: nil))
            schedulePlaybackEnd(after: duration)
        } catch {
            logger.error("Playback failed: \(error)")
            presenter?.presentPlayback(.init(success: false, errorMessage: String(localized: "parent_child.error.playback_failed")))
        }
    }

    // MARK: - Deletion

    func deleteRecording(_ request: FamilyVoiceModels.DeleteRecordingRequest) async {
        guard let dto = recordings.first(where: { $0.id == request.recordingId }) else { return }
        do {
            try await recorderWorker.deleteRecording(filePath: dto.audioFilePath)
            await deleteRecordingFromRealm(id: request.recordingId)
            recordings.removeAll { $0.id == request.recordingId }
            presenter?.presentDeletion(.init(success: true, deletedId: request.recordingId))
        } catch {
            logger.error("Delete recording failed: \(error)")
            presenter?.presentDeletion(.init(success: false, deletedId: request.recordingId))
        }
    }

    // MARK: - Child recording (split mode)

    func startChildRecording(_ request: FamilyVoiceModels.StartChildRecordingRequest) async {
        guard await checkMicPermission() else {
            presenter?.presentError(.init(message: String(localized: "parent_child.error.mic_permission")))
            return
        }
        do {
            let url = try await recorderWorker.startRecording(word: request.word)
            childAudioFilePath = try FamilyVoiceRecorderWorker.relativeFilePath(from: url)
            isChildRecording = true
            presenter?.presentRecordingStarted(.init(word: request.word))
        } catch {
            logger.error("Child recording start failed: \(error)")
            presenter?.presentError(.init(message: String(localized: "parent_child.error.recording_failed")))
        }
    }

    func stopChildRecording(_ request: FamilyVoiceModels.StopChildRecordingRequest) async {
        guard isChildRecording, let childPath = childAudioFilePath else { return }
        isChildRecording = false

        do {
            _ = try await recorderWorker.stopRecording()
        } catch {
            logger.error("Child recording stop failed: \(error)")
        }

        // Score against word
        let score = await scoringWorker.score(
            childAudioPath: childPath,
            referenceWord: request.word
        )

        // Cleanup child temp file
        try? await recorderWorker.deleteRecording(filePath: childPath)
        childAudioFilePath = nil

        presenter?.presentChildScore(.init(
            score: score,
            transcript: nil,
            word: request.word
        ))

        // Auto-dismiss feedback after 2 seconds (NIT 1 fix: cancel previous before creating new)
        feedbackTask?.cancel()
        feedbackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.0))
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                self?.presenter?.presentFeedbackDismissed()
            }
        }
    }

    // MARK: - Word navigation

    func skipWord(_ request: FamilyVoiceModels.SkipWordRequest) {
        let words = FamilyVoiceModels.targetWordsRaw
        guard let idx = words.firstIndex(of: request.currentWord) else { return }
        let next = words[(idx + 1) % words.count]
        presenter?.presentWordChanged(.init(newWord: next))
    }

    func nextWord(_ request: FamilyVoiceModels.NextWordRequest) {
        let words = FamilyVoiceModels.targetWordsRaw
        guard let idx = words.firstIndex(of: request.currentWord) else { return }
        let next = words[(idx + 1) % words.count]
        presenter?.presentWordChanged(.init(newWord: next))
    }

    func resetSession(_ request: FamilyVoiceModels.ResetSessionRequest) {
        let first = FamilyVoiceModels.targetWordsRaw.first ?? "мяч"
        presenter?.presentWordChanged(.init(newWord: first))
    }

    func selectWord(_ word: String) {
        selectedWord = word
        presenter?.setSelectedWord(word)
    }

    // MARK: - Waveform polling

    private func startWaveformPolling() {
        stopWaveformPolling()
        waveformTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                let level = await self.recorderWorker.currentRMSLevel()
                await MainActor.run { [weak self] in
                    self?.presenter?.presentWaveformUpdate(levels: [level])
                }
                try? await Task.sleep(for: .milliseconds(80))
            }
        }
    }

    private func stopWaveformPolling() {
        waveformTask?.cancel()
        waveformTask = nil
    }

    private func schedulePlaybackEnd(after duration: TimeInterval) {
        playbackTask?.cancel()
        playbackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            await MainActor.run { [weak self] in
                self?.presenter?.presentPlaybackEnded()
            }
        }
    }

    // MARK: - Microphone permission

    private func checkMicPermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    // MARK: - Realm persistence

    private func loadRecordingsFromRealm(parentId: String) async -> [RecordingDTO] {
        await FamilyRecordingStore.fetchAll(parentId: parentId, realmActor: realmActor)
    }

    private func saveRecordingToRealm(dto: RecordingDTO, replacingId: String?) async {
        await FamilyRecordingStore.save(dto: dto, replacingId: replacingId, realmActor: realmActor)
    }

    private func deleteRecordingFromRealm(id: String) async {
        await FamilyRecordingStore.delete(id: id, realmActor: realmActor)
    }

    // MARK: - Cleanup

    func cleanup() {
        stopWaveformPolling()
        playbackTask?.cancel()
        playbackTask = nil
        feedbackTask?.cancel()
        feedbackTask = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// MARK: - FamilyRecordingStore (actor-isolated helpers)

/// Nonisolated static helpers that run on RealmActor — avoids @MainActor → actor boundary closure issues.
enum FamilyRecordingStore {

    static func fetchAll(parentId: String, realmActor: RealmActor) async -> [RecordingDTO] {
        let predicate = NSPredicate(format: "parentProfileId == %@", parentId)
        return (try? await realmActor.fetchFilteredMappedAsync(
            FamilyRecordingObject.self,
            predicate: predicate,
            map: { obj in
                RecordingDTO(
                    id: obj.id,
                    word: obj.word,
                    audioFilePath: obj.audioFilePath,
                    recordedAt: obj.recordedAt,
                    durationSeconds: obj.durationSeconds,
                    parentProfileId: obj.parentProfileId
                )
            }
        )) ?? []
    }

    static func save(dto: RecordingDTO, replacingId: String?, realmActor: RealmActor) async {
        await realmActor.asyncWrite { realm in
            if let oldId = replacingId,
               let old = realm.object(ofType: FamilyRecordingObject.self, forPrimaryKey: oldId) {
                realm.delete(old)
            }
            let obj = FamilyRecordingObject()
            obj.id = dto.id
            obj.word = dto.word
            obj.audioFilePath = dto.audioFilePath
            obj.recordedAt = dto.recordedAt
            obj.durationSeconds = dto.durationSeconds
            obj.parentProfileId = dto.parentProfileId
            realm.add(obj, update: .modified)
        }
    }

    static func delete(id: String, realmActor: RealmActor) async {
        await realmActor.asyncWrite { realm in
            if let obj = realm.object(ofType: FamilyRecordingObject.self, forPrimaryKey: id) {
                realm.delete(obj)
            }
        }
    }
}
