import Foundation
import OSLog

// MARK: - SpecialistCaseNotesInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class SpecialistCaseNotesInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SpecialistCaseNotes"
    )

    let childId: String
    let specialistId: String
    var state: SpecialistCaseNotesModels.ViewState

    init(childId: String, specialistId: String) {
        self.childId = childId
        self.specialistId = specialistId
        self.state = .initial
    }

    func startAdding() {
        state.isAddingNote = true
        state.draftBody = ""
    }

    func cancelAdding() {
        state.isAddingNote = false
        state.draftBody = ""
    }

    func saveNote() {
        let trimmed = state.draftBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let note = SpecialistCaseNotesModels.Note(
            id: UUID(),
            date: Date(),
            body: trimmed
        )
        state.notes.insert(note, at: 0)
        state.draftBody = ""
        state.isAddingNote = false
        Self.logger.info("saveNote childId=\(self.childId, privacy: .private)")
    }
}
