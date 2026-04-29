import Foundation
import MultipeerConnectivity

// MARK: - SiblingDiscoveryPresentationLogic

@MainActor
protocol SiblingDiscoveryPresentationLogic: AnyObject {
    func presentPeers(_ response: SiblingModels.Discovery.Response)
    func presentInviteSent(_ response: SiblingModels.InvitePeer.Response)
    func presentPermissionError(message: String)
}

// MARK: - SiblingLobbyPresentationLogic

@MainActor
protocol SiblingLobbyPresentationLogic: AnyObject {
    func presentLobbyLoaded(_ response: SiblingModels.LobbyLoad.Response)
    func presentReadyState(_ response: SiblingModels.ReadyState.Response)
    func presentTimeout(_ response: SiblingModels.LobbyTimeout.Response)
}

// MARK: - SiblingGamePresentationLogic

@MainActor
protocol SiblingGamePresentationLogic: AnyObject {
    func presentGameLoaded(_ response: SiblingModels.GameLoad.Response)
    func presentRoundStart(_ response: SiblingModels.RoundStart.Response)
    func presentScoreUpdate(_ response: SiblingModels.ScoreUpdate.Response)
    func presentRoundResult(_ response: SiblingModels.RoundResult.Response)
    func presentGameResult(_ response: SiblingModels.GameResult.Response)
    func presentConnectionLost(message: String)
}

// MARK: - SiblingPresenter (Discovery)

@MainActor
final class SiblingDiscoveryPresenter: SiblingDiscoveryPresentationLogic {

    weak var view: (any SiblingDiscoveryDisplayLogic)?

    func presentPeers(_ response: SiblingModels.Discovery.Response) {
        let peers = response.peers.map { peerID in
            SiblingPeerViewModel(
                id: peerID.displayName,
                displayName: peerID.displayName,
                peerID: peerID
            )
        }
        let viewModel = SiblingModels.Discovery.ViewModel(
            peers: peers,
            isSearching: true
        )
        view?.displayPeers(viewModel)
    }

    func presentInviteSent(_ response: SiblingModels.InvitePeer.Response) {
        let viewModel = SiblingModels.InvitePeer.ViewModel(peerID: response.peerID)
        view?.displayInviteSent(viewModel)
    }

    func presentPermissionError(message: String) {
        view?.displayPermissionError(message: message)
    }
}

// MARK: - SiblingPresenter (Lobby)

@MainActor
final class SiblingLobbyPresenter: SiblingLobbyPresentationLogic {

    weak var view: (any SiblingLobbyDisplayLogic)?

    func presentLobbyLoaded(_ response: SiblingModels.LobbyLoad.Response) {
        let viewModel = SiblingModels.LobbyLoad.ViewModel(
            localDisplayName: response.localDisplayName,
            peerDisplayName: response.peerDisplayName
        )
        view?.displayLobbyLoaded(viewModel)
    }

    func presentReadyState(_ response: SiblingModels.ReadyState.Response) {
        let shouldStart = response.localReady && response.peerReady
        let viewModel = SiblingModels.ReadyState.ViewModel(
            localReady: response.localReady,
            peerReady: response.peerReady,
            shouldStartGame: shouldStart
        )
        view?.displayReadyState(viewModel)
    }

    func presentTimeout(_ response: SiblingModels.LobbyTimeout.Response) {
        let viewModel = SiblingModels.LobbyTimeout.ViewModel(
            errorMessage: String(localized: "sibling.error.connection")
        )
        view?.displayTimeout(viewModel)
    }
}

// MARK: - SiblingPresenter (Game)

@MainActor
final class SiblingGamePresenter: SiblingGamePresentationLogic {

    weak var view: (any SiblingGameDisplayLogic)?

    private let localPeerDisplayName: String

    init(localPeerDisplayName: String) {
        self.localPeerDisplayName = localPeerDisplayName
    }

    func presentGameLoaded(_ response: SiblingModels.GameLoad.Response) {
        let viewModel = SiblingModels.GameLoad.ViewModel(
            words: response.words,
            peerDisplayName: response.peerDisplayName,
            totalRounds: response.totalRounds
        )
        view?.displayGameLoaded(viewModel)
    }

    func presentRoundStart(_ response: SiblingModels.RoundStart.Response) {
        let label = String(
            format: String(localized: "sibling.game.round_format"),
            response.roundIndex,
            response.totalRounds
        )
        let viewModel = SiblingModels.RoundStart.ViewModel(
            roundIndex: response.roundIndex,
            word: response.word,
            totalRounds: response.totalRounds,
            roundLabel: label
        )
        view?.displayRoundStart(viewModel)
    }

    func presentScoreUpdate(_ response: SiblingModels.ScoreUpdate.Response) {
        let viewModel = SiblingModels.ScoreUpdate.ViewModel(
            ourRoundResult: response.ourRoundResult,
            peerRoundResult: response.peerRoundResult,
            ourTotalPoints: response.ourTotalPoints,
            peerTotalPoints: response.peerTotalPoints
        )
        view?.displayScoreUpdate(viewModel)
    }

    func presentRoundResult(_ response: SiblingModels.RoundResult.Response) {
        let isOurWin = response.winnerName == localPeerDisplayName
        let resultLabel: String
        if let winner = response.winnerName {
            resultLabel = String(format: String(localized: "sibling.game.win"), winner)
        } else {
            resultLabel = String(localized: "sibling.game.tie")
        }
        let viewModel = SiblingModels.RoundResult.ViewModel(
            winnerName: response.winnerName,
            isOurWin: isOurWin,
            resultLabel: resultLabel
        )
        view?.displayRoundResult(viewModel)
    }

    func presentGameResult(_ response: SiblingModels.GameResult.Response) {
        let isTie = response.winnerName == nil
        let isOurWin = response.winnerName == localPeerDisplayName
        let resultTitle: String
        if let winner = response.winnerName {
            resultTitle = String(format: String(localized: "sibling.game.win"), winner)
        } else {
            resultTitle = String(localized: "sibling.game.tie")
        }
        let viewModel = SiblingModels.GameResult.ViewModel(
            winnerName: response.winnerName,
            ourFinalScore: response.ourFinalScore,
            peerFinalScore: response.peerFinalScore,
            isOurWin: isOurWin,
            isTie: isTie,
            resultTitle: resultTitle
        )
        view?.displayGameResult(viewModel)
    }

    func presentConnectionLost(message: String) {
        view?.displayConnectionLost(message: message)
    }
}
