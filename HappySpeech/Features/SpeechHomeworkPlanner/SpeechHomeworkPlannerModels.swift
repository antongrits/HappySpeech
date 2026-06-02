import Foundation

// MARK: - SpeechHomeworkPlannerModels

/// Недельный план домашней практики. Это рекомендованный **шаблон** недели
/// (не персональное назначение специалиста — честно помечено в UI). Отметки
/// «выполнено» персистятся (см. интерактор), поэтому id уровней стабильны.
enum SpeechHomeworkPlannerModels {

    struct Item: Identifiable, Hashable {
        /// Стабильный строковый id (для персистентности отметок).
        let id: String
        let dayOfWeek: String
        let title: String
        var isDone: Bool
    }

    /// Рекомендованный недельный шаблон. id стабильны между запусками.
    static let seed: [Item] = [
        .init(id: "hw-mon", dayOfWeek: "Пн", title: "Артикуляция: 5 поз.", isDone: false),
        .init(id: "hw-tue", dayOfWeek: "Вт", title: "Чтение слов на С", isDone: false),
        .init(id: "hw-wed", dayOfWeek: "Ср", title: "Игра «Бинго» — 1 раунд", isDone: false),
        .init(id: "hw-thu", dayOfWeek: "Чт", title: "Дыхательная разминка", isDone: false),
        .init(id: "hw-fri", dayOfWeek: "Пт", title: "История с Лялей", isDone: false),
        .init(id: "hw-sat", dayOfWeek: "Сб", title: "Свободное повторение", isDone: false)
    ]
}
