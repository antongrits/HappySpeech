import Foundation

// MARK: - SpeechRiddlesModels

/// Модели игры «Речевые загадки». Загадки строятся из реального словаря
/// (`SpeechRiddlesWorker` → `LessonContentMap`), не из статического seed.
enum SpeechRiddlesModels {

    struct Option: Identifiable, Hashable {
        let id: String
        /// Имя имейджсета (`word_*`), либо nil → плейсхолдер.
        let asset: String?
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
        var isLoaded: Bool

        var current: Riddle? {
            guard currentIndex < riddles.count else { return nil }
            return riddles[currentIndex]
        }

        var isComplete: Bool {
            isLoaded && currentIndex >= riddles.count && !riddles.isEmpty
        }

        var isEmpty: Bool {
            isLoaded && riddles.isEmpty
        }

        var progress: Double {
            guard !riddles.isEmpty else { return 0 }
            return Double(currentIndex) / Double(riddles.count)
        }

        static let initial = ViewState(
            riddles: [],
            currentIndex: 0,
            feedback: .none,
            score: 0,
            isLoaded: false
        )
    }
}
