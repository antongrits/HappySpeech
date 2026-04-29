import Foundation

// MARK: - SiblingDiscoveryDisplayLogic

@MainActor
protocol SiblingDiscoveryDisplayLogic: AnyObject {
    func displayPeers(_ viewModel: SiblingModels.Discovery.ViewModel)
    func displayInviteSent(_ viewModel: SiblingModels.InvitePeer.ViewModel)
    func displayPermissionError(message: String)
}

// MARK: - SiblingLobbyDisplayLogic

@MainActor
protocol SiblingLobbyDisplayLogic: AnyObject {
    func displayLobbyLoaded(_ viewModel: SiblingModels.LobbyLoad.ViewModel)
    func displayReadyState(_ viewModel: SiblingModels.ReadyState.ViewModel)
    func displayTimeout(_ viewModel: SiblingModels.LobbyTimeout.ViewModel)
}

// MARK: - SiblingGameDisplayLogic

@MainActor
protocol SiblingGameDisplayLogic: AnyObject {
    func displayGameLoaded(_ viewModel: SiblingModels.GameLoad.ViewModel)
    func displayRoundStart(_ viewModel: SiblingModels.RoundStart.ViewModel)
    func displayScoreUpdate(_ viewModel: SiblingModels.ScoreUpdate.ViewModel)
    func displayRoundResult(_ viewModel: SiblingModels.RoundResult.ViewModel)
    func displayGameResult(_ viewModel: SiblingModels.GameResult.ViewModel)
    func displayConnectionLost(message: String)
}
