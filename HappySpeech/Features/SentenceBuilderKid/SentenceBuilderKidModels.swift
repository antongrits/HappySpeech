import Foundation

// MARK: - SentenceBuilderKidModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum SentenceBuilderKidModels {

    struct WordChip: Identifiable, Hashable {
        let id: UUID
        let text: String
        let order: Int   // правильная позиция (0-based)
    }

    struct ViewState: Equatable {
        var available: [WordChip]
        var assembled: [WordChip]

        var isCorrect: Bool {
            guard assembled.count == correctCount else { return false }
            for (idx, chip) in assembled.enumerated() where chip.order != idx {
                return false
            }
            return true
        }

        var isFull: Bool {
            assembled.count == correctCount
        }

        var correctCount: Int {
            available.count + assembled.count
        }

        static let correctSentence: [(text: String, order: Int)] = [
            (text: "Лиса",    order: 0),
            (text: "бежит",   order: 1),
            (text: "по",      order: 2),
            (text: "зелёному", order: 3),
            (text: "лесу",    order: 4)
        ]

        static let initial: ViewState = {
            let chips = correctSentence.map { item in
                WordChip(id: UUID(), text: item.text, order: item.order)
            }.shuffled()
            return ViewState(available: chips, assembled: [])
        }()
    }
}
