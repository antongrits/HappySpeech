import Foundation
import OSLog

// MARK: - EveningReflectionStore

/// Локальное персистентное хранилище вечерних рефлексий ребёнка.
///
/// Записи (что было весело/трудно + настроение) сериализуются JSON в
/// `UserDefaults` с ключом, привязанным к ребёнку, и переживают перезапуск.
/// Это локальный дневник; без сетевой синхронизации.
struct EveningReflectionStore {

    private let defaults: UserDefaults
    private let childId: String

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "EveningReflection.Store"
    )

    init(defaults: UserDefaults = .standard, childId: String) {
        self.defaults = defaults
        self.childId = childId
    }

    private var key: String { "eveningReflection.\(childId)" }

    /// Записи от новых к старым (ограничены последними 30).
    func loadHistory() -> [EveningReflectionModels.Entry] {
        guard !childId.isEmpty, let data = defaults.data(forKey: key) else { return [] }
        do {
            let entries = try JSONDecoder().decode([EveningReflectionModels.Entry].self, from: data)
            return entries.sorted { ($0.savedAt ?? .distantPast) > ($1.savedAt ?? .distantPast) }
        } catch {
            Self.logger.error("decode failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    /// Добавляет запись в начало истории и сохраняет (не более 30).
    func append(_ entry: EveningReflectionModels.Entry) -> [EveningReflectionModels.Entry] {
        var history = loadHistory()
        history.insert(entry, at: 0)
        history = Array(history.prefix(30))
        save(history)
        return history
    }

    private func save(_ entries: [EveningReflectionModels.Entry]) {
        guard !childId.isEmpty else { return }
        do {
            let data = try JSONEncoder().encode(entries)
            defaults.set(data, forKey: key)
        } catch {
            Self.logger.error("encode failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
