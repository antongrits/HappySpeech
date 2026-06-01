import Foundation
import OSLog

// MARK: - SpecialistQuickAssessmentStore

/// Локальное персистентное хранилище экспресс-оценки специалиста по ребёнку.
///
/// Оценки по категориям (звёзды 0–5) сериализуются JSON-кодеком в
/// `UserDefaults` с ключом, привязанным к паре (специалист, ребёнок), поэтому
/// переживают перезапуск и разделены между разными детьми/специалистами.
/// Без идентификаторов (Preview/тесты) хранилище безопасно возвращает `nil`.
struct SpecialistQuickAssessmentStore {

    /// Персистентная запись одной экспресс-оценки.
    struct Record: Codable, Equatable {
        let date: Date
        /// Звёзды по категориям: ключ — `Category.rawValue`.
        let stars: [String: Int]
    }

    private let defaults: UserDefaults
    private let specialistId: String
    private let childId: String

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SpecialistQuickAssessment.Store"
    )

    init(defaults: UserDefaults = .standard, specialistId: String, childId: String) {
        self.defaults = defaults
        self.specialistId = specialistId
        self.childId = childId
    }

    private var storageKey: String {
        "specialistQuickAssessment.\(specialistId).\(childId)"
    }

    /// Загружает последнюю сохранённую оценку (или `nil`, если её нет).
    func load() -> Record? {
        guard !specialistId.isEmpty, !childId.isEmpty,
              let data = defaults.data(forKey: storageKey) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(Record.self, from: data)
        } catch {
            Self.logger.error("decode failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Сохраняет оценку. Без идентификаторов — no-op (возвращает false).
    @discardableResult
    func save(_ record: Record) -> Bool {
        guard !specialistId.isEmpty, !childId.isEmpty else { return false }
        do {
            let data = try JSONEncoder().encode(record)
            defaults.set(data, forKey: storageKey)
            return true
        } catch {
            Self.logger.error("encode failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
