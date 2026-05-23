import Foundation

// MARK: - LyalyaPersonalCoachModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum LyalyaPersonalCoachModels {

    struct Round: Identifiable, Hashable {
        let id: Int
        let question: String
        let options: [String]
        let correctIndex: Int
    }

    enum Reaction: Equatable {
        case none
        case correct
        case tryAgain
    }

    /// 5 раундов простых вопросов.
    static let seedRounds: [Round] = [
        .init(id: 1,
              question: "Какой первый звук в слове «сова»?",
              options: ["С", "О", "В", "А"], correctIndex: 0),
        .init(id: 2,
              question: "Что Ляля любит больше всего?",
              options: ["Играть", "Спать", "Молчать", "Кричать"], correctIndex: 0),
        .init(id: 3,
              question: "Какой звук жужжит как пчела?",
              options: ["Ж", "К", "Т", "С"], correctIndex: 0),
        .init(id: 4,
              question: "С чего начинается «рыба»?",
              options: ["Р", "Ы", "Б", "А"], correctIndex: 0),
        .init(id: 5,
              question: "Какое настроение у улыбки?",
              options: ["Радостное", "Грустное", "Сонное", "Сердитое"], correctIndex: 0)
    ]
}
