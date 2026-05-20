import Foundation
import OSLog

// MARK: - ParentVoiceNotePresentationLogic

@MainActor
protocol ParentVoiceNotePresentationLogic: AnyObject {
    func presentLoad(response: ParentVoiceNoteModels.Load.Response) async
    func presentSave(savedClip: ParentVoiceClipData) async
    func presentDelete(deletedId: String) async
    func presentToggle(isEnabled: Bool) async
    func presentError(message: String) async
}

// MARK: - ParentVoiceNotePresenter (Clean Swift: Presenter)
//
// v31 Волна B, Функция Ф.4 «Parent voice notes».

@MainActor
final class ParentVoiceNotePresenter: ParentVoiceNotePresentationLogic {

    weak var displayLogic: (any ParentVoiceNoteDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ParentVoiceNote.Presenter"
    )

    init(displayLogic: (any ParentVoiceNoteDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    func presentLoad(response: ParentVoiceNoteModels.Load.Response) async {
        let viewModel = Self.makeViewModel(response: response)
        await displayLogic?.displayLoad(viewModel: viewModel)
    }

    func presentSave(savedClip: ParentVoiceClipData) async {
        await displayLogic?.displaySave(savedClip: savedClip)
    }

    func presentDelete(deletedId: String) async {
        await displayLogic?.displayDelete(deletedId: deletedId)
    }

    func presentToggle(isEnabled: Bool) async {
        await displayLogic?.displayToggle(isEnabled: isEnabled)
    }

    func presentError(message: String) async {
        await displayLogic?.displayError(message: message)
    }

    // MARK: - Helpers

    static func makeViewModel(
        response: ParentVoiceNoteModels.Load.Response
    ) -> ParentVoiceNoteModels.Load.ViewModel {
        let clipsByTemplate = Dictionary(
            grouping: response.existingClips,
            by: \.lessonTemplate
        )
        let templates = response.templates.map { option -> ParentVoiceNoteModels.Load.TemplateViewModel in
            let clip = clipsByTemplate[option.id]?
                .sorted(by: { $0.recordedAt > $1.recordedAt })
                .first
            return ParentVoiceNoteModels.Load.TemplateViewModel(
                id: option.id,
                title: Self.localized(option.title),
                symbolName: option.symbolName,
                hasClip: clip != nil,
                durationLabel: clip.map { formatDuration($0.durationSec) },
                recordedAtLabel: clip.map { formatRecordedAt($0.recordedAt) }
            )
        }
        return .init(
            title: String(localized: "voice.title"),
            introMessage: String(localized: "voice.intro"),
            templates: templates,
            isEnabledGlobally: response.isEnabledGlobally,
            optInLabel: String(localized: "voice.optIn.title"),
            optInSubtitle: String(localized: "voice.optIn.subtitle")
        )
    }

    static func localized(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }

    static func formatDuration(_ seconds: Double) -> String {
        let rounded = max(0, Int(seconds.rounded()))
        return String(
            format: String(localized: "voice.duration"),
            rounded
        )
    }

    static func formatRecordedAt(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
