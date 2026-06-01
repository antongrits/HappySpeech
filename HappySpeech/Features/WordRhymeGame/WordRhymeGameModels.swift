import Foundation

// MARK: - WordRhymeGameModels

/// Модели игры «Найди рифму». Контент строится из реального словаря
/// (`WordRhymeGameWorker` → `LessonContentMap`), не из статического seed.
enum WordRhymeGameModels {

    struct RhymeOption: Identifiable, Hashable {
        let id: String
        let word: String
        /// Имя имейджсета (`word_*`) для иллюстрации, либо nil → плейсхолдер.
        let asset: String?
    }

    struct Round: Identifiable, Hashable {
        let id: String
        let targetWord: String
        let targetAsset: String?
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
        var isLoaded: Bool

        var current: Round? {
            guard index < rounds.count else { return nil }
            return rounds[index]
        }

        var isComplete: Bool {
            isLoaded && index >= rounds.count && !rounds.isEmpty
        }

        /// Истинно пустой словарь (контент не загрузился) — для empty-state.
        var isEmpty: Bool {
            isLoaded && rounds.isEmpty
        }

        var progress: Double {
            guard !rounds.isEmpty else { return 0 }
            return Double(index) / Double(rounds.count)
        }

        static let initial = ViewState(
            rounds: [],
            index: 0,
            feedback: .none,
            score: 0,
            isLoaded: false
        )
    }
}
