import Foundation

// MARK: - AdvancedGrammarPresentationLogic

@MainActor
protocol AdvancedGrammarPresentationLogic: AnyObject {
    func presentStart(_ response: AdvancedGrammarModels.Start.Response)
    func presentRound(_ response: AdvancedGrammarModels.PresentRound.Response)
    func presentPlaying(_ isPlaying: Bool)
    func presentEvaluate(_ response: AdvancedGrammarModels.Evaluate.Response)
    func presentComplete(_ response: AdvancedGrammarModels.Complete.Response)
}

// MARK: - AdvancedGrammarPresenter
//
// Прокидывает Response → Display. Здесь нет вычислений строк помимо тех, что
// зависят от ViewModel (всю текстовую логику локализации Display формирует из
// уже готовых полей Response). Слой тонкий намеренно — Round строится Worker'ом
// и уже содержит локализованные title/subtitle/choices.

@MainActor
final class AdvancedGrammarPresenter: AdvancedGrammarPresentationLogic {

    weak var display: (any AdvancedGrammarDisplayLogic)?

    func presentStart(_ response: AdvancedGrammarModels.Start.Response) {
        display?.displayStart(response)
    }

    func presentRound(_ response: AdvancedGrammarModels.PresentRound.Response) {
        display?.displayRound(response)
    }

    func presentPlaying(_ isPlaying: Bool) {
        display?.displayPlaying(isPlaying)
    }

    func presentEvaluate(_ response: AdvancedGrammarModels.Evaluate.Response) {
        display?.displayEvaluate(response)
    }

    func presentComplete(_ response: AdvancedGrammarModels.Complete.Response) {
        display?.displayComplete(response)
    }
}
