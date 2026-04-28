import Foundation

// MARK: - StutteringPresentationLogic

@MainActor
protocol StutteringPresentationLogic: AnyObject {
    func presentLoadScreen(_ response: StutteringModels.LoadScreen.Response)
    func presentSelectMode(_ response: StutteringModels.SelectMode.Response)
}

// MARK: - StutteringPresenter

@MainActor
final class StutteringPresenter: StutteringPresentationLogic {

    weak var view: (any StutteringDisplayLogic)?

    // MARK: - Load Screen

    func presentLoadScreen(_ response: StutteringModels.LoadScreen.Response) {
        let cards = response.cards.map { card in
            ExerciseCardViewModel(
                mode: card.mode,
                title: localizedTitle(for: card.mode),
                subtitle: localizedSubtitle(for: card.mode),
                symbol: card.symbol,
                symbolColor: card.symbolColor,
                duration: card.duration,
                accessibilityLabel: "\(localizedTitle(for: card.mode)), \(card.duration)"
            )
        }
        let viewModel = StutteringModels.LoadScreen.ViewModel(
            cards: cards,
            showWelcomeSheet: !response.hasSeenWelcome
        )
        view?.displayLoadScreen(viewModel)
    }

    func presentSelectMode(_ response: StutteringModels.SelectMode.Response) {
        view?.displaySelectMode(.init(mode: response.mode))
    }

    // MARK: - Helpers

    private func localizedTitle(for mode: StutteringMode) -> String {
        switch mode {
        case .metronome:  return String(localized: "stuttering.exercise.metronome.title")
        case .breathing:  return String(localized: "stuttering.exercise.breathing.title")
        case .softOnset:  return String(localized: "stuttering.exercise.soft_start.title")
        case .diary:      return String(localized: "stuttering.exercise.diary.title")
        }
    }

    private func localizedSubtitle(for mode: StutteringMode) -> String {
        switch mode {
        case .metronome:  return String(localized: "stuttering.exercise.metronome.subtitle")
        case .breathing:  return String(localized: "stuttering.exercise.breathing.subtitle")
        case .softOnset:  return String(localized: "stuttering.exercise.soft_start.subtitle")
        case .diary:      return String(localized: "stuttering.exercise.diary.subtitle")
        }
    }
}
