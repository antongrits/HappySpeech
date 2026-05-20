import Foundation
import OSLog

// MARK: - ObjectDescriptionMapInteractor
//
// VIP-Interactor для «Описательной карты» (Ткаченко).
//
// Поток:
//   1. `loadObjects()`            — отдаёт корпус из 12 объектов.
//   2. `selectObject(id:)`        — ребёнок выбрал объект → план-схема.
//   3. `startRecording()`         — запись аудио через `AudioService`.
//   4. `stopRecordingAndProcess()`— стоп + ASR (WhisperKit) + анализ
//      покрытия пунктов плана через `DescriptionCoverageAnalyzer`.
//   5. `presentRecordResult(...)` через Presenter.
//
// Fail-safe: при отказе записи или ASR пользователю показывается пустой
// транскрипт + честный фидбэк «попробуем ещё раз».

@MainActor
final class ObjectDescriptionMapInteractor {

    // MARK: - Dependencies

    private let presenter: ObjectDescriptionMapPresenter
    private let audioService: any AudioService
    private let asrService: any ASRService
    private let analyzer = DescriptionCoverageAnalyzer()

    private let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ObjectDescriptionMap.Interactor"
    )

    // MARK: - State

    private(set) var selectedObjectId: String?
    private var recordingStartedAt: Date?

    // MARK: - Init

    init(
        presenter: ObjectDescriptionMapPresenter,
        audioService: any AudioService,
        asrService: any ASRService
    ) {
        self.presenter = presenter
        self.audioService = audioService
        self.asrService = asrService
    }

    // MARK: - Load Objects

    func loadObjects() async {
        let objects = ObjectDescriptionMapCorpus.objects
        await presenter.presentLoadObjects(response: .init(objects: objects))
    }

    // MARK: - Select Object

    func selectObject(id: String) async {
        guard ObjectDescriptionMapCorpus.object(id: id) != nil else {
            logger.error("Unknown object id: \(id)")
            return
        }
        selectedObjectId = id
        await presenter.presentSelectObject(response: .init(objectId: id))
    }

    func clearSelection() {
        selectedObjectId = nil
    }

    // MARK: - Recording

    func startRecording() async {
        do {
            try await audioService.startRecording()
            recordingStartedAt = Date()
            logger.info("Description-map recording started.")
        } catch {
            logger.error("Recording start failed: \(error.localizedDescription)")
        }
    }

    /// Останов записи, ASR-транскрипт, анализ покрытия плана,
    /// презентация результата.
    func stopRecordingAndProcess() async {
        let started = recordingStartedAt ?? Date()
        do {
            let url = try await audioService.stopRecording()
            let duration = Date().timeIntervalSince(started)
            let transcript = try await transcribe(url: url)
            await analyseAndPresent(transcript: transcript, duration: duration)
        } catch {
            logger.error("Stop+ASR failed: \(error.localizedDescription)")
            await analyseAndPresent(transcript: "", duration: 0)
        }
    }

    // MARK: - Public for tests

    /// Запускает анализ напрямую (для unit-тестов без записи микрофоном).
    @discardableResult
    func processTranscript(_ transcript: String, duration: Double) async -> DescriptionCoverageReport? {
        await analyseAndPresent(transcript: transcript, duration: duration)
    }

    // MARK: - Private

    private func transcribe(url: URL) async throws -> String {
        let result = try await asrService.transcribe(url: url)
        return result.transcript
    }

    @discardableResult
    private func analyseAndPresent(transcript: String, duration: Double) async -> DescriptionCoverageReport? {
        guard
            let id = selectedObjectId,
            let object = ObjectDescriptionMapCorpus.object(id: id)
        else {
            logger.error("No object selected at analyse stage.")
            return nil
        }
        let coverage = analyzer.analyse(transcript: transcript, plan: object.plan)
        await presenter.presentRecordResult(
            response: .init(
                object: object,
                transcript: transcript,
                durationSeconds: duration,
                coverage: coverage
            )
        )
        return coverage
    }
}
