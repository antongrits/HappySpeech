import Foundation

// MARK: - SpecialistCaseNotesModels

/// Модели «Заметки по случаю» специалиста. Заметки реально хранятся в
/// `UserDefaults` (см. `SpecialistCaseNotesStore`) и переживают перезапуск.
enum SpecialistCaseNotesModels {

    struct Note: Identifiable, Hashable, Codable {
        let id: UUID
        let date: Date
        let body: String
    }

    struct ViewState: Equatable {
        var notes: [Note]
        var isAddingNote: Bool
        var draftBody: String
        var isLoaded: Bool

        var isEmpty: Bool {
            isLoaded && notes.isEmpty
        }

        static let initial = ViewState(
            notes: [],
            isAddingNote: false,
            draftBody: "",
            isLoaded: false
        )
    }
}
