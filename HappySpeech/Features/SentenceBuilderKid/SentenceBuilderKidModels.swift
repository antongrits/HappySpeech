import Foundation

// MARK: - SentenceBuilderKidModels

/// Модели игры «Собери предложение».
///
/// Предложения берутся из контент-каталога (`SentenceBuilderKidContent`),
/// насыщенного рабочим звуком ребёнка. Из перемешанных слов ребёнок собирает
/// фразу в правильном порядке. Каждое решение идёт в outcome планировщика.
enum SentenceBuilderKidModels {

    struct WordChip: Identifiable, Hashable {
        let id: UUID
        let text: String
        let order: Int   // правильная позиция (0-based)
    }

    struct ViewState: Equatable {
        var available: [WordChip]
        var assembled: [WordChip]
        /// Рабочий звук текущего предложения (для outcome).
        var sound: String = "С"
        /// Индекс текущего предложения в наборе раунда.
        var sentenceIndex: Int = 0
        /// Всего предложений в игре.
        var totalSentences: Int = 1
        var solvedCount: Int = 0
        var attempts: Int = 0
        var bestStars: Int = 0
        var isLoaded: Bool = false

        var isCorrect: Bool {
            guard assembled.count == correctCount, correctCount > 0 else { return false }
            for (idx, chip) in assembled.enumerated() where chip.order != idx {
                return false
            }
            return true
        }

        var isFull: Bool {
            assembled.count == correctCount && correctCount > 0
        }

        var correctCount: Int {
            available.count + assembled.count
        }

        var isGameComplete: Bool {
            sentenceIndex >= totalSentences
        }

        var accuracy: Double {
            attempts > 0 ? Double(solvedCount) / Double(attempts) : 0
        }

        var stars: Int {
            guard attempts > 0 else { return 0 }
            switch accuracy {
            case 0.85...: return 3
            case 0.6..<0.85: return 2
            default: return 1
            }
        }

        /// Базовое состояние (Preview / тесты).
        static let initial: ViewState = {
            let sentences = SentenceBuilderKidContent.sentences(for: "С", count: 3)
            var state = ViewState(available: [], assembled: [], sound: "С", isLoaded: true)
            state.totalSentences = sentences.count
            state.load(sentence: sentences.first ?? SentenceBuilderKidContent.fallback)
            return state
        }()

        /// Загружает в состояние конкретное предложение (перемешанные слова).
        mutating func load(sentence: SentenceBuilderKidContent.Sentence) {
            let chips = sentence.words.enumerated().map { idx, word in
                WordChip(id: UUID(), text: word, order: idx)
            }.shuffled()
            available = chips
            assembled = []
            sound = sentence.sound
        }
    }
}
