@testable import HappySpeech
import MultipeerConnectivity
import XCTest

// MARK: - SiblingPresenterTests
//
// Phase 2.6 batch 2 v25 — покрытие SiblingDiscoveryPresenter,
// SiblingLobbyPresenter, SiblingGamePresenter (38% → цель ≥90%).

// MARK: - SiblingDiscoveryPresenterTests

@MainActor
final class SiblingDiscoveryPresenterTests: XCTestCase {

    @MainActor
    private final class DiscoveryDisplaySpy: SiblingDiscoveryDisplayLogic {
        var peersVM: SiblingModels.Discovery.ViewModel?
        var inviteSentVM: SiblingModels.InvitePeer.ViewModel?
        var permissionErrorMessage: String?

        func displayPeers(_ viewModel: SiblingModels.Discovery.ViewModel) { peersVM = viewModel }
        func displayInviteSent(_ viewModel: SiblingModels.InvitePeer.ViewModel) { inviteSentVM = viewModel }
        func displayPermissionError(message: String) { permissionErrorMessage = message }
    }

    private func makeSUT() -> (SiblingDiscoveryPresenter, DiscoveryDisplaySpy) {
        let presenter = SiblingDiscoveryPresenter()
        let spy = DiscoveryDisplaySpy()
        presenter.view = spy
        return (presenter, spy)
    }

    func test_presentPeers_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentPeers(.init(peers: []))
        XCTAssertNotNil(spy.peersVM)
    }

    func test_presentPeers_emptyPeers_emptyRows() {
        let (sut, spy) = makeSUT()
        sut.presentPeers(.init(peers: []))
        XCTAssertEqual(spy.peersVM?.peers.count, 0)
    }

    func test_presentPeers_withPeers_rowsBuilt() {
        let (sut, spy) = makeSUT()
        let peer = MCPeerID(displayName: "iPhone Маши")
        sut.presentPeers(.init(peers: [peer]))
        XCTAssertEqual(spy.peersVM?.peers.count, 1)
    }

    func test_presentPeers_peerDisplayNamePassedThrough() {
        let (sut, spy) = makeSUT()
        let peer = MCPeerID(displayName: "iPhone Вани")
        sut.presentPeers(.init(peers: [peer]))
        XCTAssertEqual(spy.peersVM?.peers.first?.displayName, "iPhone Вани")
    }

    func test_presentPeers_isSearchingTrue() {
        let (sut, spy) = makeSUT()
        sut.presentPeers(.init(peers: []))
        XCTAssertTrue(spy.peersVM?.isSearching ?? false)
    }

    func test_presentInviteSent_callsDisplay() {
        let (sut, spy) = makeSUT()
        let peer = MCPeerID(displayName: "iPhone Маши")
        sut.presentInviteSent(.init(peerID: peer))
        XCTAssertNotNil(spy.inviteSentVM)
    }

    func test_presentInviteSent_peerIDPassedThrough() {
        let (sut, spy) = makeSUT()
        let peer = MCPeerID(displayName: "iPad Вани")
        sut.presentInviteSent(.init(peerID: peer))
        XCTAssertEqual(spy.inviteSentVM?.peerID.displayName, "iPad Вани")
    }

    func test_presentPermissionError_messagePassedThrough() {
        let (sut, spy) = makeSUT()
        sut.presentPermissionError(message: "Нет разрешения на Bluetooth")
        XCTAssertEqual(spy.permissionErrorMessage, "Нет разрешения на Bluetooth")
    }
}

// MARK: - SiblingLobbyPresenterTests

@MainActor
final class SiblingLobbyPresenterTests: XCTestCase {

    @MainActor
    private final class LobbyDisplaySpy: SiblingLobbyDisplayLogic {
        var lobbyLoadedVM: SiblingModels.LobbyLoad.ViewModel?
        var readyStateVM: SiblingModels.ReadyState.ViewModel?
        var timeoutVM: SiblingModels.LobbyTimeout.ViewModel?

        func displayLobbyLoaded(_ viewModel: SiblingModels.LobbyLoad.ViewModel) { lobbyLoadedVM = viewModel }
        func displayReadyState(_ viewModel: SiblingModels.ReadyState.ViewModel) { readyStateVM = viewModel }
        func displayTimeout(_ viewModel: SiblingModels.LobbyTimeout.ViewModel) { timeoutVM = viewModel }
    }

    private func makeSUT() -> (SiblingLobbyPresenter, LobbyDisplaySpy) {
        let presenter = SiblingLobbyPresenter()
        let spy = LobbyDisplaySpy()
        presenter.view = spy
        return (presenter, spy)
    }

    func test_presentLobbyLoaded_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentLobbyLoaded(.init(localDisplayName: "Маша", peerDisplayName: "Ваня"))
        XCTAssertNotNil(spy.lobbyLoadedVM)
    }

    func test_presentLobbyLoaded_displayNamesPassedThrough() {
        let (sut, spy) = makeSUT()
        sut.presentLobbyLoaded(.init(localDisplayName: "Маша", peerDisplayName: "Ваня"))
        XCTAssertEqual(spy.lobbyLoadedVM?.localDisplayName, "Маша")
        XCTAssertEqual(spy.lobbyLoadedVM?.peerDisplayName, "Ваня")
    }

    func test_presentReadyState_bothReady_shouldStartGame() {
        let (sut, spy) = makeSUT()
        sut.presentReadyState(.init(localReady: true, peerReady: true))
        XCTAssertTrue(spy.readyStateVM?.shouldStartGame ?? false)
    }

    func test_presentReadyState_onlyLocalReady_shouldNotStartGame() {
        let (sut, spy) = makeSUT()
        sut.presentReadyState(.init(localReady: true, peerReady: false))
        XCTAssertFalse(spy.readyStateVM?.shouldStartGame ?? true)
    }

    func test_presentReadyState_neitherReady_shouldNotStartGame() {
        let (sut, spy) = makeSUT()
        sut.presentReadyState(.init(localReady: false, peerReady: false))
        XCTAssertFalse(spy.readyStateVM?.shouldStartGame ?? true)
    }

    func test_presentReadyState_statesPassedThrough() {
        let (sut, spy) = makeSUT()
        sut.presentReadyState(.init(localReady: true, peerReady: false))
        XCTAssertTrue(spy.readyStateVM?.localReady ?? false)
        XCTAssertFalse(spy.readyStateVM?.peerReady ?? true)
    }

    func test_presentTimeout_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentTimeout(.init())
        XCTAssertNotNil(spy.timeoutVM)
    }

    func test_presentTimeout_errorMessageNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentTimeout(.init())
        XCTAssertFalse(spy.timeoutVM?.errorMessage.isEmpty ?? true)
    }
}

// MARK: - SiblingGamePresenterTests

@MainActor
final class SiblingGamePresenterTests: XCTestCase {

    @MainActor
    private final class GameDisplaySpy: SiblingGameDisplayLogic {
        var gameLoadedVM: SiblingModels.GameLoad.ViewModel?
        var roundStartVM: SiblingModels.RoundStart.ViewModel?
        var scoreUpdateVM: SiblingModels.ScoreUpdate.ViewModel?
        var roundResultVM: SiblingModels.RoundResult.ViewModel?
        var gameResultVM: SiblingModels.GameResult.ViewModel?
        var connectionLostMessage: String?

        func displayGameLoaded(_ viewModel: SiblingModels.GameLoad.ViewModel) { gameLoadedVM = viewModel }
        func displayRoundStart(_ viewModel: SiblingModels.RoundStart.ViewModel) { roundStartVM = viewModel }
        func displayScoreUpdate(_ viewModel: SiblingModels.ScoreUpdate.ViewModel) { scoreUpdateVM = viewModel }
        func displayRoundResult(_ viewModel: SiblingModels.RoundResult.ViewModel) { roundResultVM = viewModel }
        func displayGameResult(_ viewModel: SiblingModels.GameResult.ViewModel) { gameResultVM = viewModel }
        func displayConnectionLost(message: String) { connectionLostMessage = message }
    }

    private let localName = "Маша"

    private func makeSUT() -> (SiblingGamePresenter, GameDisplaySpy) {
        let presenter = SiblingGamePresenter(localPeerDisplayName: localName)
        let spy = GameDisplaySpy()
        presenter.view = spy
        return (presenter, spy)
    }

    func test_presentGameLoaded_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentGameLoaded(.init(words: ["кот", "мяч"], peerDisplayName: "Ваня", totalRounds: 5))
        XCTAssertNotNil(spy.gameLoadedVM)
    }

    func test_presentGameLoaded_dataPassedThrough() {
        let (sut, spy) = makeSUT()
        sut.presentGameLoaded(.init(words: ["рыба", "кот"], peerDisplayName: "Ваня", totalRounds: 3))
        XCTAssertEqual(spy.gameLoadedVM?.words, ["рыба", "кот"])
        XCTAssertEqual(spy.gameLoadedVM?.totalRounds, 3)
        XCTAssertEqual(spy.gameLoadedVM?.peerDisplayName, "Ваня")
    }

    func test_presentRoundStart_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentRoundStart(.init(roundIndex: 1, word: "мяч", totalRounds: 5))
        XCTAssertNotNil(spy.roundStartVM)
    }

    func test_presentRoundStart_roundLabelNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentRoundStart(.init(roundIndex: 2, word: "кот", totalRounds: 5))
        XCTAssertFalse(spy.roundStartVM?.roundLabel.isEmpty ?? true)
    }

    func test_presentRoundStart_wordPassedThrough() {
        let (sut, spy) = makeSUT()
        sut.presentRoundStart(.init(roundIndex: 1, word: "собака", totalRounds: 5))
        XCTAssertEqual(spy.roundStartVM?.word, "собака")
    }

    func test_presentScoreUpdate_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentScoreUpdate(.init(ourRoundResult: 0.9, peerRoundResult: 0.7, ourTotalPoints: 5, peerTotalPoints: 3))
        XCTAssertNotNil(spy.scoreUpdateVM)
    }

    func test_presentScoreUpdate_scoresPassedThrough() {
        let (sut, spy) = makeSUT()
        sut.presentScoreUpdate(.init(ourRoundResult: 0.85, peerRoundResult: 0.6, ourTotalPoints: 10, peerTotalPoints: 7))
        XCTAssertEqual(spy.scoreUpdateVM?.ourTotalPoints, 10)
        XCTAssertEqual(spy.scoreUpdateVM?.peerTotalPoints, 7)
    }

    func test_presentRoundResult_localWin_isOurWinTrue() {
        let (sut, spy) = makeSUT()
        sut.presentRoundResult(.init(winnerName: localName))
        XCTAssertTrue(spy.roundResultVM?.isOurWin ?? false)
    }

    func test_presentRoundResult_peerWin_isOurWinFalse() {
        let (sut, spy) = makeSUT()
        sut.presentRoundResult(.init(winnerName: "Ваня"))
        XCTAssertFalse(spy.roundResultVM?.isOurWin ?? true)
    }

    func test_presentRoundResult_noWinner_resultLabelNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentRoundResult(.init(winnerName: nil))
        XCTAssertFalse(spy.roundResultVM?.resultLabel.isEmpty ?? true)
    }

    func test_presentRoundResult_hasWinner_resultLabelNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentRoundResult(.init(winnerName: "Маша"))
        XCTAssertFalse(spy.roundResultVM?.resultLabel.isEmpty ?? true)
    }

    func test_presentGameResult_tieCase() {
        let (sut, spy) = makeSUT()
        sut.presentGameResult(.init(winnerName: nil, ourFinalScore: 3, peerFinalScore: 3))
        XCTAssertTrue(spy.gameResultVM?.isTie ?? false)
        XCTAssertFalse(spy.gameResultVM?.isOurWin ?? true)
    }

    func test_presentGameResult_localWin() {
        let (sut, spy) = makeSUT()
        sut.presentGameResult(.init(winnerName: localName, ourFinalScore: 5, peerFinalScore: 3))
        XCTAssertTrue(spy.gameResultVM?.isOurWin ?? false)
        XCTAssertFalse(spy.gameResultVM?.isTie ?? true)
    }

    func test_presentGameResult_peerWin() {
        let (sut, spy) = makeSUT()
        sut.presentGameResult(.init(winnerName: "Ваня", ourFinalScore: 2, peerFinalScore: 5))
        XCTAssertFalse(spy.gameResultVM?.isOurWin ?? true)
        XCTAssertFalse(spy.gameResultVM?.isTie ?? true)
    }

    func test_presentGameResult_resultTitleNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentGameResult(.init(winnerName: nil, ourFinalScore: 3, peerFinalScore: 3))
        XCTAssertFalse(spy.gameResultVM?.resultTitle.isEmpty ?? true)
    }

    func test_presentConnectionLost_messagePassedThrough() {
        let (sut, spy) = makeSUT()
        sut.presentConnectionLost(message: "Связь потеряна")
        XCTAssertEqual(spy.connectionLostMessage, "Связь потеряна")
    }
}
