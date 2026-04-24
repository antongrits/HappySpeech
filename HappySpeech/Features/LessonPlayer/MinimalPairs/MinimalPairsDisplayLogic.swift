import Foundation

// MARK: - MinimalPairsDisplayLogic
//
// Протокол для связи Presenter → View (store). Все методы main-actor
// из-за обновления @Observable состояния.

@MainActor
protocol MinimalPairsDisplayLogic: AnyObject {
    func displayLoadSession(_ viewModel: MinimalPairsModels.LoadSession.ViewModel)
    func displayStartRound(_ viewModel: MinimalPairsModels.StartRound.ViewModel)
    func displaySelectOption(_ viewModel: MinimalPairsModels.SelectOption.ViewModel)
    func displayCompleteSession(_ viewModel: MinimalPairsModels.CompleteSession.ViewModel)
}
