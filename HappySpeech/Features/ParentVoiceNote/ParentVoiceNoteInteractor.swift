import Foundation
import OSLog

// MARK: - ParentVoiceNoteBusinessLogic

@MainActor
protocol ParentVoiceNoteBusinessLogic: AnyObject {
    func load(request: ParentVoiceNoteModels.Load.Request) async
    func saveClip(request: ParentVoiceNoteModels.SaveClip.Request) async
    func deleteClip(request: ParentVoiceNoteModels.DeleteClip.Request) async
    func toggleEnabled(request: ParentVoiceNoteModels.ToggleEnabled.Request) async
}

// MARK: - ParentVoiceNoteDataStore

@MainActor
protocol ParentVoiceNoteDataStore: AnyObject {
    var childId: String { get set }
    var clips: [ParentVoiceClipData] { get set }
    var isEnabledGlobally: Bool { get set }
}

// MARK: - ParentVoiceNoteInteractor (Clean Swift: Interactor)
//
// v31 Волна B, Функция Ф.4 «Parent voice notes».

@MainActor
final class ParentVoiceNoteInteractor:
    ParentVoiceNoteBusinessLogic, ParentVoiceNoteDataStore {

    var childId: String
    var clips: [ParentVoiceClipData] = []
    var isEnabledGlobally: Bool = true

    var presenter: (any ParentVoiceNotePresentationLogic)?

    private let worker: any ParentVoiceNoteWorkerProtocol
    private let optInService: any ParentVoiceNoteOptInServiceProtocol

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ParentVoiceNote.Interactor"
    )

    init(
        childId: String,
        worker: any ParentVoiceNoteWorkerProtocol,
        optInService: any ParentVoiceNoteOptInServiceProtocol
    ) {
        self.childId = childId
        self.worker = worker
        self.optInService = optInService
    }

    func load(request: ParentVoiceNoteModels.Load.Request) async {
        childId = request.childId
        let fetched = await worker.fetchClips(childId: request.childId)
        clips = fetched
        isEnabledGlobally = optInService.isEnabled(childId: request.childId)
        let response = ParentVoiceNoteModels.Load.Response(
            childId: request.childId,
            templates: LessonTemplateOption.canonical,
            existingClips: fetched,
            isEnabledGlobally: isEnabledGlobally
        )
        await presenter?.presentLoad(response: response)
    }

    func saveClip(request: ParentVoiceNoteModels.SaveClip.Request) async {
        guard let saved = await worker.saveClip(
            childId: request.childId,
            lessonTemplate: request.lessonTemplate,
            tempFileURL: request.fileURL,
            durationSec: request.durationSec
        ) else {
            await presenter?.presentError(message: String(localized: "voice.error.save"))
            return
        }
        clips.removeAll { $0.lessonTemplate == request.lessonTemplate }
        clips.insert(saved, at: 0)
        await presenter?.presentSave(savedClip: saved)
    }

    func deleteClip(request: ParentVoiceNoteModels.DeleteClip.Request) async {
        guard let target = clips.first(where: { $0.id == request.clipId }) else { return }
        let ok = await worker.deleteClip(target)
        if ok {
            clips.removeAll { $0.id == request.clipId }
            await presenter?.presentDelete(deletedId: request.clipId)
        } else {
            await presenter?.presentError(message: String(localized: "voice.error.delete"))
        }
    }

    func toggleEnabled(request: ParentVoiceNoteModels.ToggleEnabled.Request) async {
        optInService.setEnabled(childId: request.childId, isEnabled: request.isEnabled)
        await worker.setEnabledForChild(request.childId, isEnabled: request.isEnabled)
        isEnabledGlobally = request.isEnabled
        await presenter?.presentToggle(isEnabled: request.isEnabled)
    }
}

// MARK: - ParentVoiceNoteOptInServiceProtocol

@MainActor
protocol ParentVoiceNoteOptInServiceProtocol: AnyObject {
    func isEnabled(childId: String) -> Bool
    func setEnabled(childId: String, isEnabled: Bool)
}

// MARK: - UserDefaults-based opt-in storage

@MainActor
final class ParentVoiceNoteOptInService: ParentVoiceNoteOptInServiceProtocol {

    private let defaults: UserDefaults
    private static let keyPrefix = "happyspeech.parentVoiceNote.enabled."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isEnabled(childId: String) -> Bool {
        // По умолчанию включено: запись существует — будет проигрываться.
        // Родитель может выключить из Settings.
        let key = Self.keyPrefix + childId
        return defaults.object(forKey: key) as? Bool ?? true
    }

    func setEnabled(childId: String, isEnabled: Bool) {
        let key = Self.keyPrefix + childId
        defaults.set(isEnabled, forKey: key)
    }
}
