import Foundation
import OSLog

// MARK: - ParentMoodCheckInInteractor

/// Чек-ин настроения родителя. Запись реально персистится (UserDefaults):
/// сохраняется последнее настроение, заметка и история отметок. Раньше `save()`
/// только логировал и ничего не сохранял.
@MainActor
@Observable
final class ParentMoodCheckInInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ParentMoodCheckIn"
    )

    /// Одна запись настроения в истории (Codable — для UserDefaults).
    struct MoodRecord: Codable, Equatable, Sendable {
        let mood: String        // ParentMoodCheckInModels.Mood.rawValue
        let note: String
        let savedAt: Date
    }

    var entry: ParentMoodCheckInModels.Entry = .init()
    var lastSavedAt: Date?
    /// История чек-инов, новейшие — первыми.
    private(set) var history: [MoodRecord] = []

    private let defaults: UserDefaults
    private static let storageKey = "parentMood.history"
    private static let maxHistory = 60

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadHistory()
        lastSavedAt = history.first?.savedAt
    }

    func save() {
        guard let mood = entry.mood else { return }
        let record = MoodRecord(mood: mood.rawValue, note: entry.note, savedAt: Date())
        history.insert(record, at: 0)
        if history.count > Self.maxHistory {
            history = Array(history.prefix(Self.maxHistory))
        }
        persistHistory()
        lastSavedAt = record.savedAt
        Self.logger.info("Parent mood saved: \(mood.rawValue, privacy: .public)")
    }

    // MARK: - Persistence

    private func loadHistory() {
        guard let data = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([MoodRecord].self, from: data) else {
            return
        }
        history = decoded
    }

    private func persistHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
