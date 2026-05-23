import Foundation

// MARK: - SpeechHomeworkPlannerModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum SpeechHomeworkPlannerModels {

    struct Item: Identifiable, Hashable {
        let id: UUID
        let dayOfWeek: String
        let title: String
        var isDone: Bool
    }

    static let seed: [Item] = [
        .init(id: UUID(), dayOfWeek: "Пн", title: "Артикуляция: 5 поз.", isDone: false),
        .init(id: UUID(), dayOfWeek: "Вт", title: "Чтение слов на С", isDone: false),
        .init(id: UUID(), dayOfWeek: "Ср", title: "Игра «Бинго» — 1 раунд", isDone: false),
        .init(id: UUID(), dayOfWeek: "Чт", title: "Дыхательная разминка", isDone: false),
        .init(id: UUID(), dayOfWeek: "Пт", title: "История с Лялей", isDone: false),
        .init(id: UUID(), dayOfWeek: "Сб", title: "Свободное повторение", isDone: false)
    ]
}
