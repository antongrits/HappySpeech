import Foundation
import OSLog

// MARK: - MorningRoutineStore

/// Локальное персистентное хранилище состояния утренней рутины.
///
/// Состояние привязано к паре (ребёнок, день): отмеченные шаги переживают
/// перезапуск, а на следующий день рутина начинается заново. Хранится в
/// `UserDefaults` (JSON-набор выполненных шагов с датой).
struct MorningRoutineStore {

    private let defaults: UserDefaults
    private let childId: String
    private let calendar: Calendar

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "MorningRoutine.Store"
    )

    init(
        defaults: UserDefaults = .standard,
        childId: String,
        calendar: Calendar = .current
    ) {
        self.defaults = defaults
        self.childId = childId
        self.calendar = calendar
    }

    private var key: String { "morningRoutine.\(childId)" }

    private struct Saved: Codable {
        var dayKey: String
        var doneSteps: [String]
    }

    private func dayKey(for date: Date = Date()) -> String {
        let day = calendar.startOfDay(for: date)
        let comps = calendar.dateComponents([.year, .month, .day], from: day)
        return "\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)"
    }

    /// Выполненные сегодня шаги. Если запись с прошлого дня — начинаем заново.
    func loadDoneSteps(for date: Date = Date()) -> Set<MorningRoutineModels.StepKind> {
        guard !childId.isEmpty, let data = defaults.data(forKey: key) else { return [] }
        do {
            let saved = try JSONDecoder().decode(Saved.self, from: data)
            guard saved.dayKey == dayKey(for: date) else { return [] }
            return Set(saved.doneSteps.compactMap { MorningRoutineModels.StepKind(rawValue: $0) })
        } catch {
            Self.logger.error("decode failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    /// Сохраняет выполненные шаги текущего дня.
    func save(doneSteps: Set<MorningRoutineModels.StepKind>, for date: Date = Date()) {
        guard !childId.isEmpty else { return }
        let saved = Saved(dayKey: dayKey(for: date), doneSteps: doneSteps.map(\.rawValue))
        do {
            let data = try JSONEncoder().encode(saved)
            defaults.set(data, forKey: key)
        } catch {
            Self.logger.error("encode failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
