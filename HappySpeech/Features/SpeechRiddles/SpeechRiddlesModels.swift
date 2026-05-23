import Foundation

// MARK: - SpeechRiddlesModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum SpeechRiddlesModels {

    struct Option: Identifiable, Hashable {
        let id: String
        let emoji: String
        let label: String
        let startsWith: String
    }

    struct Riddle: Identifiable, Hashable {
        let id: String
        let prompt: String
        let targetLetter: String
        let options: [Option]
        let correctOptionId: String
    }

    enum Feedback: Hashable {
        case none
        case correct
        case wrong(String)
    }

    struct ViewState: Equatable {
        var riddles: [Riddle]
        var currentIndex: Int
        var feedback: Feedback
        var score: Int

        var current: Riddle? {
            guard currentIndex < riddles.count else { return nil }
            return riddles[currentIndex]
        }

        var isComplete: Bool {
            currentIndex >= riddles.count
        }

        var progress: Double {
            guard !riddles.isEmpty else { return 0 }
            return Double(currentIndex) / Double(riddles.count)
        }

        static let initial = ViewState(
            riddles: [
                Riddle(
                    id: "r1",
                    prompt: "Что начинается на «Р»?",
                    targetLetter: "Р",
                    options: [
                        Option(id: "o1", emoji: "🌹", label: "Роза", startsWith: "Р"),
                        Option(id: "o2", emoji: "🐱", label: "Кот", startsWith: "К"),
                        Option(id: "o3", emoji: "🌳", label: "Дерево", startsWith: "Д"),
                        Option(id: "o4", emoji: "🍎", label: "Яблоко", startsWith: "Я")
                    ],
                    correctOptionId: "o1"
                ),
                Riddle(
                    id: "r2",
                    prompt: "Что начинается на «С»?",
                    targetLetter: "С",
                    options: [
                        Option(id: "o1", emoji: "🐘", label: "Слон", startsWith: "С"),
                        Option(id: "o2", emoji: "🍌", label: "Банан", startsWith: "Б"),
                        Option(id: "o3", emoji: "🦋", label: "Бабочка", startsWith: "Б"),
                        Option(id: "o4", emoji: "🚗", label: "Машина", startsWith: "М")
                    ],
                    correctOptionId: "o1"
                ),
                Riddle(
                    id: "r3",
                    prompt: "Что начинается на «Л»?",
                    targetLetter: "Л",
                    options: [
                        Option(id: "o1", emoji: "🐭", label: "Мышь", startsWith: "М"),
                        Option(id: "o2", emoji: "🦁", label: "Лев", startsWith: "Л"),
                        Option(id: "o3", emoji: "🐧", label: "Пингвин", startsWith: "П"),
                        Option(id: "o4", emoji: "🐠", label: "Рыба", startsWith: "Р")
                    ],
                    correctOptionId: "o2"
                )
            ],
            currentIndex: 0,
            feedback: .none,
            score: 0
        )
    }
}
