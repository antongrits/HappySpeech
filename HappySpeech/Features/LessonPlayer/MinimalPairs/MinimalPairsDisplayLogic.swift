import Foundation

// MARK: - MinimalPairsDisplayLogic
//
// Протокол связи Presenter → View (Display store).
// Все методы @MainActor — обновление @Observable состояния.

@MainActor
protocol MinimalPairsDisplayLogic: AnyObject {
    func displayLoadSession(_ viewModel: MinimalPairsModels.LoadSession.ViewModel)
    func displayStartRound(_ viewModel: MinimalPairsModels.StartRound.ViewModel)
    func displaySelectOption(_ viewModel: MinimalPairsModels.SelectOption.ViewModel)
    func displayReplayWord(_ viewModel: MinimalPairsModels.ReplayWord.ViewModel)
    func displayHint(_ viewModel: MinimalPairsModels.RequestHint.ViewModel)
    func displayBonusRoundAdded(_ viewModel: MinimalPairsModels.BonusRoundAdded.ViewModel)
    func displayCompleteSession(_ viewModel: MinimalPairsModels.CompleteSession.ViewModel)
}
