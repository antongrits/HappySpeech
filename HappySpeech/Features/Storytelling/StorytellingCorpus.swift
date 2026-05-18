import Foundation

// MARK: - StorytellingCorpus
//
// v29 Фаза 8, Функция 11 «Я расскажу историю».
//
// Стартовый корпус тем-стимулов с планами-схемами рассказа. Темы возрастные
// (7–8 лет), близкие личному опыту ребёнка. План-схема даёт опору
// программированию высказывания (кто — что делает — какой — где).
// Представительный набор; расширяется командой speech-content-curator.
// Полностью offline / on-device.

enum StorytellingCorpus {

    /// Универсальный план-схема «кто — где — что делает — чем закончилось».
    static func narrativePlan(prefix: String) -> [StoryPlanStep] {
        [
            .init(id: "\(prefix)-who",
                  question: "Кто главный герой рассказа?",
                  symbolName: "person.fill"),
            .init(id: "\(prefix)-where",
                  question: "Где происходит история?",
                  symbolName: "mappin.circle.fill"),
            .init(id: "\(prefix)-what",
                  question: "Что произошло? Что делал герой?",
                  symbolName: "figure.run"),
            .init(id: "\(prefix)-end",
                  question: "Чем всё закончилось?",
                  symbolName: "checkmark.seal.fill")
        ]
    }

    // MARK: - Topics

    static let topics: [StoryTopic] = [
        .init(id: "zoo-trip", title: "Прогулка в зоопарк",
              symbolName: "tortoise.fill",
              plan: narrativePlan(prefix: "zoo")),
        .init(id: "birthday", title: "Мой день рождения",
              symbolName: "gift.fill",
              plan: narrativePlan(prefix: "bday")),
        .init(id: "winter-walk", title: "Зимняя прогулка",
              symbolName: "snowflake",
              plan: narrativePlan(prefix: "winter")),
        .init(id: "favorite-toy", title: "Моя любимая игрушка",
              symbolName: "teddybear.fill",
              plan: narrativePlan(prefix: "toy")),
        .init(id: "summer-day", title: "Летний день",
              symbolName: "sun.max.fill",
              plan: narrativePlan(prefix: "summer")),
        .init(id: "forest-trip", title: "Поход в лес",
              symbolName: "tree.fill",
              plan: narrativePlan(prefix: "forest")),
        .init(id: "helping-mom", title: "Как я помогал маме",
              symbolName: "heart.fill",
              plan: narrativePlan(prefix: "mom")),
        .init(id: "new-friend", title: "Мой новый друг",
              symbolName: "person.2.fill",
              plan: narrativePlan(prefix: "friend"))
    ]

    // MARK: - Queries

    /// Тема по идентификатору.
    static func topic(id: String) -> StoryTopic? {
        topics.first { $0.id == id }
    }
}
