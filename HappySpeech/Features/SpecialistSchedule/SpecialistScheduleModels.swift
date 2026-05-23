import Foundation

// MARK: - SpecialistScheduleModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
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
    }

    struct Slot: Identifiable, Hashable {
        let id: String
        let weekday: Weekday
        let time: String
        let childName: String
        let topic: String
    }

    struct ViewState: Equatable {
        var slots: [Slot]
        var selectedWeekday: Weekday

        func slotsFor(_ weekday: Weekday) -> [Slot] {
            slots.filter { $0.weekday == weekday }
        }

        static let initial = ViewState(
            slots: [
                Slot(id: "s1", weekday: .mon, time: "10:00", childName: "Аня К.", topic: "Звук Р"),
                Slot(id: "s2", weekday: .mon, time: "11:30", childName: "Миша П.", topic: "Свистящие"),
                Slot(id: "s3", weekday: .tue, time: "09:00", childName: "Ваня Г.", topic: "Шипящие"),
                Slot(id: "s4", weekday: .tue, time: "15:00", childName: "Лена С.", topic: "Соноры"),
                Slot(id: "s5", weekday: .wed, time: "10:00", childName: "Аня К.", topic: "Звук Р"),
                Slot(id: "s6", weekday: .wed, time: "13:00", childName: "Кирилл М.", topic: "Слоги"),
                Slot(id: "s7", weekday: .thu, time: "11:00", childName: "Маша Б.", topic: "Фонематика"),
                Slot(id: "s8", weekday: .fri, time: "10:00", childName: "Миша П.", topic: "Свистящие"),
                Slot(id: "s9", weekday: .fri, time: "14:00", childName: "Аня К.", topic: "Скороговорки"),
                Slot(id: "s10", weekday: .sat, time: "11:00", childName: "Ваня Г.", topic: "Рассказ")
            ],
            selectedWeekday: .mon
        )
    }
}
