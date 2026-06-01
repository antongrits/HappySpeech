import Foundation
import OSLog

// MARK: - SpecialistCaseNotesInteractor

/// Бизнес-логика «Заметки по случаю» специалиста.
///
/// Заметки реально персистятся в `SpecialistCaseNotesStore` (UserDefaults,
/// per specialist+child): добавленная заметка переживает перезапуск, удаление
/// тоже сохраняется. Без идентификаторов (Preview/тесты) хранилище безопасно
/// возвращает пустой список.
@MainActor
@Observable
final class SpecialistCaseNotesInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SpecialistCaseNotes"
    )

    let childId: String
    let specialistId: String
    var state: SpecialistCaseNotesModels.ViewState = .initial

    private let store: SpecialistCaseNotesStore

    init(
        childId: String,
        specialistId: String,
        defaults: UserDefaults = .standard
    ) {
        self.childId = childId
        self.specialistId = specialistId
        self.store = SpecialistCaseNotesStore(
            defaults: defaults,
            specialistId: specialistId,
            childId: childId
        )
    }

    /// Загружает сохранённые заметки из хранилища.
    func load() {
        state.notes = store.load()
        state.isLoaded = true
        Self.logger.info("loaded \(self.state.notes.count, privacy: .public) notes")
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
        store.save(state.notes)
        Self.logger.info("saveNote childId=\(self.childId, privacy: .private)")
    }

    func deleteNote(_ id: UUID) {
        state.notes.removeAll { $0.id == id }
        store.save(state.notes)
        Self.logger.info("deleteNote childId=\(self.childId, privacy: .private)")
    }
}
