import Foundation
import OSLog

// MARK: - SpecialistCaseNotesStore

/// Локальное персистентное хранилище заметок специалиста по случаю ребёнка.
///
/// Заметки сериализуются JSON-кодеком в `UserDefaults` с ключом, привязанным к
/// паре (специалист, ребёнок), поэтому переживают перезапуск приложения и
/// разделены между разными детьми/специалистами. Без сетевой синхронизации —
/// это локальные рабочие записи специалиста.
struct SpecialistCaseNotesStore {

    private let defaults: UserDefaults
    private let specialistId: String
    private let childId: String

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SpecialistCaseNotes.Store"
    )

    init(defaults: UserDefaults = .standard, specialistId: String, childId: String) {
        self.defaults = defaults
        self.specialistId = specialistId
        self.childId = childId
    }

    private var storageKey: String {
        "specialistCaseNotes.\(specialistId).\(childId)"
    }

    /// Загружает заметки, отсортированные от новых к старым.
    func load() -> [SpecialistCaseNotesModels.Note] {
        guard !specialistId.isEmpty, !childId.isEmpty,
              let data = defaults.data(forKey: storageKey) else {
            return []
        }
        do {
            let notes = try JSONDecoder().decode([SpecialistCaseNotesModels.Note].self, from: data)
            return notes.sorted { $0.date > $1.date }
        } catch {
            Self.logger.error("decode failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    /// Сохраняет полный список заметок.
    func save(_ notes: [SpecialistCaseNotesModels.Note]) {
        guard !specialistId.isEmpty, !childId.isEmpty else { return }
        do {
            let data = try JSONEncoder().encode(notes)
            defaults.set(data, forKey: storageKey)
        } catch {
            Self.logger.error("encode failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
