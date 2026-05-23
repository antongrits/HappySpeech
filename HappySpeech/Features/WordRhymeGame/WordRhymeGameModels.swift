import Foundation

// MARK: - WordRhymeGameModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum WordRhymeGameModels {

    struct RhymeOption: Identifiable, Hashable {
        let id: String
        let word: String
        let emoji: String
    }

    struct Round: Identifiable, Hashable {
        let id: String
        let targetWord: String
        let targetEmoji: String
        let options: [RhymeOption]
        let correctOptionId: String
    }

    enum Feedback: Hashable {
        case none
        case correct
        case wrong(String)
    }

    struct ViewState: Equatable {
        var rounds: [Round]
        var index: Int
        var feedback: Feedback
        var score: Int

        var current: Round? {
            guard index < rounds.count else { return nil }
            return rounds[index]
        }

        var isComplete: Bool {
            index >= rounds.count
        }

        var progress: Double {
            guard !rounds.isEmpty else { return 0 }
            return Double(index) / Double(rounds.count)
        }

        static let initial = ViewState(
            rounds: [
                Round(
                    id: "r1",
                    targetWord: "Кошка",
                    targetEmoji: "🐱",
                    options: [
                        RhymeOption(id: "o1", word: "Мошка", emoji: "🪰"),
                        RhymeOption(id: "o2", word: "Дом",   emoji: "🏠"),
                        RhymeOption(id: "o3", word: "Лук",   emoji: "🧅")
                    ],
                    correctOptionId: "o1"
                ),
                Round(
                    id: "r2",
                    targetWord: "Мишка",
                    targetEmoji: "🐻",
                    options: [
                        RhymeOption(id: "o1", word: "Стол",   emoji: "🪑"),
                        RhymeOption(id: "o2", word: "Шишка",  emoji: "🌰"),
                        RhymeOption(id: "o3", word: "Шар",    emoji: "🎈")
                    ],
                    correctOptionId: "o2"
                ),
                Round(
                    id: "r3",
                    targetWord: "Кот",
                    targetEmoji: "🐈",
                    options: [
                        RhymeOption(id: "o1", word: "Стол",   emoji: "🪑"),
                        RhymeOption(id: "o2", word: "Гном",   emoji: "🧙"),
                        RhymeOption(id: "o3", word: "Бегемот", emoji: "🦛")
                    ],
                    correctOptionId: "o3"
                )
            ],
            index: 0,
            feedback: .none,
            score: 0
        )
    }
}
