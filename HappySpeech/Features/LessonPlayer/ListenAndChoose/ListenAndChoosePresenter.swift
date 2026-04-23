import Foundation

// MARK: - ListenAndChoosePresentationLogic

@MainActor
protocol ListenAndChoosePresentationLogic: AnyObject {
    func presentLoadRound(_ response: ListenAndChooseModels.LoadRound.Response)
    func presentSubmitAttempt(_ response: ListenAndChooseModels.SubmitAttempt.Response)
}

// MARK: - ListenAndChoosePresenter

@MainActor
final class ListenAndChoosePresenter: ListenAndChoosePresentationLogic {

    weak var display: (any ListenAndChooseDisplayLogic)?

    func presentLoadRound(_ response: ListenAndChooseModels.LoadRound.Response) {
        let options = response.options.map { item in
            ListenAndChooseModels.LoadRound.OptionViewModel(
                id: item.id,
                word: item.word,
                imageSystemName: Self.imageSymbol(for: item.word)
            )
        }
        let vm = ListenAndChooseModels.LoadRound.ViewModel(
            targetWord: response.targetWord,
            options: options,
            correctIndex: response.correctIndex,
            instructionText: String(localized: "Слушай внимательно и выбери картинку")
        )
        display?.displayLoadRound(vm)
    }

    func presentSubmitAttempt(_ response: ListenAndChooseModels.SubmitAttempt.Response) {
        let feedback: String = {
            if response.isCorrect {
                return String(localized: "Правильно!")
            }
            if response.shouldRevealAnswer {
                return String(localized: "Вот правильный ответ")
            }
            return String(localized: "Попробуй ещё раз")
        }()

        let vm = ListenAndChooseModels.SubmitAttempt.ViewModel(
            isCorrect: response.isCorrect,
            feedbackText: feedback,
            shouldRevealAnswer: response.shouldRevealAnswer,
            correctIndex: response.correctIndex,
            finalScore: (response.isCorrect || response.shouldRevealAnswer) ? response.score : nil
        )
        display?.displaySubmitAttempt(vm)
    }

    // MARK: Private

    /// Picks a generic SF Symbol as a placeholder image for a word. Real asset lookup
    /// happens in production via `Content/Images/<word>.png`; this is a safe fallback.
    private static func imageSymbol(for word: String) -> String {
        let first = word.lowercased().first
        switch first {
        case "р", "r": return "circle.grid.2x2"
        case "с", "s": return "sun.max"
        case "ш", "w": return "leaf"
        case "л", "l": return "moon"
        case "к", "k": return "key"
        default:       return "star"
        }
    }
}
