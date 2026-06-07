import Foundation

// MARK: - SpecialistScheduleModels (Clean Swift: Models)
//
// Расписание занятий специалиста. Источник данных РЕАЛЬНЫЙ:
//   • дети — `ChildRepository` (профили, к которым подключён специалист);
//   • запланированные занятия — назначенные домашние задания
//     (`HomeworkAssignment`, общее хранилище с `AssignedHomeworkWorker`):
//     `dueDate` задания = дата занятия, `childId` → имя ребёнка, набор
//     упражнений → тема.
// Никаких выдуманных детей/слотов: при отсутствии заданий — честный empty-state.

enum SpecialistScheduleModels {

    enum Weekday: Int, CaseIterable, Hashable, Identifiable {
        case mon = 1, tue, wed, thu, fri, sat, sun

        var id: Int { rawValue }

        var shortTitle: String {
            switch self {
            case .mon: return "Пн"
            case .tue: return "Вт"
            case .wed: return "Ср"
            case .thu: return "Чт"
            case .fri: return "Пт"
            case .sat: return "Сб"
            case .sun: return "Вс"
            }
        }

        /// Преобразование из `Calendar.component(.weekday)` (1 = воскресенье).
        static func from(calendarWeekday: Int) -> Weekday {
            switch calendarWeekday {
            case 1: return .sun
            case 2: return .mon
            case 3: return .tue
            case 4: return .wed
            case 5: return .thu
            case 6: return .fri
            default: return .sat
            }
        }
    }

    struct Slot: Identifiable, Hashable {
        let id: String
        let weekday: Weekday
        /// Дата занятия (срок назначенного задания).
        let date: Date
        let time: String
        let childName: String
        /// Тема — выводится из назначенных упражнений / целевых звуков ребёнка.
        let topic: String
    }

    struct ViewState: Equatable {
        var slots: [Slot]
        var selectedWeekday: Weekday
        var isLoading: Bool

        func slotsFor(_ weekday: Weekday) -> [Slot] {
            slots
                .filter { $0.weekday == weekday }
                .sorted { $0.date < $1.date }
        }

        /// Нейтральное стартовое состояние — без выдуманных данных.
        /// Реальные слоты приходят из `SpecialistScheduleWorker.load`.
        static let initial = ViewState(
            slots: [],
            selectedWeekday: Weekday.from(
                calendarWeekday: Calendar.current.component(.weekday, from: Date())
            ),
            isLoading: true
        )
    }
}
