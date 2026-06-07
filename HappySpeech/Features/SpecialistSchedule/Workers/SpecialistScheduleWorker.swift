import Foundation
import OSLog

// MARK: - SpecialistScheduleWorkerProtocol

@MainActor
protocol SpecialistScheduleWorkerProtocol: AnyObject {
    /// Загружает реальные слоты расписания специалиста на текущую неделю.
    func loadSlots(specialistId: String) async -> [SpecialistScheduleModels.Slot]
}

// MARK: - SpecialistScheduleWorker (Clean Swift: Worker)
//
// Строит расписание из РЕАЛЬНЫХ данных:
//   • `ChildRepository` — имена и целевые звуки детей;
//   • назначенные домашние задания (`HomeworkAssignment`) из того же
//     UserDefaults-хранилища, что и `AssignedHomeworkWorker`
//     (ключ `AssignedHomeworkWorker.storageKey`): срок задания = дата занятия.
// Без фабрикации: если заданий нет — возвращает пустой массив (честный empty).

@MainActor
final class SpecialistScheduleWorker: SpecialistScheduleWorkerProtocol {

    private let childRepository: any ChildRepository
    private let defaults: UserDefaults

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SpecialistSchedule.Worker"
    )

    init(
        childRepository: any ChildRepository,
        defaults: UserDefaults = .standard
    ) {
        self.childRepository = childRepository
        self.defaults = defaults
    }

    func loadSlots(
        specialistId: String
    ) async -> [SpecialistScheduleModels.Slot] {
        // 1. Реальные дети (имя + целевые звуки для темы).
        var childById: [String: ChildProfileDTO] = [:]
        do {
            for child in try await childRepository.fetchAll() {
                childById[child.id] = child
            }
        } catch {
            Self.logger.error(
                "Failed to load children: \(error.localizedDescription, privacy: .public)"
            )
            return []
        }

        // 2. Реальные назначенные задания — то же хранилище, что у конструктора.
        let assignments = loadAssignments()
        guard !assignments.isEmpty else { return [] }

        let calendar = Calendar.current
        let weekRange = currentWeekRange(calendar: calendar)

        // 3. Слоты только за текущую неделю — занятие = срок задания.
        var slots: [SpecialistScheduleModels.Slot] = []
        for assignment in assignments {
            guard let child = childById[assignment.childId] else { continue }
            let due = assignment.dueDate
            guard due >= weekRange.start, due < weekRange.end else { continue }

            let weekdayValue = calendar.component(.weekday, from: due)
            let weekday = SpecialistScheduleModels.Weekday.from(calendarWeekday: weekdayValue)
            slots.append(
                SpecialistScheduleModels.Slot(
                    id: assignment.id,
                    weekday: weekday,
                    date: due,
                    time: Self.timeFormatter.string(from: due),
                    childName: child.name,
                    topic: topic(for: assignment, child: child)
                )
            )
        }
        return slots
    }

    // MARK: - Topic derivation

    /// Тема занятия — из назначенных упражнений (читаемое имя первого
    /// шаблона) либо из целевых звуков ребёнка. Без выдуманных строк.
    private func topic(
        for assignment: HomeworkAssignment,
        child: ChildProfileDTO
    ) -> String {
        if let firstTemplate = assignment.exercises.first?.template {
            if assignment.exercises.count > 1 {
                return "\(firstTemplate.displayName) +\(assignment.exercises.count - 1)"
            }
            return firstTemplate.displayName
        }
        if !child.targetSounds.isEmpty {
            return "Звуки: \(child.targetSounds.joined(separator: ", "))"
        }
        return String(localized: "specialistSchedule.topic.general")
    }

    // MARK: - Week range

    private func currentWeekRange(calendar: Calendar) -> (start: Date, end: Date) {
        let now = Date()
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 7, to: start) ?? now
            return (start, end)
        }
        return (interval.start, interval.end)
    }

    // MARK: - Storage (shared with AssignedHomeworkWorker)

    private func loadAssignments() -> [HomeworkAssignment] {
        guard let data = defaults.data(forKey: AssignedHomeworkWorker.storageKey) else {
            return []
        }
        do {
            return try JSONDecoder().decode([HomeworkAssignment].self, from: data)
        } catch {
            Self.logger.error(
                "Decode assignments failed: \(error.localizedDescription, privacy: .public)"
            )
            return []
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
