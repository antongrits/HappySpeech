import Foundation
import OSLog

// MARK: - OralStoryCreatorInteractor

@MainActor
final class OralStoryCreatorInteractor {

    private let presenter: OralStoryCreatorPresenter
    private let audioService: any AudioService
    private let asrService: any ASRService
    private let realmActor: RealmActor
    private let childId: String
    private let calculator = LexicalDiversityCalculator()
    private let logger = Logger(
        subsystem: "ru.happyspeech", category: "OralStoryCreator.Interactor"
    )

    private(set) var selectedIds: [String] = []
    private var recordingStartedAt: Date?
    private var lastRecordedURL: URL?

    init(
        presenter: OralStoryCreatorPresenter,
        audioService: any AudioService,
        asrService: any ASRService,
        realmActor: RealmActor,
        childId: String
    ) {
        self.presenter = presenter
        self.audioService = audioService
        self.asrService = asrService
        self.realmActor = realmActor
        self.childId = childId
    }

    // MARK: - Lifecycle

    func loadStimuli() async {
        let stimuli = OralStoryCreatorCorpus.stimuli
        await presenter.presentLoadStimuli(response: .init(stimuli: stimuli))
        await presenter.presentSelection(response: .init(selectedIds: selectedIds))
    }

    // MARK: - Selection

    /// Toggles a stimulus into / out of the selection set, capped at 3.
    func toggleSelection(_ stimulusId: String) async {
        if let idx = selectedIds.firstIndex(of: stimulusId) {
            selectedIds.remove(at: idx)
        } else if selectedIds.count < OralStoryCreatorCorpus.pickCountTarget {
            selectedIds.append(stimulusId)
        }
        await presenter.presentSelection(response: .init(selectedIds: selectedIds))
    }

    func resetSelection() async {
        selectedIds.removeAll()
        await presenter.presentSelection(response: .init(selectedIds: selectedIds))
    }

    // MARK: - Recording

    func startRecording() async {
        do {
            try await audioService.startRecording()
            recordingStartedAt = Date()
            logger.info("Oral story recording started.")
        } catch {
            logger.error("Recording start failed: \(error.localizedDescription)")
        }
    }

    /// Останов записи, ASR-транскрипт, сохранение Realm-объекта,
    /// презентация результата.
    func stopRecordingAndProcess() async {
        let started = recordingStartedAt ?? Date()
        do {
            let url = try await audioService.stopRecording()
            lastRecordedURL = url
            let duration = Date().timeIntervalSince(started)
            let transcript = try await transcribe(url: url)
            await saveAndPresent(transcript: transcript, duration: duration)
        } catch {
            logger.error("Stop+ASR failed: \(error.localizedDescription)")
            await saveAndPresent(transcript: "", duration: 0)
        }
    }

    // MARK: - Public for tests

    /// Сохраняет рассказ напрямую (для тестов без записи микрофоном).
    @discardableResult
    func saveStory(transcript: String, duration: Double) async -> ChildOralStoryData {
        let analysis = calculator.analyse(transcript: transcript)
        let data = ChildOralStoryData(
            id: UUID().uuidString,
            childId: childId,
            createdAt: Date(),
            transcript: transcript,
            durationSeconds: duration,
            stimulusIds: selectedIds,
            lexicalDiversity: analysis.ttr,
            totalWords: analysis.total,
            uniqueWords: analysis.unique
        )
        await realmActor.persistOralStory(data)
        return data
    }

    // MARK: - Private

    private func transcribe(url: URL) async throws -> String {
        let result = try await asrService.transcribe(url: url)
        return result.transcript
    }

    private func saveAndPresent(transcript: String, duration: Double) async {
        let data = await saveStory(transcript: transcript, duration: duration)
        let stimuli = OralStoryCreatorCorpus.stimuli.filter { selectedIds.contains($0.id) }
        await presenter.presentRecordResult(
            response: .init(
                transcript: transcript,
                durationSeconds: duration,
                stimuli: stimuli,
                savedStoryId: data.id
            )
        )
    }
}
